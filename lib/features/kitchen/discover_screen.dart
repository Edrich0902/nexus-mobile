import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';
import 'package:nexus_mobile/features/kitchen/kitchen_api.dart';
import 'package:nexus_mobile/features/kitchen/kitchen_screen.dart';

const _defaultCategory = 'Seafood';

/// Browse TheMealDB by category / cuisine or search (web KitchenDiscoverView).
class DiscoverScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final _search = TextEditingController();
  String _q = '';
  String? _category = _defaultCategory;
  String? _area;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _browse({String? category, String? area}) {
    _search.clear();
    setState(() {
      _q = '';
      _category = category;
      _area = area;
    });
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(kitchenFiltersProvider).value;
    final key = (q: _q, category: _category, area: _area);
    final results = ref.watch(discoverProvider(key));
    final heading = _q.isNotEmpty
        ? 'Results for “$_q”'
        : ([_area, _category].whereType<String>().join(' ').ifEmpty('Everything') ?? 'Everything');

    return NxPage(
      onRefresh: () async {
        ref.invalidate(discoverProvider(key));
        await ref.read(discoverProvider(key).future);
      },
      children: [
        NxStage(
          compact: true,
          eyebrow: 'Kitchen · TheMealDB',
          title: 'What should we',
          accent: 'cook?',
          lede: 'Browse by category or cuisine, open anything that looks good, and save the keepers.',
          actions: [NxButton('Surprise me', icon: LucideIcons.dices, onPressed: () => surpriseMeal(context, ref))],
        ),
        const SizedBox(height: 22),
        const KitchenNav(value: 'discover'),
        const SizedBox(height: 12),
        NxSearchField(controller: _search, hint: 'Search meals…', onSubmitted: (v) => setState(() => _q = v.trim())),
        const SizedBox(height: 12),
        NxFormRow(
          children: [
            NxPickerField<String>(
              label: 'Category',
              options: [for (final c in filters?.strings('categories') ?? const <String>[]) (c, c)],
              value: _category,
              onChanged: (v) => _browse(category: v, area: _area),
            ),
            NxPickerField<String>(
              label: 'Cuisine',
              options: [for (final a in filters?.strings('areas') ?? const <String>[]) (a, a)],
              value: _area,
              searchable: true,
              onChanged: (v) => _browse(category: _category, area: v),
            ),
          ],
        ),
        NxSectionHeader(heading),
        NxAsync(
          value: results,
          onRetry: () => ref.invalidate(discoverProvider(key)),
          loading: const NxGrid(
            children: [
              NxSkeleton(height: 190, radius: NxRadius.md),
              NxSkeleton(height: 190, radius: NxRadius.md),
              NxSkeleton(height: 190, radius: NxRadius.md),
              NxSkeleton(height: 190, radius: NxRadius.md),
            ],
          ),
          data: (meals) => meals.isEmpty
              ? NxEmptyState(
                  title: 'No meals found',
                  body: 'Try a different search, or clear the filters to browse everything in a category.',
                  icon: LucideIcons.search,
                  actionLabel: 'Browse seafood',
                  onAction: () => _browse(category: _defaultCategory),
                )
              : NxGrid(
                  children: [
                    for (final m in meals)
                      NxCoverCard(
                        key: ValueKey(m['mealdb_id']),
                        title: m.text('name', 'Meal'),
                        subtitle: [m.str('category'), m.str('area')].whereType<String>().join(' · ').ifEmpty(null),
                        url: m.str('thumb_url'),
                        fallbackIcon: LucideIcons.chefHat,
                        onTap: () => context.push('/kitchen/discover/${m.str('mealdb_id')}'),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

extension on String {
  String? ifEmpty(String? fallback) => isEmpty ? fallback : this;
}
