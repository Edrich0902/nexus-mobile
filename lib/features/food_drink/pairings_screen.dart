import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nexus_mobile/core/api/api_client.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';
import 'package:nexus_mobile/features/food_drink/food_drink_screen.dart';
import 'package:nexus_mobile/features/kitchen/kitchen_api.dart';

const _verdicts = <(String, String)>[('great', 'Great match'), ('good', 'Good'), ('poor', 'Didn’t work')];

/// Wines, beers and recipes to pick from when saving a pairing (first 50 of
/// each, newest first — matches the web picker's loaded lists).
final pairingOptionsProvider =
    FutureProvider.autoDispose<({List<(int, String)> wines, List<(int, String)> beers, List<(int, String)> recipes})>((
      ref,
    ) async {
      final api = ref.watch(apiClientProvider);
      Future<List<Json>> load(String path) async => asJsonList(await api.get(path, query: {'per_page': 50}));
      final [wines, beers, recipes] = await Future.wait([
        load('/cellar/wines'),
        load('/beer/beers'),
        load('/kitchen/recipes'),
      ]);
      List<(int, String)> opts(List<Json> list, String Function(Json) name) => [
        for (final j in list) (j.integer('id') ?? 0, name(j)),
      ];
      return (
        wines: opts(wines, (w) => w.text('name')),
        beers: opts(beers, (b) => b.text('name')),
        recipes: opts(recipes, (r) => r.obj('meal')?.str('name') ?? 'Recipe #${r['id']}'),
      );
    });

/// Food & drink pairings (web FoodDrinkPairingsView).
class PairingsScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.nx;
    final pairings = ref.watch(pairingsProvider);
    final suggestions = ref.watch(suggestionsProvider).value ?? const [];
    final list = pairings.value ?? const [];

    return NxPage(
      onRefresh: () async {
        ref
          ..invalidate(pairingsProvider)
          ..invalidate(suggestionsProvider);
        await ref.read(pairingsProvider.future);
      },
      children: [
        NxStage(
          compact: true,
          eyebrow: 'Food & Drink',
          title: 'Pairings',
          accent: 'that worked',
          lede: 'Which bottle went with which dish — and the ones worth trying next.',
          actions: [NxButton('Save a pairing', icon: LucideIcons.plus, onPressed: () => showPairingSheet(context))],
        ),
        const SizedBox(height: 22),
        const FoodDrinkNav(value: 'pairings'),
        NxSectionHeader('Your pairings · ${list.length}'),
        if (pairings.isLoading && pairings.value == null)
          const NxSkeleton(height: 160, radius: NxRadius.xl)
        else if (pairings.hasError && pairings.value == null)
          NxErrorState(error: pairings.error!, compact: true, onRetry: () => ref.invalidate(pairingsProvider))
        else
          NxPanel(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: list.isEmpty
                ? NxEmptyState(
                    compact: true,
                    title: 'No pairings saved',
                    body: 'Next time a bottle and a dish click, save it here so you can repeat it.',
                    actionLabel: 'Save a pairing',
                    onAction: () => showPairingSheet(context),
                  )
                : Column(
                    children: [for (var i = 0; i < list.length; i++) _PairingRow(pairing: list[i], first: i == 0)],
                  ),
          ),
        const NxSectionHeader('Worth trying'),
        NxPanel(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: suggestions.isEmpty
              ? const NxEmptyState(
                  compact: true,
                  title: 'Nothing to suggest yet',
                  body: 'Suggestions appear once you have drinks and recipes saved.',
                )
              : Column(
                  children: [
                    for (var i = 0; i < suggestions.length; i++)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          border: i == 0 ? null : Border(top: BorderSide(color: c.line)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  PairLine(
                                    drink: suggestions[i].text('drink_name'),
                                    recipe: suggestions[i].text('recipe_name'),
                                  ),
                                  if (suggestions[i].strings('reasons').isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        suggestions[i].strings('reasons').join(' · '),
                                        style: NxText.sans(size: 13, color: c.ink3),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            NxButton(
                              'Save',
                              compact: true,
                              variant: NxButtonVariant.ghost,
                              onPressed: () => showPairingSheet(
                                context,
                                preset: (
                                  type: suggestions[i].str('drinkable_type') ?? 'wine',
                                  drinkId: suggestions[i].integer('drinkable_id'),
                                  recipeId: suggestions[i].integer('recipe_id'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _PairingRow extends ConsumerWidget {
  const new({required this.pairing, required this.first});

  final Json pairing;
  final bool first;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.nx;
    final p = pairing;
    final verdict = p.str('verdict') ?? 'good';
    final type = p.str('drinkable_type');
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: first ? null : Border(top: BorderSide(color: c.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KindDot(beer: type == 'beer'),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PairLine(
                  drink: p.text('drinkable_name', 'A drink'),
                  recipe: p.text('recipe_name', 'a dish'),
                  onDrink: () => context.push(drinkRoute(type, p.integer('drinkable_id'))),
                  onRecipe: () => context.push('/kitchen/recipes/${p.integer('kitchen_recipe_id')}'),
                ),
                if (p.str('notes') case final notes?)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(notes, style: NxText.sans(size: 13, color: c.ink3)),
                  ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: verdict == 'great' ? c.acc.withValues(alpha: .22) : c.tint,
                    borderRadius: BorderRadius.circular(NxRadius.pill),
                  ),
                  child: Text(
                    _verdicts.firstWhere((v) => v.$1 == verdict, orElse: () => _verdicts[1]).$2,
                    style: NxText.sans(
                      size: 12,
                      weight: FontWeight.w600,
                      color: verdict == 'great' ? c.ink : (verdict == 'poor' ? c.ink3 : c.ink2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          NxIconButton(
            LucideIcons.trash2,
            tooltip: 'Delete pairing',
            size: 34,
            onPressed: () async {
              final ok = await showNxConfirm(context, message: 'Delete this pairing?');
              if (!ok) return;
              try {
                await ref.read(kitchenApiProvider).deletePairing(p.integer('id') ?? 0);
              } on Object catch (e) {
                if (context.mounted) showApiError(context, e);
              }
            },
          ),
        ],
      ),
    );
  }
}

typedef PairingPreset = ({String type, int? drinkId, int? recipeId});

/// Save which bottle went with which dish (web NexusPairingPicker).
Future<void> showPairingSheet(BuildContext context, {PairingPreset? preset}) => showNxSheet<void>(
  context,
  title: 'Save a pairing',
  builder: (_) => _PairingForm(preset: preset),
);

class _PairingForm extends ConsumerStatefulWidget {
  const new({this.preset});

  final PairingPreset? preset;

  @override
  ConsumerState<_PairingForm> createState() => _PairingFormState();
}

class _PairingFormState extends ConsumerState<_PairingForm> {
  late String _type = widget.preset?.type ?? 'wine';
  late int? _drink = widget.preset?.drinkId;
  late int? _recipe = widget.preset?.recipeId;
  String _verdict = 'good';
  final _notes = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_drink == null || _recipe == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(kitchenApiProvider).createPairing({
        'drinkable_type': _type,
        'drinkable_id': _drink,
        'kitchen_recipe_id': _recipe,
        'verdict': _verdict,
        'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      });
      if (mounted) Navigator.of(context).pop();
    } on Object catch (e) {
      if (mounted) showApiError(context, e, 'Could not save the pairing.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = ref.watch(pairingOptionsProvider).value;
    final drinks = _type == 'wine' ? options?.wines : options?.beers;
    return SingleChildScrollView(
      child: Column(
        children: [
          NxForm(
            children: [
              NxFormSlot(
                label: 'Drink',
                child: NxPillNav<String>(
                  items: const [('wine', 'Wine'), ('beer', 'Beer')],
                  value: _type,
                  onChanged: (v) => setState(() {
                    if (v != _type) _drink = null;
                    _type = v;
                  }),
                ),
              ),
              NxPickerField<int>(
                label: _type == 'wine' ? 'Wine' : 'Beer',
                options: drinks ?? const [],
                value: _drink,
                searchable: true,
                onChanged: (v) => setState(() => _drink = v),
              ),
              NxPickerField<int>(
                label: 'Recipe',
                options: options?.recipes ?? const [],
                value: _recipe,
                searchable: true,
                onChanged: (v) => setState(() => _recipe = v),
              ),
              NxFormSlot(
                label: 'How was it?',
                child: NxPillNav<String>(
                  items: _verdicts,
                  value: _verdict,
                  onChanged: (v) => setState(() => _verdict = v),
                ),
              ),
              NxTextField(label: 'Notes', controller: _notes, maxLines: 2),
            ],
          ),
          NxSheetActions(
            label: 'Save pairing',
            busy: _saving,
            onSubmit: _drink == null || _recipe == null ? null : _save,
          ),
        ],
      ),
    );
  }
}
