import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/core/format.dart';
import 'package:nexus_mobile/core/media/media_image.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';
import 'package:nexus_mobile/features/collections/analysis_panel.dart';
import 'package:nexus_mobile/features/collections/drinks_api.dart';
import 'package:nexus_mobile/features/home/home_modules.dart';

/// Overview / Pairings pills (web foodDrinkNav).
class FoodDrinkNav extends StatelessWidget {
  const new({required this.value, super.key});

  final String value;

  @override
  Widget build(BuildContext context) => NxPillNav<String>(
    items: const [('overview', 'Overview'), ('pairings', 'Pairings')],
    value: value,
    onChanged: (v) => context.go(v == 'overview' ? '/food-drink' : '/food-drink/pairings'),
  );
}

String drinkRoute(String? type, int? id) => type == 'beer' ? '/beer/beers/$id' : '/cellar/wines/$id';

/// "Pinotage *with* Bobotie" (web `.pair em`).
class PairLine extends StatelessWidget {
  const new({required this.drink, required this.recipe, this.onDrink, this.onRecipe, super.key});

  final String drink;
  final String recipe;
  final VoidCallback? onDrink;
  final VoidCallback? onRecipe;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    final strong = NxText.sans(size: 15, weight: FontWeight.w600, color: c.ink);
    Widget part(String text, VoidCallback? onTap) => onTap == null
        ? Text(text, style: strong)
        : GestureDetector(
            onTap: onTap,
            child: Text(text, style: strong),
          );
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: 5,
      children: [
        part(drink, onDrink),
        Text(
          'with',
          style: NxText.serif(size: 17, height: 1.2, color: c.acc, style: FontStyle.italic),
        ),
        part(recipe, onRecipe),
      ],
    );
  }
}

class KindDot extends StatelessWidget {
  const new({required this.beer, super.key});

  final bool beer;

  @override
  Widget build(BuildContext context) => Container(
    width: 36,
    height: 36,
    decoration: BoxDecoration(shape: BoxShape.circle, color: context.nx.tint),
    child: Icon(beer ? LucideIcons.beer : LucideIcons.wine, size: 16, color: context.nx.acc),
  );
}

class _Recent {
  const new(this.key, this.kind, this.title, this.sub, this.media, this.src, this.rating, this.to, this.icon);

  final String key;
  final String kind;
  final String title;
  final String? sub;
  final MediaImage? media;
  final String? src;
  final double? rating;
  final String to;
  final IconData icon;
}

/// Food & Drink overview (web FoodDrinkView).
class FoodDrinkScreen extends ConsumerWidget {
  const new({super.key});

  List<_Recent> _recent(Json d) {
    _Recent r(Json j, String kind, IconData icon, String title, String? sub, String to, [String? src]) => _Recent(
      '$kind-${j['id']}',
      kind,
      title,
      sub,
      MediaImage.fromJson(j.obj('media')),
      src ?? j.str('image_url'),
      j.number('rating'),
      to,
      icon,
    );
    final lanes = [
      [
        for (final w in d.list('recent_wines'))
          r(w, 'Wine', LucideIcons.wine, w.text('name'), w.str('producer_name'), '/cellar/wines/${w['id']}'),
      ],
      [
        for (final b in d.list('recent_beers'))
          r(b, 'Beer', LucideIcons.beer, b.text('name'), b.obj('brewery')?.str('name'), '/beer/beers/${b['id']}'),
      ],
      [
        for (final s in d.list('recent_spirits'))
          r(s, 'Spirit', LucideIcons.glassWater, s.text('name'), s.str('producer'), '/spirits/${s['id']}'),
      ],
      [
        for (final x in d.list('top_recipes'))
          r(
            x,
            'Recipe',
            LucideIcons.chefHat,
            x.obj('meal')?.str('name') ?? 'Recipe',
            (x.integer('cooked_count') ?? 0) > 0 ? 'Cooked ${x.integer('cooked_count')}×' : null,
            '/kitchen/recipes/${x['id']}',
            x.str('image_url') ?? x.obj('meal')?.str('thumb_url'),
          ),
      ],
    ];
    // Interleave so one busy module doesn't crowd out the rest.
    final out = <_Recent>[];
    for (var i = 0; out.length < 8 && lanes.any((l) => i < l.length); i++) {
      for (final lane in lanes) {
        if (i < lane.length && out.length < 8) out.add(lane[i]);
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(foodDrinkDashboardProvider);
    final d = value.value;
    Future<void> refresh() async {
      ref
        ..invalidate(foodDrinkDashboardProvider)
        ..invalidate(analysisQuotaProvider);
      await ref.read(foodDrinkDashboardProvider.future);
    }

    if (d == null || d.isEmpty) {
      return NxPage(
        onRefresh: refresh,
        children: [
          if (value.isLoading)
            const NxPageSkeleton()
          else
            NxEmptyState(
              title: 'Could not load Food & Drink',
              icon: LucideIcons.circleAlert,
              actionLabel: 'Try again',
              onAction: () => ref.invalidate(foodDrinkDashboardProvider),
            ),
        ],
      );
    }

    final c = context.nx;
    final counts = d.obj('counts') ?? const {};
    int n(String k) => counts.integer(k) ?? 0;
    final recent = _recent(d);
    final mosaic = recent.where((r) => r.media != null || r.src != null).take(4).toList();
    final total = n('wines') + n('beers') + n('spirits');
    final suggestions = d.list('suggestions').take(5).toList();
    final mix = [
      ('Wine', n('wines'), SectionKey.cellar.field.bg),
      ('Beer', n('beers'), SectionKey.beer.field.bg),
      ('Spirits', n('spirits'), SectionKey.spirits.field.bg),
      ('Recipes', n('recipes'), SectionKey.kitchen.field.bg),
    ].where((m) => m.$2 > 0).toList();

    NxField field(SectionKey s, String label, int value, String sub, String to, {int span = 1}) => NxField(
      key: ValueKey(label),
      bg: s.field.bg,
      ink: s.field.ink,
      label: label,
      value: '$value',
      sub: sub,
      span: span,
      minHeight: 116,
      onTap: () => context.go(to),
    );

    return NxPage(
      onRefresh: refresh,
      children: [
        NxStage(
          eyebrow: 'Food & Drink',
          title: 'What you',
          accent: 'taste',
          lede: '${plural(total, 'drink')} and ${plural(n('recipes'), 'recipe')} so far — here is what goes together.',
          visual: mosaic.isEmpty ? null : _Mosaic(items: mosaic),
        ),
        NxBento(
          children: [
            field(SectionKey.cellar, 'Wine', n('wines'), plural(n('wines'), 'bottle'), '/cellar'),
            field(SectionKey.beer, 'Beer', n('beers'), '${plural(n('beers'), 'beer')} logged', '/beer'),
            field(SectionKey.spirits, 'Spirits', n('spirits'), 'on the shelf', '/spirits'),
            field(SectionKey.kitchen, 'Recipes', n('recipes'), 'saved', '/kitchen'),
            field(SectionKey.foodDrink, 'Pairings', n('pairings'), 'that worked', '/food-drink/pairings', span: 2),
          ],
        ),
        const SizedBox(height: 22),
        const Row(
          children: [
            FoodDrinkNav(value: 'overview'),
            Spacer(),
            QuotaBadge(),
          ],
        ),
        NxSectionHeader('Try tonight', actionLabel: 'All pairings', onAction: () => context.go('/food-drink/pairings')),
        NxPanel(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: suggestions.isEmpty
              ? const NxEmptyState(
                  compact: true,
                  title: 'No suggestions yet',
                  body: 'Save a few wines or beers and some recipes, and matches will show up here.',
                )
              : Column(
                  children: [
                    for (var i = 0; i < suggestions.length; i++)
                      NxPressable(
                        scale: .985,
                        onTap: () => context.push(
                          drinkRoute(suggestions[i].str('drinkable_type'), suggestions[i].integer('drinkable_id')),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            border: i == 0 ? null : Border(top: BorderSide(color: c.line)),
                          ),
                          child: Row(
                            children: [
                              KindDot(beer: suggestions[i].str('drinkable_type') == 'beer'),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    PairLine(
                                      drink: suggestions[i].text('drink_name'),
                                      recipe: suggestions[i].text('recipe_name'),
                                    ),
                                    if (suggestions[i].strings('reasons').firstOrNull case final why?)
                                      Text(
                                        why,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: NxText.sans(size: 13, color: c.ink3),
                                      ),
                                  ],
                                ),
                              ),
                              Icon(LucideIcons.chevronRight, size: 16, color: c.ink4),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
        const NxSectionHeader('Collection mix'),
        NxPanel(
          child: mix.isEmpty
              ? const NxEmptyState(
                  compact: true,
                  title: 'Nothing to chart yet',
                  body: 'Add a bottle or a recipe to start.',
                )
              : NxDonut(mix, centreLabel: 'in the collection'),
        ),
        if (recent.isNotEmpty) ...[
          const NxSectionHeader('Recently added'),
          NxGrid(
            children: [
              for (final r in recent)
                NxCoverCard(
                  key: ValueKey(r.key),
                  title: r.title,
                  subtitle: r.sub,
                  media: r.media,
                  url: r.src,
                  rating: r.rating,
                  badge: r.kind,
                  fallbackIcon: r.icon,
                  aspect: r.kind == 'Recipe' ? 1 : 3 / 4,
                  onTap: () => context.push(r.to),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Mosaic extends StatelessWidget {
  const new({required this.items});

  final List<_Recent> items;

  @override
  Widget build(BuildContext context) {
    Widget tile(_Recent r) => NxImage(media: r.media, url: r.src);
    Widget gap(Widget a, Widget b, Axis axis) => Flex(
      direction: axis,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: a),
        const SizedBox(width: 3, height: 3),
        Expanded(child: b),
      ],
    );
    return switch (items.length) {
      1 => tile(items[0]),
      2 => gap(tile(items[0]), tile(items[1]), Axis.horizontal),
      3 => gap(tile(items[0]), gap(tile(items[1]), tile(items[2]), Axis.vertical), Axis.horizontal),
      _ => gap(
        gap(tile(items[0]), tile(items[1]), Axis.horizontal),
        gap(tile(items[2]), tile(items[3]), Axis.horizontal),
        Axis.vertical,
      ),
    };
  }
}
