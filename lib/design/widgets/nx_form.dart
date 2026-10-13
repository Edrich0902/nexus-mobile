import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nexus_mobile/design/colors.dart';
import 'package:nexus_mobile/design/tokens.g.dart';
import 'package:nexus_mobile/design/typography.dart';
import 'package:nexus_mobile/design/widgets/nx_controls.dart';
import 'package:nexus_mobile/design/widgets/nx_sheet.dart';

/// Labelled slot for non-text inputs (rating, segmented choice) so they line
/// up with [NxTextField]s in a form.
class NxFormSlot extends StatelessWidget {
  const new({required this.label, required this.child, super.key});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: NxText.label(context)),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

/// Two inputs side by side (web `.nx-form .row`).
class NxFormRow extends StatelessWidget {
  const new({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: children[i]),
        ],
      ],
    );
  }
}

/// Vertical form body with consistent gaps.
class NxForm extends StatelessWidget {
  const new({required this.children, this.gap = 16, super.key});

  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++) ...[if (i > 0) SizedBox(height: gap), children[i]],
      ],
    );
  }
}

/// Cancel + primary action row at the foot of a form sheet.
class NxSheetActions extends StatelessWidget {
  const new({required this.label, required this.onSubmit, this.busy = false, super.key});

  final String label;
  final VoidCallback? onSubmit;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          NxButton('Cancel', onPressed: () => Navigator.of(context).maybePop(), variant: NxButtonVariant.ghost),
          const SizedBox(width: 8),
          NxButton(label, onPressed: onSubmit, loading: busy),
        ],
      ),
    );
  }
}

/// Tappable field that looks like an input and opens a value picker.
class _FieldShell extends StatelessWidget {
  const new({required this.label, required this.text, required this.onTap, this.icon, this.onClear});

  final String label;
  final String? text;
  final VoidCallback onTap;
  final IconData? icon;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    return NxFormSlot(
      label: label,
      child: Semantics(
        button: true,
        label: label,
        value: text ?? 'Not set',
        excludeSemantics: true,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: 50,
            padding: const EdgeInsets.only(left: 14, right: 6),
            decoration: BoxDecoration(
              color: c.tint,
              borderRadius: BorderRadius.circular(NxRadius.md),
              border: Border.all(color: c.lineStrong),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    text ?? 'Choose…',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: NxText.sans(size: 15.5, color: text == null ? c.ink4 : c.ink),
                  ),
                ),
                if (text != null && onClear != null)
                  NxIconButton(LucideIcons.x, tooltip: 'Clear $label', size: 34, onPressed: onClear)
                else
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(icon ?? LucideIcons.chevronDown, size: 18, color: c.ink3),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Select input backed by a searchable bottom-sheet list (web PrimeVue
/// Select with `filter`). With [allowCustom], typed text can be used as-is
/// (web `editable`).
class NxPickerField<T> extends StatelessWidget {
  const new({
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.searchable = false,
    this.allowCustom = false,
    this.clearable = true,
    super.key,
  });

  final String label;
  final List<(T, String)> options;
  final T? value;
  final ValueChanged<T?> onChanged;
  final bool searchable;
  final bool allowCustom;
  final bool clearable;

  String? get _text {
    for (final (v, l) in options) {
      if (v == value) return l;
    }
    return value?.toString();
  }

  Future<void> _open(BuildContext context) async {
    final picked = await showNxSheet<(T?,)>(
      context,
      title: label,
      expand: options.length > 8 || searchable,
      builder: (_) => _PickerList<T>(
        options: options,
        value: value,
        searchable: searchable || allowCustom,
        allowCustom: allowCustom,
      ),
    );
    if (picked != null) onChanged(picked.$1);
  }

  @override
  Widget build(BuildContext context) => _FieldShell(
    label: label,
    text: _text,
    onTap: () => _open(context),
    onClear: clearable && value != null ? () => onChanged(null) : null,
  );
}

class _PickerList<T> extends StatefulWidget {
  const new({required this.options, required this.value, required this.searchable, required this.allowCustom});

  final List<(T, String)> options;
  final T? value;
  final bool searchable;
  final bool allowCustom;

  @override
  State<_PickerList<T>> createState() => _PickerListState<T>();
}

class _PickerListState<T> extends State<_PickerList<T>> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    final q = _q.trim().toLowerCase();
    final shown = q.isEmpty ? widget.options : widget.options.where((o) => o.$2.toLowerCase().contains(q)).toList();
    final custom = widget.allowCustom && q.isNotEmpty && !widget.options.any((o) => o.$2.toLowerCase() == q);
    return Column(
      children: [
        if (widget.searchable) ...[
          NxSearchField(
            hint: widget.allowCustom ? 'Search or type your own' : 'Search',
            autofocus: true,
            onChanged: (v) => setState(() => _q = v),
            onSubmitted: custom ? (_) => Navigator.of(context).pop((_q.trim() as T,)) : null,
          ),
          const SizedBox(height: 10),
        ],
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              if (custom)
                NxListRow(
                  label: 'Use “${_q.trim()}”',
                  icon: LucideIcons.plus,
                  onTap: () => Navigator.of(context).pop((_q.trim() as T,)),
                ),
              for (final (v, l) in shown)
                NxListRow(
                  label: l,
                  onTap: () => Navigator.of(context).pop((v,)),
                  trailing: v == widget.value ? Icon(LucideIcons.check, size: 18, color: c.acc) : const SizedBox(),
                ),
              if (shown.isEmpty && !custom)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('No matches', style: NxText.muted(context), textAlign: TextAlign.center),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Date input using the platform date picker.
class NxDateField extends StatelessWidget {
  const new({required this.label, required this.value, required this.onChanged, this.clearable = true, super.key});

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool clearable;

  @override
  Widget build(BuildContext context) => _FieldShell(
    label: label,
    text: value == null ? null : DateFormat('d MMM y').format(value!),
    icon: LucideIcons.calendar,
    onClear: clearable && value != null ? () => onChanged(null) : null,
    onTap: () async {
      final now = DateTime.now();
      final picked = await showDatePicker(
        context: context,
        initialDate: value ?? now,
        firstDate: DateTime(1900),
        lastDate: DateTime(now.year + 1, 12, 31),
      );
      if (picked != null) onChanged(picked);
    },
  );
}

/// Local calendar date as `YYYY-MM-DD` (what the API stores for dates).
String? isoDay(DateTime? d) => d == null ? null : DateFormat('yyyy-MM-dd').format(d);
