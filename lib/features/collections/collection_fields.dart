import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';

/// One summary tile above a collection (web `CollectionField`). [span] is in
/// phone bento columns (1 or 2).
class CollectionField {
  const new({
    required this.key,
    required this.label,
    this.variant = FieldVariant.solid,
    this.span = 1,
    this.aside,
    this.value,
    this.title,
    this.sub,
    this.progress,
    this.to,
  });

  final String key;
  final String label;
  final FieldVariant variant;
  final int span;
  final String? aside;
  final String? value;

  /// Serif line used instead of [value] for names.
  final String? title;
  final String? sub;
  final double? progress;
  final String? to;
}

/// Summary fields for a bottle collection (web `drinkFields`). Averages are
/// over the loaded page, so the sub-line says so when the collection is
/// larger.
List<CollectionField> drinkFields({
  required List<Json> items,
  required int total,
  required String countLabel,
  required String noun,
  required String Function(Json) to,
}) {
  final rated = items.where((i) => i.number('rating') != null).toList();
  final avg = rated.isEmpty ? null : rated.map((i) => i.number('rating')!).reduce((a, b) => a + b) / rated.length;
  final analysed = items.where((i) => i.str('analysis_status') == 'complete').length;
  final top = rated.isEmpty
      ? null
      : (List.of(rated)..sort((a, b) => b.number('rating')!.compareTo(a.number('rating')!))).first;
  final partial = total > items.length ? ' · latest ${items.length}' : '';
  return [
    CollectionField(
      key: 'count',
      label: countLabel,
      value: '$total',
      sub: items.isEmpty ? null : 'Latest: ${items.first.text('name')}',
      span: 2,
    ),
    CollectionField(
      key: 'avg',
      label: 'Average rating',
      value: avg?.toStringAsFixed(1) ?? '—',
      sub: '${rated.length} rated$partial',
      variant: FieldVariant.tint,
    ),
    CollectionField(
      key: 'analysed',
      label: 'AI notes',
      aside: 'of ${items.length}',
      value: '$analysed',
      variant: FieldVariant.outline,
      progress: items.isEmpty ? 0 : analysed / items.length,
    ),
    if (top != null)
      CollectionField(
        key: 'top',
        label: 'Top rated',
        title: top.text('name'),
        sub: '★ ${top.number('rating')!.toStringAsFixed(1)}',
        variant: FieldVariant.tint,
        span: 2,
        to: to(top),
      )
    else
      CollectionField(
        key: 'top',
        label: 'Top rated',
        title: 'Rate a $noun to crown one',
        variant: FieldVariant.outline,
        span: 2,
      ),
  ];
}

/// Colour fields above an index (web CollectionFields).
class CollectionFields extends StatelessWidget {
  const new({required this.section, required this.fields, super.key});

  final SectionKey section;
  final List<CollectionField> fields;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    return NxBento(
      children: [
        for (final f in fields)
          NxField(
            key: ValueKey(f.key),
            bg: section.field.bg,
            ink: f.variant == FieldVariant.solid ? section.field.ink : null,
            variant: f.variant,
            label: f.label,
            aside: f.aside,
            value: f.title == null ? f.value : null,
            valueSize: f.span == 2 ? 52 : 40,
            sub: f.sub,
            span: f.span,
            progress: f.progress,
            minHeight: 116,
            onTap: f.to == null ? null : () => context.push(f.to!),
            child: f.title == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      f.title!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: NxText.serif(
                        size: 24,
                        height: 1.05,
                        color: f.variant == FieldVariant.solid ? section.field.ink : c.ink,
                      ),
                    ),
                  ),
          ),
      ],
    );
  }
}
