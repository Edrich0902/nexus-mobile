import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_mobile/core/api/api_error.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/core/media/media_image.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';
import 'package:nexus_mobile/features/capture/capture_api.dart';
import 'package:nexus_mobile/features/collections/drink_detail.dart';
import 'package:nexus_mobile/features/collections/drink_kind.dart';
import 'package:nexus_mobile/features/library/book_sheets.dart';

typedef _Spec = (String key, String label, TextInputType? type);

const _number = TextInputType.number;
const _decimal = TextInputType.numberWithOptions(decimal: true);

/// Editable fields per kind — the keys `/capture/identify` pre-fills and
/// `/capture/commit` accepts.
const _specs = <String, List<_Spec>>{
  'wine': [
    ('name', 'Name', null),
    ('producer_name', 'Producer', null),
    ('vintage', 'Vintage', _number),
    ('wine_type', 'Style', null),
    ('region_name', 'Region', null),
    ('country', 'Country', null),
  ],
  'beer': [
    ('name', 'Name', null),
    ('brewery', 'Brewery', null),
    ('style', 'Style', null),
    ('abv', 'ABV %', _decimal),
    ('ibu', 'IBU', _number),
    ('format', 'Format', null),
  ],
  'spirit': [
    ('name', 'Name', null),
    ('producer', 'Producer', null),
    ('category', 'Category', null),
    ('age_statement', 'Age statement', null),
    ('abv', 'ABV %', _decimal),
    ('region', 'Region', null),
    ('country', 'Country', null),
  ],
  'book': [
    ('title', 'Title', null),
    ('author', 'Author', null),
    ('isbn', 'ISBN', _number),
    ('publish_year', 'Published', _number),
  ],
};

const _kinds = [('wine', 'Wine'), ('beer', 'Beer'), ('spirit', 'Spirit'), ('book', 'Book')];

DrinkKind? _drinkKind(String kind) => switch (kind) {
  'wine' => DrinkKind.wine,
  'beer' => DrinkKind.beer,
  'spirit' => DrinkKind.spirit,
  _ => null,
};

Object? _typed(String key, String value) => switch (key) {
  'vintage' || 'ibu' || 'publish_year' => int.tryParse(value),
  'abv' => double.tryParse(value.replaceAll(',', '.')),
  _ => value,
};

/// The "recognised from the label" card under the frozen photo: kind pills,
/// pre-filled fields, a rating and one-tap save (web has no equivalent —
/// this is the phone-only capture flow from the mockup).
class CaptureReview extends ConsumerStatefulWidget {
  const CaptureReview({required this.result, required this.onRetake, super.key});

  final CaptureResult result;
  final VoidCallback onRetake;

  @override
  ConsumerState<CaptureReview> createState() => _CaptureReviewState();
}

class _CaptureReviewState extends ConsumerState<CaptureReview> {
  late String _kind = widget.result.kind;
  final _controllers = <String, TextEditingController>{};
  double? _rating;
  bool _saving = false;
  ApiError? _error;

  @override
  void initState() {
    super.initState();
    for (final specs in _specs.values) {
      for (final (key, _, _) in specs) {
        _controllers.putIfAbsent(key, () => TextEditingController(text: widget.result.fields.str(key)));
      }
    }
    if (widget.result.fields.str('title') case final title? when _controllers['name']!.text.isEmpty) {
      _controllers['name']!.text = title;
    }
    _controllers['name']!.addListener(_changed);
    _controllers['title']!.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Json _fields() => {
    for (final (key, _, _) in _specs[_kind] ?? const <_Spec>[])
      if (_controllers[key]!.text.trim() case final v when v.isNotEmpty) key: _typed(key, v),
  };

  Future<void> _save() async {
    final mediaId = widget.result.mediaId;
    if (mediaId == null || _controllers['name']!.text.trim().isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await ref
          .read(captureApiProvider)
          .commit(mediaId: mediaId, kind: _kind, fields: _fields(), rating: _rating);
      await HapticFeedback.mediumImpact();
      if (!mounted) return;
      showNxToast(context, 'Saved — reading the tasting notes now.');
      context.go(saved.text('route', '/home'));
    } on Object catch (e) {
      if (mounted) setState(() => _error = ApiError.from(e, 'Could not save this.'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _findBook() async {
    final isbn = _controllers['isbn']!.text.replaceAll(RegExp('[^0-9Xx]'), '');
    final query = isbn.length >= 10
        ? isbn
        : [_controllers['title']!.text, _controllers['author']!.text].where((s) => s.trim().isNotEmpty).join(' ');
    final book = await showAddBookSheet(context, initialQuery: query.trim().isEmpty ? null : query.trim());
    if (book?.integer('id') case final id? when mounted) context.go('/library/books/$id');
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final known = _specs.containsKey(_kind);
    final isBook = _kind == 'book';
    final heading = (isBook ? _controllers['title']! : _controllers['name']!).text.trim();
    final drink = _drinkKind(_kind);
    final recognised = r.kind != 'unknown';

    return ArtAmbient(
      media: MediaImage.fromJson(r.media),
      fallback: _kind == 'wine' ? wineStyleAmbient(_controllers['wine_type']!.text) : null,
      child: Builder(
        builder: (context) {
          final c = context.nx;
          return Container(
            decoration: BoxDecoration(
              color: c.amb,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(NxRadius.xxl)),
            ),
            child: ListView(
              padding: EdgeInsets.fromLTRB(20, 10, 20, 24 + MediaQuery.paddingOf(context).bottom),
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(color: c.tint2, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 14),
                NxRise(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          recognised
                              ? (isBook ? 'Read from the cover' : 'Recognised from the label')
                              : 'Not sure what this is',
                          style: NxText.eyebrow(context),
                        ),
                      ),
                      if (recognised) Text('${(r.confidence * 100).round()}% match', style: NxText.mono(color: c.ink3)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                NxRise(
                  child: Text(
                    heading.isEmpty ? (known ? 'Add the name' : 'Pick what it is') : heading,
                    style: NxText.serif(size: 32, color: heading.isEmpty ? c.ink3 : c.ink),
                  ),
                ),
                const SizedBox(height: 14),
                NxPillNav<String>(items: _kinds, value: _kind, onChanged: (v) => setState(() => _kind = v)),
                if (known) ...[
                  const SizedBox(height: 16),
                  NxForm(
                    children: [
                      for (final (key, label, type) in _specs[_kind]!)
                        NxTextField(
                          label: label,
                          controller: _controllers[key],
                          keyboardType: type,
                          error: _error?.field('fields.$key'),
                          textInputAction: TextInputAction.next,
                        ),
                    ],
                  ),
                ],
                if (drink != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: c.tint, borderRadius: BorderRadius.circular(NxRadius.md)),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('Your rating', style: NxText.sans(size: 13.5, color: c.ink2)),
                        ),
                        NxRatingInput(value: _rating, size: 26, onChanged: (v) => setState(() => _rating = v)),
                      ],
                    ),
                  ),
                ],
                if (_error != null && _error!.fieldErrors.isEmpty) ...[
                  const SizedBox(height: 12),
                  Text(_error!.message, style: NxText.sans(size: 13, color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: drink != null
                          ? NxButton(
                              switch (drink) {
                                DrinkKind.wine => 'Save to cellar',
                                DrinkKind.beer => 'Save to beer',
                                DrinkKind.spirit => 'Save to spirits',
                              },
                              loading: _saving,
                              onPressed: heading.isEmpty || r.mediaId == null ? null : _save,
                            )
                          : NxButton('Find on Open Library', onPressed: isBook ? _findBook : null),
                    ),
                    const SizedBox(width: 10),
                    NxButton('Retake', variant: NxButtonVariant.secondary, onPressed: widget.onRetake),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
