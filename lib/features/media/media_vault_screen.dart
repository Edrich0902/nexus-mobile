import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nexus_mobile/core/api/api_client.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/core/api/paged.dart';
import 'package:nexus_mobile/core/format.dart';
import 'package:nexus_mobile/core/media/media_image.dart';
import 'package:nexus_mobile/core/media/pick_image.dart';
import 'package:nexus_mobile/design/debounced_search.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';
import 'package:nexus_mobile/features/collections/collection_fields.dart';

const _collections = [
  ('avatar', 'Avatar'),
  ('cellar', 'Cellar'),
  ('kitchen', 'Kitchen'),
  ('beer', 'Beer'),
  ('library', 'Library'),
  ('vault', 'Vault'),
  ('mirror', 'Mirror'),
];

const _sources = [('upload', 'Upload'), ('unsplash', 'Unsplash'), ('mirror', 'Mirror')];

const _attached = [('all', 'All'), ('attached', 'In use'), ('orphan', 'Orphans')];

final mediaUsageProvider = FutureProvider.autoDispose<Json>(
  (ref) async => asJson(await ref.watch(apiClientProvider).get('/media/usage')),
);

/// Web MediaVaultView: Cloudinary usage, every image across Nexus, filters,
/// upload and delete (with a forced delete when the image is still in use).
class MediaVaultScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<MediaVaultScreen> createState() => _MediaVaultScreenState();
}

class _MediaVaultScreenState extends ConsumerState<MediaVaultScreen> with DebouncedSearch {
  String? _collection;
  String? _source;
  String _attachedFilter = 'all';
  bool _refreshingUsage = false;

  PageQuery get _query => PageQuery('/media', {
    'collection': _collection,
    'source': _source,
    'attached': _attachedFilter == 'all' ? null : _attachedFilter,
    'q': searched,
    'per_page': 30,
  });

  Future<void> _refreshUsage() async {
    setState(() => _refreshingUsage = true);
    try {
      await ref.read(apiClientProvider).get('/media/usage', query: {'refresh': 1});
      ref.invalidate(mediaUsageProvider);
    } on Object catch (e) {
      if (mounted) showApiError(context, e, 'Could not refresh usage.');
    } finally {
      if (mounted) setState(() => _refreshingUsage = false);
    }
  }

  Future<void> _upload() async {
    final image = await pickAndUploadImage(context, ref, collection: 'vault', title: 'Upload to the vault');
    if (image == null) return;
    ref
      ..invalidate(pagedProvider(_query))
      ..invalidate(mediaUsageProvider);
    if (mounted) showNxToast(context, 'Uploaded.');
  }

  Future<void> _delete(Json asset) async {
    final api = ref.read(apiClientProvider);
    final id = asset.integer('id');
    if (id == null) return;
    if (!await showNxConfirm(context, message: 'Delete this image from Cloudinary?')) return;
    try {
      await api.delete('/media/$id');
    } on DioException catch (e) {
      if (e.response?.statusCode != 409 || !mounted) {
        if (mounted) showApiError(context, e, 'Could not delete the image.');
        return;
      }
      final message = asJson(e.response?.data).text('message', 'This image is still in use.');
      final force = await showNxConfirm(context, message: '$message Delete it anyway?', confirmLabel: 'Delete anyway');
      if (!force) return;
      try {
        await api.delete('/media/$id', query: {'force': 1});
      } on Object catch (e) {
        if (mounted) showApiError(context, e, 'Could not delete the image.');
        return;
      }
    } on Object catch (e) {
      if (mounted) showApiError(context, e, 'Could not delete the image.');
      return;
    }
    ref
      ..invalidate(pagedProvider(_query))
      ..invalidate(mediaUsageProvider);
    if (mounted) showNxToast(context, 'Image deleted.');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    final usage = ref.watch(mediaUsageProvider).value;
    final list = ref.watch(pagedProvider(_query));
    final s = list.value;
    final originals = usage?.integer('resources') ?? s?.total ?? 0;
    final derived = usage?.integer('derived_resources') ?? 0;
    final filtered = _collection != null || _source != null || _attachedFilter != 'all' || searched.isNotEmpty;

    final eyebrow = [
      'Media vault',
      if (usage?.str('plan') case final plan?) 'Cloudinary $plan',
      if (usage?.date('fetched_at') case final at?) 'checked ${relativeTime(at)}',
    ].join(' · ');

    final lede = usage == null
        ? 'Every image across Nexus — uploads, Unsplash picks and mirrored covers.'
        : '${plural(originals, 'original')}${derived > 0 ? ' and ${plural(derived, 'resized variant')}' : ''} on '
              "Cloudinary. Totals update on Cloudinary's delay, so recent changes can take a while to show.";

    return NxPage(
      onRefresh: () async {
        ref
          ..invalidate(pagedProvider(_query))
          ..invalidate(mediaUsageProvider);
        await ref.read(pagedProvider(_query).future);
      },
      children: [
        NxStage(
          compact: true,
          eyebrow: eyebrow,
          title: NumberFormat.decimalPattern().format(originals),
          accent: originals == 1 ? 'image' : 'images',
          lede: lede,
          actions: [
            NxButton('Upload', icon: LucideIcons.plus, onPressed: _upload),
            NxIconButton(
              LucideIcons.refreshCw,
              tooltip: 'Refresh usage',
              onPressed: _refreshingUsage ? null : _refreshUsage,
            ),
          ],
        ),
        if (usage != null) CollectionFields(section: SectionKey.media, fields: _fields(usage)),
        const SizedBox(height: 22),
        NxPillNav<String>(
          items: _attached,
          value: _attachedFilter,
          onChanged: (v) => setState(() => _attachedFilter = v),
        ),
        const SizedBox(height: 12),
        NxFormRow(
          children: [
            NxPickerField<String>(
              label: 'Collection',
              options: _collections,
              value: _collection,
              onChanged: (v) => setState(() => _collection = v),
            ),
            NxPickerField<String>(
              label: 'Source',
              options: _sources,
              value: _source,
              onChanged: (v) => setState(() => _source = v),
            ),
          ],
        ),
        const SizedBox(height: 12),
        NxSearchField(
          controller: searchController,
          hint: 'Search public id or alt text…',
          onChanged: onSearchChanged,
          onSubmitted: submitSearch,
        ),
        const SizedBox(height: 16),
        if (s == null && list.hasError)
          NxErrorState(error: list.error!, onRetry: () => ref.invalidate(pagedProvider(_query)))
        else if (s == null)
          const NxSkeleton(height: 320, radius: NxRadius.lg)
        else if (s.items.isEmpty && filtered)
          const NxEmptyState(
            compact: true,
            icon: LucideIcons.search,
            title: 'Nothing matches',
            body: 'Try another collection, source or search.',
          )
        else if (s.items.isEmpty)
          NxEmptyState(
            icon: LucideIcons.image,
            title: 'The vault is empty',
            body: 'Upload from your device or pick a photo from Unsplash to get started.',
            actionLabel: 'Upload an image',
            onAction: _upload,
          )
        else ...[
          Text(plural(s.total, 'image'), style: NxText.muted(context, size: 12.5)),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [for (final a in s.items) _Tile(asset: a, onDelete: () => _delete(a))],
          ),
          if (s.hasMore)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: NxButton(
                'Load more',
                variant: NxButtonVariant.secondary,
                wide: true,
                loading: s.loadingMore,
                onPressed: () => unawaited(
                  ref.read(pagedProvider(_query).notifier).loadMore().catchError((Object e) {
                    if (context.mounted) showApiError(context, e);
                  }),
                ),
              ),
            ),
        ],
        if (s != null && s.items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Text(
              'Images are delivered through Cloudinary named transforms sized for this screen.',
              style: NxText.sans(size: 12.5, color: c.ink3),
            ),
          ),
      ],
    );
  }

  List<CollectionField> _fields(Json u) {
    final limit = u.obj('credits')?.number('limit');
    double? share(Json? meter) {
      final used = meter?.number('credits_usage');
      return used == null || limit == null || limit == 0 ? null : used / limit;
    }

    final credits = u.obj('credits')?.number('usage') ?? 0;
    final percent = u.obj('credits')?.number('used_percent');
    return [
      CollectionField(
        key: 'credits',
        label: 'Credits used',
        value: credits.toStringAsFixed(credits < 10 ? 2 : 1),
        sub: limit == null ? null : 'of ${limit.round()} this month',
        progress: percent == null ? null : percent / 100,
      ),
      CollectionField(
        key: 'storage',
        label: 'Storage',
        value: formatBytes(u.obj('storage')?.number('usage')),
        progress: share(u.obj('storage')),
        variant: FieldVariant.tint,
      ),
      CollectionField(
        key: 'bandwidth',
        label: 'Bandwidth',
        value: formatBytes(u.obj('bandwidth')?.number('usage')),
        progress: share(u.obj('bandwidth')),
        variant: FieldVariant.tint,
      ),
      CollectionField(
        key: 'transforms',
        label: 'Transformations',
        value: NumberFormat.decimalPattern().format(u.obj('transformations')?.number('usage') ?? 0),
        progress: share(u.obj('transformations')),
        variant: FieldVariant.outline,
      ),
    ];
  }
}

class _Tile extends StatelessWidget {
  const new({required this.asset, required this.onDelete});

  final Json asset;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    final media = MediaImage.fromJson(asset.obj('media')) ?? MediaImage(url: asset.str('secure_url'));
    final orphan = asset.integer('attachments_count') == 0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(NxRadius.md),
      child: Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: () =>
                showImagePreview(context, media: media, label: asset.str('alt_text') ?? asset.str('public_id')),
            child: NxImage(media: media, semanticLabel: asset.str('alt_text') ?? asset.str('public_id')),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 18, 10, 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withValues(alpha: .7)],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      asset.text('collection'),
                      style: NxText.sans(size: 12, weight: FontWeight.w600, color: Colors.white),
                    ),
                    Text(
                      '${asset.text('source')} · ${formatBytes(asset.number('bytes'))}',
                      style: NxText.sans(size: 11, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (orphan)
            Positioned(
              left: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: c.acc, borderRadius: BorderRadius.circular(NxRadius.pill)),
                child: Text(
                  'Orphan',
                  style: NxText.sans(size: 11, weight: FontWeight.w600, color: c.accInk),
                ),
              ),
            ),
          Positioned(
            right: 6,
            top: 6,
            child: NxIconButton(
              LucideIcons.trash2,
              tooltip: 'Delete image',
              size: 32,
              filled: true,
              onPressed: onDelete,
            ),
          ),
        ],
      ),
    );
  }
}
