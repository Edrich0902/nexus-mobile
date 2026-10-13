import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nexus_mobile/design/ambient_palette.dart';
import 'package:nexus_mobile/design/colors.dart';
import 'package:nexus_mobile/design/tokens.g.dart';
import 'package:nexus_mobile/design/typography.dart';
import 'package:nexus_mobile/design/widgets/nx_controls.dart';
import 'package:nexus_mobile/design/widgets/nx_layout.dart';
import 'package:nexus_mobile/design/widgets/nx_motion.dart';

enum FieldVariant { solid, tint, outline, surface }

/// A colour field (web NxField): a solid, saturated block with a small label
/// row and an oversized display value. Lives inside [NxBento].
class NxField extends StatelessWidget with BentoItem {
  const new({
    this.bg,
    this.ink,
    this.variant = FieldVariant.solid,
    this.label,
    this.aside,
    this.value,
    this.valueSize = 44,
    this.sub,
    this.span = 1,
    this.onTap,
    this.pips,
    this.progress,
    this.child,
    this.minHeight = 120,
    super.key,
  });

  final Color? bg;
  final Color? ink;
  final FieldVariant variant;
  final String? label;
  final String? aside;
  final String? value;
  final double valueSize;
  final String? sub;
  @override
  final int span;
  final VoidCallback? onTap;
  final (int, int)? pips;
  final double? progress;
  final Widget? child;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    final effective = bg == null && variant == FieldVariant.solid ? FieldVariant.surface : variant;
    final (Color background, Color fg, Color valueColor, Border? border) = switch (effective) {
      FieldVariant.solid => (bg!, ink ?? inkFor(bg!), ink ?? inkFor(bg!), null),
      // The field colour is often a deep section hue: lift it for the value
      // so it still reads on its own 18% wash over the dark page.
      FieldVariant.tint => (
        bg!.withValues(alpha: .18),
        c.ink,
        legibleOn(bg!, Color.alphaBlend(bg!.withValues(alpha: .18), c.amb), min: 3),
        null,
      ),
      FieldVariant.outline => (Colors.transparent, c.ink, c.ink, Border.all(color: c.lineStrong)),
      FieldVariant.surface => (c.surface2, c.ink, c.ink, null),
    };

    final content = Container(
      constraints: BoxConstraints(minHeight: minHeight),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(NxRadius.xl), border: border),
      child: DefaultTextStyle(
        style: NxText.sans(color: fg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (label != null || aside != null)
              Opacity(
                opacity: .72,
                child: _LabelRow(
                  label: Text(
                    label ?? '',
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: NxText.sans(size: 12, weight: FontWeight.w600, color: fg),
                  ),
                  aside: Text(
                    aside ?? '',
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: NxText.sans(size: 12, weight: FontWeight.w600, color: fg),
                  ),
                ),
              ),
            if (child != null) ...[
              const Spacer(),
              child!,
            ] else if (value != null && value!.isNotEmpty)
              // Flexible (not a Spacer) so rounding in the bento's intrinsic
              // row height shrinks the number a hair instead of overflowing.
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.bottomLeft,
                    child: NxCountUp(
                      value!,
                      style: NxText.display(size: valueSize, color: valueColor),
                    ),
                  ),
                ),
              )
            else
              const Spacer(),
            if (sub != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Opacity(
                  opacity: .78,
                  child: Text(
                    sub!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: NxText.sans(size: 13, color: fg),
                  ),
                ),
              ),
            if (pips != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: NxPips(value: pips!.$1, max: pips!.$2, color: fg),
              ),
            if (progress != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: NxProgressRail(
                  value: progress!,
                  color: fg,
                  track: Colors.black.withValues(alpha: .15),
                  height: 5,
                ),
              ),
          ],
        ),
      ),
    );

    if (onTap == null) return content;
    return NxPressable(onTap: onTap!, child: content);
  }
}

enum _LabelSlot { label, aside }

/// Label left, aside right. When both don't fit, the label keeps its width
/// (up to ~half the row) and the aside ellipsises into what's left. A render
/// object rather than a LayoutBuilder so it still answers the bento's
/// intrinsic-height queries.
class _LabelRow extends SlottedMultiChildRenderObjectWidget<_LabelSlot, RenderBox> {
  const new({required this.label, required this.aside});

  final Widget label;
  final Widget aside;

  @override
  Iterable<_LabelSlot> get slots => _LabelSlot.values;

  @override
  Widget childForSlot(_LabelSlot slot) => switch (slot) {
    _LabelSlot.label => label,
    _LabelSlot.aside => aside,
  };

  @override
  _RenderLabelRow createRenderObject(BuildContext context) => _RenderLabelRow();
}

class _RenderLabelRow extends RenderBox with SlottedContainerRenderObjectMixin<_LabelSlot, RenderBox> {
  static const _gap = 10.0;

  RenderBox get _label => childForSlot(_LabelSlot.label)!;
  RenderBox get _aside => childForSlot(_LabelSlot.aside)!;

  (double, double) _widths(double max) {
    final available = math.max<double>(0, max - _gap);
    final label = _label.getMaxIntrinsicWidth(double.infinity);
    final aside = _aside.getMaxIntrinsicWidth(double.infinity);
    if (label + aside <= available) return (label, aside);
    final labelWidth = math.min(label, math.max(available - aside, available * .5));
    return (labelWidth, available - labelWidth);
  }

  @override
  double computeMinIntrinsicWidth(double height) => 0;

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _label.getMaxIntrinsicWidth(height) + _gap + _aside.getMaxIntrinsicWidth(height);

  @override
  double computeMinIntrinsicHeight(double width) => computeMaxIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      math.max(_label.getMaxIntrinsicHeight(double.infinity), _aside.getMaxIntrinsicHeight(double.infinity));

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final (lw, aw) = _widths(constraints.maxWidth);
    final height = math.max(
      _label.getDryLayout(BoxConstraints(maxWidth: lw)).height,
      _aside.getDryLayout(BoxConstraints(maxWidth: aw)).height,
    );
    return constraints.constrain(Size(constraints.maxWidth, height));
  }

  @override
  void performLayout() {
    final (lw, aw) = _widths(constraints.maxWidth);
    _label.layout(BoxConstraints(maxWidth: lw), parentUsesSize: true);
    _aside.layout(BoxConstraints(maxWidth: aw), parentUsesSize: true);
    final height = math.max(_label.size.height, _aside.size.height);
    size = constraints.constrain(Size(constraints.maxWidth, height));
    (_label.parentData! as BoxParentData).offset = Offset(0, (size.height - _label.size.height) / 2);
    (_aside.parentData! as BoxParentData).offset = Offset(
      size.width - _aside.size.width,
      (size.height - _aside.size.height) / 2,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final child in children) {
      context.paintChild(child, offset + (child.parentData! as BoxParentData).offset);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    for (final child in children) {
      final hit = result.addWithPaintOffset(
        offset: (child.parentData! as BoxParentData).offset,
        position: position,
        hitTest: (result, local) => child.hitTest(result, position: local),
      );
      if (hit) return true;
    }
    return false;
  }
}
