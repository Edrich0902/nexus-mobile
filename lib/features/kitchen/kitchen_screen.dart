import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/core/api/paged.dart';
import 'package:nexus_mobile/core/format.dart';
import 'package:nexus_mobile/design/debounced_search.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';
import 'package:nexus_mobile/features/collections/collection_fields.dart';
import 'package:nexus_mobile/features/collections/collection_index.dart';
import 'package:nexus_mobile/features/collections/prints.dart';
import 'package:nexus_mobile/features/kitchen/kitchen_api.dart';

/// Saved / Discover pills shared by the kitchen pages (web kitchenNav).
class KitchenNav extends StatelessWidget {
  const KitchenNav({required this.value, super.key});

  final String value;

  @override
  Widget build(BuildContext context) => NxPillNav<String>(
    items: const [('saved', 'Saved'), ('discover', 'Discover')],
    value: value,
    onChanged: (v) => context.go(v == 'saved' ? '/kitchen' : '/kitchen/discover'),
  );
}

/// Opens a random TheMealDB meal (web "Surprise me").
Future<void> surpriseMeal(BuildContext context, WidgetRef ref) async {
  try {
    final meal = await ref.read(kitchenApiProvider).random();
    final id = meal.str('mealdb_id');
    if (id != null && context.mounted) unawaited(context.push('/kitchen/discover/$id'));
  } on Object catch (e) {
    if (context.mounted) showApiError(context, e);
  }
}

const _verdictRank = {'great': 2, 'good': 1, 'poor': 0};

/// Saved recipes (web KitchenView).
class KitchenScreen extends ConsumerStatefulWidget {
  const KitchenScreen({super.key});

  @override
  ConsumerState<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends ConsumerState<KitchenScreen> with DebouncedSearch {
  bool _favourites = false;

  PageQuery get _query => recipeQuery(q: searched, favourites: _favourites);

  /// The best-rated drink for each recipe; poor matches are not suggested.
  Map<int, String> _pairs(List<Json> pairings) {
    final best = <int, (String, int)>{};
    for (final p in pairings) {
      final rank = _verdictRank[p.str('verdict')] ?? 0;
      final name = p.str('drinkable_name');
      final recipe = p.integer('kitchen_recipe_id');
      if (rank == 0 || name == null || recipe == null) continue;
      if ((best[recipe]?.$2 ?? -1) < rank) best[recipe] = (name, rank);
    }
    return best.map((k, v) => MapEntry(k, v.$1));
  }

  List<CollectionField> _fields(List<Json> recipes) {
    final cooked = recipes.fold<int>(0, (s, r) => s + (r.integer('cooked_count') ?? 0));
    final favourites = recipes.where((r) => r.flag('is_favourite')).length;
    final most = recipes.isEmpty
        ? null
        : (List.of(
            recipes,
          )..sort((a, b) => (b.integer('cooked_count') ?? 0).compareTo(a.integer('cooked_count') ?? 0))).first;
    return [
      CollectionField(key: 'saved', label: 'Saved', value: '${recipes.length}', sub: plural(favourites, 'favourite')),
      CollectionField(
        key: 'cooked',
        label: 'Times cooked',
        value: '$cooked',
        sub: 'across your saved recipes',
        variant: FieldVariant.tint,
      ),
      if (most != null && (most.integer('cooked_count') ?? 0) > 0)
        CollectionField(
          key: 'most',
          label: 'Most cooked',
          title: most.obj('meal')?.str('name') ?? 'Recipe',
          sub: '${most.integer('cooked_count')}× so far',
          variant: FieldVariant.tint,
          span: 2,
          to: '/kitchen/recipes/${most.integer('id')}',
        )
      else
        const CollectionField(
          key: 'most',
          label: 'Most cooked',
          title: 'Cook something and mark it done',
          variant: FieldVariant.outline,
          span: 2,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(pagedProvider(recipeQuery())).value;
    final pairs = _pairs(ref.watch(pairingsProvider).value ?? const []);

    return NxPage(
      onRefresh: () async {
        ref
          ..invalidate(pagedProvider(_query))
          ..invalidate(pairingsProvider);
        await ref.read(pagedProvider(_query).future);
      },
      children: [
        NxStage(
          compact: true,
          eyebrow: 'Kitchen',
          title: 'Recipes',
          accent: 'worth keeping',
          lede: 'Meals saved from TheMealDB, with what you thought of them and how often they made it to the table.',
          actions: [
            NxButton('Discover', icon: LucideIcons.compass, onPressed: () => context.go('/kitchen/discover')),
            NxButton(
              'Surprise me',
              icon: LucideIcons.dices,
              variant: NxButtonVariant.secondary,
              onPressed: () => surpriseMeal(context, ref),
            ),
          ],
        ),
        if (all != null && all.items.isNotEmpty)
          CollectionFields(section: SectionKey.kitchen, fields: _fields(all.items)),
        const SizedBox(height: 22),
        const KitchenNav(value: 'saved'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: NxSearchField(
                controller: searchController,
                hint: 'Search saved recipes…',
                onChanged: onSearchChanged,
                onSubmitted: submitSearch,
              ),
            ),
            const SizedBox(width: 10),
            NxIconButton(
              _favourites ? Icons.favorite_rounded : LucideIcons.heart,
              tooltip: _favourites ? 'Show all' : 'Favourites only',
              filled: true,
              color: _favourites ? context.nx.acc : null,
              onPressed: () => setState(() => _favourites = !_favourites),
            ),
          ],
        ),
        PagedPrints(
          query: _query,
          filterLabel: 'Tags',
          toPrint: (r) => recipePrint(r, pair: pairs[r.integer('id')]),
          empty: NxEmptyState(
            title: 'No saved recipes yet',
            body: 'Browse TheMealDB, open something that looks good and save it here.',
            icon: LucideIcons.chefHat,
            actionLabel: 'Discover recipes',
            onAction: () => context.go('/kitchen/discover'),
          ),
          noMatch: NxEmptyState(
            title: 'Nothing matches',
            body: _favourites ? 'No favourites match that search yet.' : 'Try another ingredient or dish name.',
            icon: LucideIcons.search,
          ),
        ),
      ],
    );
  }
}
