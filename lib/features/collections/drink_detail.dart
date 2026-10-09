import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/core/media/media_image.dart';
import 'package:nexus_mobile/core/media/pick_image.dart';
import 'package:nexus_mobile/design/art_ambient.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';
import 'package:nexus_mobile/features/collections/analysis_panel.dart';
import 'package:nexus_mobile/features/collections/drink_forms.dart';
import 'package:nexus_mobile/features/collections/drink_kind.dart';
import 'package:nexus_mobile/features/collections/drinks_api.dart';
import 'package:nexus_mobile/features/collections/prints.dart';

String _cap(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
String _num(double v) => v % 1 == 0 ? v.toStringAsFixed(0) : '$v';

/// Wine / beer / spirit page (web DrinkDetail + useDrinkDetail): label art,
/// serif stage, AI tasting notes (polled while pending), facts and notes.
class DrinkDetailScreen extends ConsumerStatefulWidget {
  const DrinkDetailScreen({required this.kind, required this.id, super.key});

  final DrinkKind kind;
  final int id;

  @override
  ConsumerState<DrinkDetailScreen> createState() => _DrinkDetailScreenState();
}

class _DrinkDetailScreenState extends ConsumerState<DrinkDetailScreen> {
  static const _pollEvery = Duration(milliseconds: 2500);
  Timer? _poll;
  bool _analysing = false;

  (DrinkKind, int) get _key => (widget.kind, widget.id);

  @override
  void initState() {
    super.initState();
    ref.listenManual(
      drinkProvider(_key),
      (_, next) => _syncPoll(next.value?.str('analysis_status') == 'pending'),
      fireImmediately: true,
    );
  }

  void _syncPoll(bool pending) {
    if (!pending) {
      _poll?.cancel();
      _poll = null;
      return;
    }
    _poll ??= Timer.periodic(_pollEvery, (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) ref.invalidate(drinkProvider(_key));
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _analyse(bool force) async {
    setState(() => _analysing = true);
    try {
      await ref.read(drinksApiProvider).analyse(widget.kind, widget.id, force: force);
    } on Object catch (e) {
      if (mounted) showApiError(context, e, 'Analysis could not start.');
    } finally {
      if (mounted) setState(() => _analysing = false);
    }
  }

  Future<void> _photo(String title) async {
    final image = await pickAndUploadImage(
      context,
      ref,
      collection: widget.kind.uploadCollection,
      attachType: widget.kind.attachType,
      attachId: widget.id,
      title: '$title · label photo',
    );
    if (image != null) ref.read(drinksApiProvider).imageAttached(widget.kind, widget.id);
  }

  Future<void> _remove() async {
    final ok = await showNxConfirm(
      context,
      message: 'Delete this ${widget.kind.noun}? Tastings and notes go with it.',
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(drinksApiProvider).remove(widget.kind, widget.id);
      if (mounted) context.go(widget.kind.route);
    } on Object catch (e) {
      if (mounted) showApiError(context, e, 'Could not delete.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(drinkProvider(_key));
    return NxAsync(
      value: value,
      onRetry: () => ref.invalidate(drinkProvider(_key)),
      loading: const NxPage(children: [NxPageSkeleton()]),
      data: _page,
    );
  }

  Widget _page(Json item) {
    final kind = widget.kind;
    final c = context.nx;
    final title = item.text('name', _cap(kind.noun));
    final media = MediaImage.fromJson(item.obj('media'));
    final url = item.str('image_url');
    final hasArt = media != null || url != null;
    final rating = item.number('rating');
    final notes = item.str('notes');

    final (eyebrow, accent, lede, facts) = switch (kind) {
      DrinkKind.wine => (
        item.str('producer_name') ?? 'Wine',
        item.integer('vintage')?.toString(),
        [item.str('wine_type'), item.str('region_name'), item.str('country')].whereType<String>().join(' · '),
        <(String, String?)>[
          ('Producer', item.str('producer_name')),
          ('Vintage', item.integer('vintage')?.toString()),
          ('Style', item.str('wine_type')),
          ('Region', item.str('region_name')),
          ('Country', item.str('country')),
          ('Tastings', '${item.list('tastings').length}'),
        ],
      ),
      DrinkKind.beer => (
        item.obj('style')?.str('name') ?? 'Beer',
        null,
        [
          if (item.number('abv') case final abv?) '${_num(abv)}% ABV',
          if (item.number('ibu') case final ibu?) '${_num(ibu)} IBU',
          if (item.str('format') case final f?) _cap(f),
        ].join(' · '),
        <(String, String?)>[
          ('Style', item.obj('style')?.str('name')),
          ('Family', item.obj('style')?.str('family')),
          ('ABV', item.number('abv') == null ? null : '${_num(item.number('abv')!)}%'),
          ('IBU', item.number('ibu') == null ? null : _num(item.number('ibu')!)),
          ('Format', item.str('format')),
          (
            'Origin',
            [item.obj('brewery')?.str('city'), item.obj('brewery')?.str('country')].whereType<String>().join(', '),
          ),
        ],
      ),
      DrinkKind.spirit => (
        item.str('category') ?? 'Spirit',
        item.str('age_statement'),
        [
          item.str('producer'),
          item.str('region') ?? item.str('country'),
          if (item.number('abv') case final abv?) '${_num(abv)}% ABV',
        ].whereType<String>().join(' · '),
        <(String, String?)>[
          ('Distillery', item.str('producer')),
          ('Category', item.str('category')),
          ('Age', item.str('age_statement')),
          ('ABV', item.number('abv') == null ? null : '${_num(item.number('abv')!)}%'),
          ('Region', item.str('region')),
          ('Country', item.str('country')),
        ],
      ),
    };

    final brewery = kind == DrinkKind.beer ? item.obj('brewery') : null;
    final ledeWidget = brewery == null
        ? null
        : Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: brewery.text('name'),
                  style: TextStyle(color: c.ink, decoration: TextDecoration.underline, decorationColor: c.lineStrong),
                ),
                if (lede.isNotEmpty) TextSpan(text: ' · $lede'),
              ],
            ),
          );

    return ArtAmbient(
      media: media,
      url: url,
      fallback: kind == DrinkKind.wine ? wineStyleAmbient(item.str('wine_type')) : null,
      child: NxPage(
        onRefresh: () async {
          ref
            ..invalidate(drinkProvider(_key))
            ..invalidate(analysisQuotaProvider);
          await ref.read(drinkProvider(_key).future);
        },
        children: [
          NxStage(
            eyebrow: eyebrow,
            title: title,
            accent: accent,
            lede: lede.isEmpty ? null : lede,
            ledeWidget: ledeWidget == null
                ? null
                : GestureDetector(
                    onTap: () => context.push('/beer/breweries/${brewery!.integer('id')}'),
                    child: ledeWidget,
                  ),
            art: StageArt.portrait,
            visual: NxArtWell(
              media: media,
              url: url,
              label: title,
              addLabel: 'Add a label photo',
              onAdd: () => _photo(title),
            ),
            actions: [
              if (kind == DrinkKind.wine)
                NxButton(
                  'Log tasting',
                  icon: LucideIcons.pencil,
                  onPressed: () => showTastingSheet(context, widget.id),
                ),
              NxButton(
                hasArt ? 'Label photo' : 'Add photo',
                icon: LucideIcons.image,
                variant: kind == DrinkKind.wine ? NxButtonVariant.secondary : NxButtonVariant.primary,
                onPressed: () => _photo(title),
              ),
              NxIconButton(LucideIcons.trash2, tooltip: 'Delete ${kind.noun}', filled: true, onPressed: _remove),
            ],
          ),
          const SizedBox(height: 24),
          NxPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AT A GLANCE', style: NxText.label(context, size: 11)),
                const SizedBox(height: 14),
                if (rating != null) ...[NxRating(rating, size: 20), const SizedBox(height: 14)],
                NxFacts(facts, columns: 2),
              ],
            ),
          ),
          const SizedBox(height: 8),
          AnalysisPanel(item: item, analysing: _analysing, onAnalyse: _analyse),
          if (kind == DrinkKind.wine) ...[
            const NxSectionHeader('Tasting history'),
            _Tastings(wineId: widget.id, tastings: item.list('tastings')),
          ],
          if (notes != null) ...[
            const NxSectionHeader('Your notes'),
            NxPanel(
              child: Text(notes, style: NxText.sans(size: 15, color: c.ink2, height: 1.6)),
            ),
          ],
          const SizedBox(height: 20),
          const Align(alignment: Alignment.centerRight, child: QuotaBadge()),
        ],
      ),
    );
  }
}

/// Tasting timeline (web NexusTastingTimeline).
class _Tastings extends ConsumerWidget {
  const _Tastings({required this.wineId, required this.tastings});

  final int wineId;
  final List<Json> tastings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tastings.isEmpty) {
      return const NxEmptyState(
        compact: true,
        title: 'No tastings yet',
        body: 'Log each time you open a bottle — the date, who you shared it with and how it showed.',
        icon: LucideIcons.wine,
      );
    }
    return Column(
      children: [
        for (final t in tastings)
          NxStreamItem(
            key: ValueKey(t['id']),
            time: shortDay(t.str('tasted_on')) ?? '',
            kind: 'Tasting',
            meta: t.str('location'),
            title: t.str('occasion') ?? 'Opened a bottle',
            body: t.str('notes'),
            chips: [if (t.number('rating') case final r?) '★ ${r.toStringAsFixed(1)}'],
            trailing: NxIconButton(
              LucideIcons.trash2,
              tooltip: 'Delete tasting',
              size: 34,
              onPressed: () async {
                final ok = await showNxConfirm(context, message: 'Delete this tasting?');
                if (!ok) return;
                try {
                  await ref.read(drinksApiProvider).removeTasting(wineId, t.integer('id') ?? 0);
                } on Object catch (e) {
                  if (context.mounted) showApiError(context, e);
                }
              },
            ),
          ),
      ],
    );
  }
}
