import 'package:flutter/material.dart';
import 'package:nexus_mobile/design/ambient_palette.dart';
import 'package:nexus_mobile/design/colors.dart';
import 'package:nexus_mobile/design/tokens.g.dart';
import 'package:nexus_mobile/design/typography.dart';
import 'package:nexus_mobile/design/widgets/nx_controls.dart';
import 'package:nexus_mobile/design/widgets/nx_layout.dart';

enum FieldVariant { solid, tint, outline, surface }

/// A colour field (web NxField): a solid, saturated block with a small label
/// row and an oversized display value. Lives inside [NxBento].
class NxField extends StatelessWidget with BentoItem {
  const NxField({
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
      FieldVariant.tint => (bg!.withValues(alpha: .18), c.ink, bg!, null),
      FieldVariant.outline => (Colors.transparent, c.ink, c.ink, Border.all(color: c.lineStrong)),
      FieldVariant.surface => (c.surface2, c.ink, c.ink, null),
    };

    final content = Container(
      constraints: BoxConstraints(minHeight: minHeight),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(NxRadius.xl),
        border: border,
      ),
      child: DefaultTextStyle(
        style: NxText.sans(color: fg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (label != null || aside != null)
              Opacity(
                opacity: .72,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: NxText.sans(size: 12, weight: FontWeight.w600, color: fg),
                      ),
                    ),
                    if (aside != null)
                      Text(
                        aside!,
                        style: NxText.sans(size: 12, weight: FontWeight.w600, color: fg),
                      ),
                  ],
                ),
              ),
            const Spacer(),
            if (child != null)
              child!
            else if (value != null && value!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value!,
                    style: NxText.display(size: valueSize, color: valueColor),
                  ),
                ),
              ),
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
