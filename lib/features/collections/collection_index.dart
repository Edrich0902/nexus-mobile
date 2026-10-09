import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/core/api/paged.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';
import 'package:nexus_mobile/features/collections/analysis_panel.dart';
import 'package:nexus_mobile/features/collections/collection_fields.dart';
import 'package:nexus_mobile/features/collections/drink_forms.dart';
import 'package:nexus_mobile/features/collections/drink_kind.dart';
import 'package:nexus_mobile/features/collections/drinks_api.dart';
import 'package:nexus_mobile/features/collections/prints.dart';

/// Debounced search box state shared by collection indexes.
mixin DebouncedSearch<T extends StatefulWidget> on State<T> {
  final searchController = TextEditingController();
  Timer? _debounce;
  String searched = '';

  void onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted && value.trim() != searched) setState(() => searched = value.trim());
    });
  }

  void submitSearch(String value) {
    _debounce?.cancel();
    setState(() => searched = value.trim());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    searchController.dispose();
    super.dispose();
  }
}

/// The print list, its empty / no-match states and "Show more" paging for a
/// [PageQuery] (web CollectionPrints inside IndexTemplate).
class PagedPrints extends ConsumerWidget {
  const PagedPrints({
    required this.query,
    required this.toPrint,
    required this.empty,
    required this.noMatch,
    this.filterLabel = 'Notes',
    super.key,
  });

  final PageQuery query;
  final PrintModel Function(Json item) toPrint;
  final Widget empty;
  final Widget noMatch;
  final String filterLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(pagedProvider(query));
    final s = list.value;
    if (s == null) {
      return list.hasError
          ? NxErrorState(error: list.error!, onRetry: () => ref.invalidate(pagedProvider(query)))
          : const _PrintsSkeleton();
    }
    if (s.items.isEmpty) return query.params.isEmpty ? empty : noMatch;
    return AnimatedOpacity(
      opacity: list.isLoading ? .55 : 1,
      duration: const Duration(milliseconds: 200),
      child: Column(
        children: [
          NxPrintCollection(
            prints: s.items.map(toPrint).toList(),
            filterLabel: filterLabel,
            onOpen: (p) => context.push(p.route),
          ),
          if (s.hasMore)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: NxButton(
                'Show more · ${s.remaining} left',
                variant: NxButtonVariant.secondary,
                loading: s.loadingMore,
                onPressed: () => ref.read(pagedProvider(query).notifier).loadMore().catchError((Object e) {
                  if (context.mounted) showApiError(context, e);
                }),
              ),
            ),
        ],
      ),
    );
  }
}

class _PrintsSkeleton extends StatelessWidget {
  const _PrintsSkeleton();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(top: 22),
    child: Column(
      children: [
        NxSkeleton(height: 220, radius: NxRadius.xxl),
        SizedBox(height: 12),
        NxSkeleton(height: 220, radius: NxRadius.xxl),
      ],
    ),
  );
}

/// Wine / beer / spirits index (web CellarView, BeerView, SpiritsView).
class DrinkIndexScreen extends ConsumerStatefulWidget {
  const DrinkIndexScreen({required this.kind, super.key});

  final DrinkKind kind;

  @override
  ConsumerState<DrinkIndexScreen> createState() => _DrinkIndexScreenState();
}

class _DrinkIndexScreenState extends ConsumerState<DrinkIndexScreen> with DebouncedSearch {
  Future<void> _create() async {
    final created = await showDrinkCreateSheet(context, widget.kind);
    final id = created?.integer('id');
    if (id != null && mounted) unawaited(context.push(widget.kind.pathFor(id)));
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.kind;
    final copy = kind.copy;
    final base = drinkQuery(kind, '');
    final query = drinkQuery(kind, searched);
    final all = ref.watch(pagedProvider(base)).value;

    return NxPage(
      onRefresh: () async {
        ref
          ..invalidate(pagedProvider(query))
          ..invalidate(analysisQuotaProvider);
        await ref.read(pagedProvider(query).future);
      },
      children: [
        NxStage(
          compact: true,
          eyebrow: copy.eyebrow,
          title: copy.title,
          accent: copy.accent,
          lede: copy.lede,
          actions: [NxButton(copy.add, icon: LucideIcons.plus, onPressed: _create)],
        ),
        if (all == null || all.items.isNotEmpty)
          all == null
              ? const Padding(
                  padding: EdgeInsets.only(top: 22),
                  child: NxSkeleton(height: 240, radius: NxRadius.xl),
                )
              : CollectionFields(
                  section: kind.section,
                  fields: drinkFields(
                    items: all.items,
                    total: all.total,
                    countLabel: kind.countLabel,
                    noun: kind.noun,
                    to: (i) => kind.pathFor(i.integer('id') ?? 0),
                  ),
                ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: NxSearchField(
                controller: searchController,
                hint: copy.search,
                onChanged: onSearchChanged,
                onSubmitted: submitSearch,
              ),
            ),
            if (kind != DrinkKind.beer) ...[const SizedBox(width: 10), const QuotaBadge()],
          ],
        ),
        PagedPrints(
          query: query,
          toPrint: (i) => drinkPrint(kind, i),
          empty: NxEmptyState(
            title: kind.empty.title,
            body: kind.empty.body,
            icon: kind.icon,
            actionLabel: kind.empty.action,
            onAction: _create,
          ),
          noMatch: NxEmptyState(
            title: 'Nothing matches “$searched”',
            body: kind.empty.noMatch,
            icon: LucideIcons.search,
          ),
        ),
      ],
    );
  }
}
