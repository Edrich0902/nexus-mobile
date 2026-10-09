import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/core/media/cloudinary.dart';
import 'package:nexus_mobile/core/media/media_image.dart';
import 'package:nexus_mobile/core/media/pick_image.dart';
import 'package:nexus_mobile/design/art_ambient.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';
import 'package:nexus_mobile/features/collections/prints.dart';
import 'package:nexus_mobile/features/kitchen/kitchen_api.dart';
import 'package:url_launcher/url_launcher.dart';

/// Method text → steps (web NexusRecipeDetail): line breaks first, then
/// sentences when the method is one block.
List<String> recipeSteps(String? instructions) {
  final raw = (instructions ?? '').trim();
  if (raw.isEmpty) return const [];
  final byBreak = raw
      .split(RegExp(r'\r?\n+'))
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty && !RegExp(r'^step\s*\d+:?$', caseSensitive: false).hasMatch(l))
      .map((l) => l.replaceFirst(RegExp(r'^(step\s*)?\d+[).\-:]?\s+', caseSensitive: false), ''))
      .toList();
  if (byBreak.length > 1) return byBreak;
  final sentences = raw
      .split(RegExp(r'(?<=[.!?])\s+(?=[A-Z])'))
      .map((s) => s.trim())
      .where((s) => s.length > 12)
      .toList();
  return sentences.length > 1 ? sentences : [raw];
}

/// A recipe page: dish photo and serif name on the stage, ingredients, then
/// the numbered method. Shared by saved recipes and TheMealDB previews.
class RecipeDetail extends StatelessWidget {
  const RecipeDetail({
    required this.meal,
    required this.eyebrow,
    required this.actions,
    this.media,
    this.imageUrl,
    this.meta = const [],
    this.onRefresh,
    super.key,
  });

  final Json meal;
  final String eyebrow;
  final List<Widget> actions;
  final MediaImage? media;
  final String? imageUrl;
  final List<Widget> meta;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    final hero = imageUrl ?? meal.str('thumb_url');
    final ingredients = meal.list('ingredients');
    final steps = recipeSteps(meal.str('instructions'));
    final tags = meal.strings('tags').where((t) => t.trim().isNotEmpty).take(4).toList();
    final lede = [
      if (meal.str('area') case final a?) '$a cooking',
      meal.str('category'),
      '${ingredients.length} ingredients',
    ].whereType<String>().join(' · ');
    final links = [
      if (meal.str('youtube_url') case final u?) ('Watch it made', u),
      if (meal.str('source_url') case final u?) ('Original recipe', u),
    ];

    return ArtAmbient(
      media: media,
      url: hero,
      child: NxPage(
        onRefresh: onRefresh,
        children: [
          NxStage(
            eyebrow: eyebrow,
            title: meal.text('name', 'Recipe'),
            lede: lede,
            visual: GestureDetector(
              onTap: () => showImagePreview(context, media: media, url: hero, label: meal.str('name')),
              child: NxImage(
                media: media,
                url: hero,
                variant: MediaVariant.hero,
                fallbackIcon: LucideIcons.chefHat,
                semanticLabel: meal.str('name'),
              ),
            ),
            actions: actions,
            below: meta.isEmpty && tags.isEmpty
                ? null
                : Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [...meta, for (final t in tags) NxChip(t)],
                    ),
                  ),
          ),
          NxSectionHeader('Ingredients · ${ingredients.length}'),
          NxPanel(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                for (var i = 0; i < ingredients.length; i++)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      border: i == 0 ? null : Border(top: BorderSide(color: c.line)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(
                          child: Text(
                            ingredients[i].text('name'),
                            style: NxText.sans(size: 14.5, color: c.ink),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          ingredients[i].str('measure') ?? '—',
                          textAlign: TextAlign.right,
                          style: NxText.sans(color: c.ink3),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (links.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Wrap(
                spacing: 10,
                children: [
                  for (final (label, url) in links)
                    if (Uri.tryParse(url) case final uri? when uri.scheme.startsWith('http'))
                      NxButton(
                        label,
                        icon: LucideIcons.externalLink,
                        compact: true,
                        variant: NxButtonVariant.ghost,
                        onPressed: () => launchUrl(uri, mode: LaunchMode.externalApplication),
                      ),
                ],
              ),
            ),
          NxSectionHeader('Method · ${steps.length} steps'),
          for (var i = 0; i < steps.length; i++)
            Container(
              padding: EdgeInsets.only(top: i == 0 ? 4 : 18, bottom: 18),
              decoration: BoxDecoration(
                border: i == 0 ? null : Border(top: BorderSide(color: c.line)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 46,
                    child: ExcludeSemantics(
                      child: Text(
                        '${i + 1}'.padLeft(2, '0'),
                        style: NxText.display(size: 26, color: c.acc),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Semantics(
                      label: 'Step ${i + 1}',
                      child: Text(steps[i], style: NxText.sans(size: 16, color: c.ink2, height: 1.65)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A saved recipe (web KitchenRecipeView).
class SavedRecipeScreen extends ConsumerWidget {
  const SavedRecipeScreen({required this.id, super.key});

  final int id;

  Future<void> _run(BuildContext context, Future<void> Function() task, [String? done]) async {
    try {
      await task();
      if (done != null && context.mounted) showNxToast(context, done);
    } on Object catch (e) {
      if (context.mounted) showApiError(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NxAsync(
      value: ref.watch(recipeProvider(id)),
      onRetry: () => ref.invalidate(recipeProvider(id)),
      loading: const NxPage(children: [NxPageSkeleton()]),
      data: (r) {
        final api = ref.read(kitchenApiProvider);
        final meal = r.obj('meal');
        if (meal == null) {
          return const NxPage(
            children: [NxEmptyState(title: 'Recipe not found', icon: LucideIcons.chefHat)],
          );
        }
        final fav = r.flag('is_favourite');
        final cooked = r.integer('cooked_count') ?? 0;
        final last = shortDay(r.str('last_cooked_on'));
        return RecipeDetail(
          meal: meal,
          eyebrow: 'Saved recipe',
          media: MediaImage.fromJson(r.obj('media')),
          imageUrl: r.str('image_url'),
          onRefresh: () async {
            ref.invalidate(recipeProvider(id));
            await ref.read(recipeProvider(id).future);
          },
          actions: [
            NxButton(
              'Cooked it',
              icon: LucideIcons.check,
              onPressed: () => _run(context, () => api.markCooked(id), 'Marked as cooked'),
            ),
            NxIconButton(
              fav ? Icons.favorite_rounded : LucideIcons.heart,
              tooltip: fav ? 'Remove from favourites' : 'Add to favourites',
              filled: true,
              color: fav ? context.nx.acc : null,
              onPressed: () => _run(context, () => api.update(id, {'is_favourite': !fav})),
            ),
            NxIconButton(
              LucideIcons.image,
              tooltip: 'Change photo',
              filled: true,
              onPressed: () async {
                final image = await pickAndUploadImage(
                  context,
                  ref,
                  collection: 'kitchen',
                  attachType: 'kitchen_recipe',
                  attachId: id,
                  title: 'Recipe photo',
                );
                if (image != null) api.imageAttached(id);
              },
            ),
            NxIconButton(
              LucideIcons.trash2,
              tooltip: 'Remove recipe',
              filled: true,
              onPressed: () async {
                final ok = await showNxConfirm(
                  context,
                  message: 'Remove this recipe from your collection?',
                  confirmLabel: 'Remove',
                );
                if (!ok || !context.mounted) return;
                await _run(context, () async {
                  await api.remove(id);
                  if (context.mounted) context.go('/kitchen');
                });
              },
            ),
          ],
          meta: [
            Semantics(
              button: true,
              label: 'Change rating',
              child: NxPressable(
                onTap: () => _rate(context, ref, r.number('rating')),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: context.nx.tint,
                    borderRadius: BorderRadius.circular(NxRadius.pill),
                  ),
                  child: r.number('rating') == null
                      ? Text('Rate it', style: NxText.sans(size: 13, color: context.nx.ink2))
                      : NxRating(r.number('rating')),
                ),
              ),
            ),
            Text(
              'Cooked $cooked×${last == null ? '' : ' · last on $last'}',
              style: NxText.sans(color: context.nx.ink3),
            ),
          ],
        );
      },
    );
  }

  Future<void> _rate(BuildContext context, WidgetRef ref, double? current) async {
    final value = await showNxSheet<(double?,)>(
      context,
      title: 'Rate this recipe',
      builder: (sheet) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: NxRatingInput(value: current, size: 40, onChanged: (v) => Navigator.of(sheet).pop((v,))),
        ),
      ),
    );
    if (value == null || !context.mounted) return;
    await _run(context, () => ref.read(kitchenApiProvider).update(id, {'rating': value.$1}));
  }
}

/// A TheMealDB meal before it's saved (web KitchenMealPreviewView).
class MealPreviewScreen extends ConsumerStatefulWidget {
  const MealPreviewScreen({required this.mealdbId, super.key});

  final String mealdbId;

  @override
  ConsumerState<MealPreviewScreen> createState() => _MealPreviewScreenState();
}

class _MealPreviewScreenState extends ConsumerState<MealPreviewScreen> {
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final saved = await ref.read(kitchenApiProvider).save(widget.mealdbId);
      if (mounted) context.pushReplacement('/kitchen/recipes/${saved.integer('id')}');
    } on Object catch (e) {
      if (mounted) showApiError(context, e, 'Could not save the recipe.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return NxAsync(
      value: ref.watch(mealProvider(widget.mealdbId)),
      onRetry: () => ref.invalidate(mealProvider(widget.mealdbId)),
      loading: const NxPage(children: [NxPageSkeleton()]),
      data: (meal) => RecipeDetail(
        meal: meal,
        eyebrow: 'From TheMealDB',
        actions: [NxButton('Save to my recipes', icon: LucideIcons.bookmark, loading: _saving, onPressed: _save)],
      ),
    );
  }
}
