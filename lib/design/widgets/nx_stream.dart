import 'package:flutter/material.dart';
import 'package:nexus_mobile/design/colors.dart';
import 'package:nexus_mobile/design/tokens.g.dart';
import 'package:nexus_mobile/design/typography.dart';
import 'package:nexus_mobile/design/widgets/nx_controls.dart';

/// One event on a timeline (web NxStreamItem): mono time, a coloured node on
/// the rail, and a card with a coloured kind label, title, body and chips.
class NxStreamItem extends StatelessWidget {
  const new({
    required this.time,
    required this.title,
    this.color,
    this.kind,
    this.meta,
    this.body,
    this.chips = const [],
    this.onTap,
    this.future = false,
    this.trailing,
    super.key,
  });

  final String time;
  final String title;
  final Color? color;
  final String? kind;
  final String? meta;
  final String? body;
  final List<String> chips;
  final VoidCallback? onTap;
  final bool future;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    final node = color ?? c.acc;
    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: future ? Colors.transparent : c.tint,
        borderRadius: BorderRadius.circular(NxRadius.md),
        border: future ? Border.all(color: c.lineStrong) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (kind != null || meta != null)
                  Text.rich(
                    TextSpan(
                      children: [
                        if (kind != null)
                          TextSpan(
                            text: kind,
                            style: TextStyle(color: node, fontWeight: FontWeight.w600),
                          ),
                        if (kind != null && meta != null) const TextSpan(text: ' · '),
                        if (meta != null) TextSpan(text: meta),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: NxText.sans(size: 12, color: c.ink3),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(
                    title,
                    style: NxText.sans(size: 14.5, weight: FontWeight.w600, color: c.ink).copyWith(letterSpacing: -.15),
                  ),
                ),
                if (body != null && body!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(body!, style: NxText.sans(size: 13, color: c.ink2)),
                  ),
                if (chips.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 9),
                    child: Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: [
                        for (final chip in chips)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                            decoration: BoxDecoration(
                              color: node.withValues(alpha: .22),
                              borderRadius: BorderRadius.circular(NxRadius.pill),
                            ),
                            child: Text(chip, style: NxText.sans(size: 12, color: c.ink)),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ],
      ),
    );

    return Semantics(
      button: onTap != null,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 42,
              child: Padding(
                padding: const EdgeInsets.only(top: 14, right: 8),
                child: Text(
                  time,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  style: NxText.mono(size: 11, color: c.ink3),
                ),
              ),
            ),
            SizedBox(
              width: 20,
              child: CustomPaint(
                painter: _RailPainter(line: c.line, node: node, halo: c.amb),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 6, 0, 12),
                child: onTap == null ? card : NxPressable(onTap: onTap!, child: card),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RailPainter extends CustomPainter {
  new({required this.line, required this.node, required this.halo});

  final Color line;
  final Color node;
  final Color halo;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..drawRect(Rect.fromLTWH(9, 0, 1, size.height), Paint()..color = line)
      ..drawCircle(const Offset(9.5, 21.5), 8.5, Paint()..color = halo)
      ..drawCircle(const Offset(9.5, 21.5), 4.5, Paint()..color = node);
  }

  @override
  bool shouldRepaint(_RailPainter old) => old.line != line || old.node != node || old.halo != halo;
}

/// Day / group label inside a stream (web NxStreamGroup).
class NxStreamGroup extends StatelessWidget {
  const new(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(62, 10, 0, 4),
    child: Text(label.toUpperCase(), style: NxText.label(context, size: 11)),
  );
}
