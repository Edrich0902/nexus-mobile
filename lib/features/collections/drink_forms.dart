import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nexus_mobile/core/api/api_error.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';
import 'package:nexus_mobile/features/collections/drink_kind.dart';
import 'package:nexus_mobile/features/collections/drinks_api.dart';

/// Add a wine / beer / spirit (web CellarView, BeerView, SpiritsView create
/// dialogs). Resolves with the created record.
Future<Json?> showDrinkCreateSheet(BuildContext context, DrinkKind kind) => showNxSheet<Json>(
  context,
  title: kind.copy.add,
  expand: true,
  builder: (_) => _DrinkCreateForm(kind: kind),
);

class _DrinkCreateForm extends ConsumerStatefulWidget {
  const _DrinkCreateForm({required this.kind});

  final DrinkKind kind;

  @override
  ConsumerState<_DrinkCreateForm> createState() => _DrinkCreateFormState();
}

class _DrinkCreateFormState extends ConsumerState<_DrinkCreateForm> {
  final _name = TextEditingController();
  final _producer = TextEditingController();
  final _vintage = TextEditingController();
  final _style = TextEditingController();
  final _region = TextEditingController();
  final _country = TextEditingController();
  final _abv = TextEditingController();
  final _age = TextEditingController();
  final _notes = TextEditingController();
  double? _rating;
  int? _beerStyleId;
  String _format = 'can';
  String? _category;
  Json? _brewery;
  bool _saving = false;
  ApiError? _error;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [_name, _producer, _vintage, _style, _region, _country, _abv, _age, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _t(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
  double? _n(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.'));

  Json _payload() => switch (widget.kind) {
    DrinkKind.wine => {
      'name': _name.text.trim(),
      'producer_name': _t(_producer),
      'vintage': int.tryParse(_vintage.text.trim()),
      'wine_type': _t(_style),
      'region_name': _t(_region),
      'country': _t(_country),
      'rating': _rating,
      'notes': _t(_notes),
    },
    DrinkKind.beer => {
      'name': _name.text.trim(),
      'beer_brewery_id': _brewery?.integer('id'),
      'beer_style_id': _beerStyleId,
      'abv': _n(_abv),
      'format': _format,
      'rating': _rating,
      'notes': _t(_notes),
    },
    DrinkKind.spirit => {
      'name': _name.text.trim(),
      'producer': _t(_producer),
      'category': _category,
      'age_statement': _t(_age),
      'abv': _n(_abv),
      'rating': _rating,
      'notes': _t(_notes),
    },
  };

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final created = await ref.read(drinksApiProvider).create(widget.kind, _payload());
      if (mounted) Navigator.of(context).pop(created);
    } on Object catch (e) {
      if (mounted) setState(() => _error = ApiError.from(e, 'Could not save.'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.kind;
    const number = TextInputType.numberWithOptions(decimal: true);
    final fields = <Widget>[
      NxTextField(
        label: 'Name',
        controller: _name,
        autofocus: true,
        error: _error?.field('name'),
        hint: kind == DrinkKind.wine ? 'Winemakers Selection Cape Blend' : null,
      ),
      ...switch (kind) {
        DrinkKind.wine => [
          NxTextField(label: 'Producer', controller: _producer),
          NxFormRow(
            children: [
              NxTextField(
                label: 'Vintage',
                controller: _vintage,
                keyboardType: TextInputType.number,
                error: _error?.field('vintage'),
              ),
              NxTextField(label: 'Style', controller: _style, hint: 'Red, white, rosé…'),
            ],
          ),
          NxFormRow(
            children: [
              NxTextField(label: 'Region', controller: _region),
              NxTextField(label: 'Country', controller: _country),
            ],
          ),
        ],
        DrinkKind.beer => [
          NxFormRow(
            children: [
              _BeerStylePicker(value: _beerStyleId, onChanged: (v) => setState(() => _beerStyleId = v)),
              NxTextField(label: 'ABV %', controller: _abv, keyboardType: number, error: _error?.field('abv')),
            ],
          ),
          NxFormSlot(
            label: 'Format',
            child: NxPillNav<String>(
              items: const [('can', 'Can'), ('bottle', 'Bottle'), ('draught', 'Draught')],
              value: _format,
              onChanged: (v) => setState(() => _format = v),
            ),
          ),
          _BreweryPicker(value: _brewery, onChanged: (b) => setState(() => _brewery = b)),
        ],
        DrinkKind.spirit => [
          NxTextField(label: 'Distillery', controller: _producer),
          NxFormRow(
            children: [
              NxPickerField<String>(
                label: 'Category',
                options: [
                  for (final c in ['Whisky', 'Gin', 'Rum', 'Brandy', 'Tequila', 'Vodka', 'Liqueur']) (c, c),
                ],
                value: _category,
                allowCustom: true,
                onChanged: (v) => setState(() => _category = v),
              ),
              NxTextField(label: 'Age statement', controller: _age, hint: '12 years'),
            ],
          ),
          NxTextField(label: 'ABV %', controller: _abv, keyboardType: number, error: _error?.field('abv')),
        ],
      },
      NxFormSlot(
        label: 'Rating',
        child: NxRatingInput(value: _rating, onChanged: (v) => setState(() => _rating = v)),
      ),
      NxTextField(label: 'Notes', controller: _notes, maxLines: 3),
      if (_error != null && _error!.fieldErrors.isEmpty)
        Text(_error!.message, style: NxText.sans(size: 13.5, color: NexusColors.bad)),
    ];

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(child: NxForm(children: fields)),
        ),
        NxSheetActions(
          label: 'Save ${kind == DrinkKind.spirit ? 'bottle' : kind.noun}',
          busy: _saving,
          onSubmit: _name.text.trim().isEmpty ? null : _submit,
        ),
      ],
    );
  }
}

class _BeerStylePicker extends ConsumerWidget {
  const _BeerStylePicker({required this.value, required this.onChanged});

  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final styles = ref.watch(beerStylesProvider).value ?? const [];
    return NxPickerField<int>(
      label: 'Style',
      options: [for (final s in styles) (s.integer('id') ?? 0, s.text('name'))],
      value: value,
      searchable: true,
      onChanged: onChanged,
    );
  }
}

/// Open Brewery DB lookup, or add a brewery by hand (web BeerView).
class _BreweryPicker extends ConsumerStatefulWidget {
  const _BreweryPicker({required this.value, required this.onChanged});

  final Json? value;
  final ValueChanged<Json?> onChanged;

  @override
  ConsumerState<_BreweryPicker> createState() => _BreweryPickerState();
}

class _BreweryPickerState extends ConsumerState<_BreweryPicker> {
  final _query = TextEditingController();
  final _name = TextEditingController();
  final _city = TextEditingController();
  final _country = TextEditingController(text: 'South Africa');
  List<Json> _results = const [];
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_query, _name, _city, _country]) {
      c.dispose();
    }
    super.dispose();
  }

  String _place(Json b) => [b.str('city'), b.str('country')].whereType<String>().join(', ');

  Future<void> _run(Future<void> Function() task) async {
    setState(() => _busy = true);
    try {
      await task();
    } on Object catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.isEmpty) return;
    await _run(() async {
      final r = await ref.read(drinksApiProvider).searchBreweries(q);
      setState(() => _results = r);
    });
  }

  Future<void> _import(String obdbId) => _run(() async {
    final b = await ref.read(drinksApiProvider).importBrewery(obdbId);
    _query.clear();
    setState(() => _results = const []);
    widget.onChanged(b);
  });

  Future<void> _create() async {
    if (_name.text.trim().isEmpty) return;
    await _run(() async {
      final b = await ref.read(drinksApiProvider).createBrewery({
        'name': _name.text.trim(),
        'city': _city.text.trim().isEmpty ? null : _city.text.trim(),
        'country': _country.text.trim().isEmpty ? null : _country.text.trim(),
      });
      _name.clear();
      _city.clear();
      widget.onChanged(b);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    final picked = widget.value;
    if (picked != null) {
      return NxFormSlot(
        label: 'Brewery',
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
          decoration: BoxDecoration(
            color: c.acc.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(NxRadius.md),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      picked.text('name'),
                      style: NxText.sans(size: 15, weight: FontWeight.w600, color: c.ink),
                    ),
                    if (_place(picked).isNotEmpty) Text(_place(picked), style: NxText.sans(size: 12.5, color: c.ink3)),
                  ],
                ),
              ),
              NxButton(
                'Change',
                onPressed: () => widget.onChanged(null),
                variant: NxButtonVariant.ghost,
                compact: true,
              ),
            ],
          ),
        ),
      );
    }
    return NxFormSlot(
      label: 'Brewery',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NxSearchField(
            controller: _query,
            hint: 'Search Open Brewery DB…',
            onSubmitted: (_) => _search(),
            trailing: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : NxIconButton(LucideIcons.arrowRight, tooltip: 'Find', size: 34, onPressed: _search),
          ),
          if (_results.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(NxRadius.md)),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(4),
                children: [
                  for (final r in _results)
                    NxListRow(
                      label: r.text('name'),
                      detail: _place(r).isEmpty ? null : _place(r),
                      onTap: () => _import(r.text('obdb_id')),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          Text('Not listed? Add it yourself:', style: NxText.muted(context)),
          const SizedBox(height: 8),
          TextField(
            controller: _name,
            decoration: const InputDecoration(hintText: 'Brewery name'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _city,
                  decoration: const InputDecoration(hintText: 'City'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _country,
                  decoration: const InputDecoration(hintText: 'Country'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: NxButton(
              'Add brewery',
              compact: true,
              variant: NxButtonVariant.secondary,
              onPressed: _name.text.trim().isEmpty || _busy ? null : _create,
            ),
          ),
        ],
      ),
    );
  }
}

/// Log a tasting against a wine (web CellarWineView dialog).
Future<bool?> showTastingSheet(BuildContext context, int wineId) => showNxSheet<bool>(
  context,
  title: 'Log a tasting',
  builder: (_) => _TastingForm(wineId: wineId),
);

class _TastingForm extends ConsumerStatefulWidget {
  const _TastingForm({required this.wineId});

  final int wineId;

  @override
  ConsumerState<_TastingForm> createState() => _TastingFormState();
}

class _TastingFormState extends ConsumerState<_TastingForm> {
  DateTime? _date = DateTime.now();
  double? _rating;
  final _occasion = TextEditingController();
  final _location = TextEditingController();
  final _notes = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_occasion, _location, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    String? t(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    try {
      await ref.read(drinksApiProvider).addTasting(widget.wineId, {
        'tasted_on': isoDay(_date ?? DateTime.now()),
        'rating': _rating,
        'occasion': t(_occasion),
        'location': t(_location),
        'notes': t(_notes),
      });
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (e) {
      if (mounted) showApiError(context, e, 'Could not save the tasting.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          NxForm(
            children: [
              NxDateField(label: 'Date', value: _date, clearable: false, onChanged: (d) => setState(() => _date = d)),
              NxFormSlot(
                label: 'Rating',
                child: NxRatingInput(value: _rating, onChanged: (v) => setState(() => _rating = v)),
              ),
              NxTextField(label: 'Occasion', controller: _occasion, hint: 'Sunday braai, anniversary…'),
              NxTextField(label: 'Where', controller: _location),
              NxTextField(label: 'How it showed', controller: _notes, maxLines: 3),
            ],
          ),
          NxSheetActions(label: 'Save tasting', busy: _saving, onSubmit: _save),
        ],
      ),
    );
  }
}
