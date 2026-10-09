import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nexus_mobile/core/media/media_image.dart';
import 'package:nexus_mobile/design/colors.dart';
import 'package:nexus_mobile/design/profile.dart';
import 'package:nexus_mobile/design/tokens.g.dart';
import 'package:nexus_mobile/design/typography.dart';
import 'package:nexus_mobile/design/widgets/nx_controls.dart';
import 'package:nexus_mobile/design/widgets/nx_media.dart';

/// Big display number with label + sub (web NxStatNumber).
class NxStatNumber extends StatelessWidget {
  const NxStatNumber({required this.value, required this.label, this.sub, this.size = 40, super.key});

  final String value;
  final String label;
  final String? sub;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: NxText.label(context, size: 11)),
        const SizedBox(height: 6),
        Text(
          value,
          style: NxText.display(size: size, color: c.ink),
        ),
        if (sub != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(sub!, style: NxText.muted(context)),
          ),
      ],
    );
  }
}

/// Labelled 0–1 bars (web NxMeters / `.scale`).
class NxMeters extends StatelessWidget {
  const NxMeters(this.rows, {this.labelWidth = 70, this.showWords = false, super.key});

  final List<ProfileAxis> rows;
  final double labelWidth;
  final bool showWords;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    return Column(
      children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Semantics(
              label: '${r.label}: ${r.word}',
              excludeSemantics: true,
              child: Row(
                children: [
                  SizedBox(
                    width: labelWidth,
                    child: Text(r.label, style: NxText.sans(size: 12, color: c.ink3)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: math.max(.06, r.value)),
                      duration: const Duration(milliseconds: 800),
                      curve: NxMotion.ease,
                      builder: (_, v, _) => NxProgressRail(value: v, color: c.acc, track: c.tint2, height: 4),
                    ),
                  ),
                  if (showWords) ...[
                    const SizedBox(width: 8),
                    Text(r.word, style: NxText.sans(size: 12, color: c.ink2)),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Five-spoke taste radar (web NxRadar).
class NxRadar extends StatelessWidget {
  const NxRadar(this.values, {this.size = 88, super.key});

  final List<double> values;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    return ExcludeSemantics(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: .05, end: 1),
        duration: const Duration(milliseconds: 800),
        curve: NxMotion.ease,
        builder: (_, t, _) => CustomPaint(
          size: Size.square(size),
          painter: _RadarPainter(values: values, grow: t, ring: c.tint2, spoke: c.line, acc: c.acc),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({required this.values, required this.grow, required this.ring, required this.spoke, required this.acc});

  final List<double> values;
  final double grow;
  final Color ring;
  final Color spoke;
  final Color acc;

  @override
  void paint(Canvas canvas, Size size) {
    final n = values.length;
    if (n < 3) return;
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 4;
    Offset at(int i, double r) {
      final a = -math.pi / 2 + i * 2 * math.pi / n;
      return center + Offset(math.cos(a), math.sin(a)) * r;
    }

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = ring;
    for (final f in [.33, .66, 1.0]) {
      canvas.drawPath(Path()..addPolygon([for (var i = 0; i < n; i++) at(i, radius * f)], true), ringPaint);
    }
    final spokePaint = Paint()..color = spoke;
    for (var i = 0; i < n; i++) {
      canvas.drawLine(center, at(i, radius), spokePaint);
    }
    final shape = Path()
      ..addPolygon([for (var i = 0; i < n; i++) at(i, radius * math.max(.06, values[i]) * grow)], true);
    canvas
      ..drawPath(shape, Paint()..color = acc.withValues(alpha: .32))
      ..drawPath(
        shape,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeJoin = StrokeJoin.round
          ..color = acc,
      );
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.grow != grow || old.values != values || old.acc != acc;
}

/// Ranked row with optional artwork (web NxRankList item).
class NxRankRow extends StatelessWidget {
  const NxRankRow({
    required this.rank,
    required this.title,
    this.subtitle,
    this.trailing,
    this.media,
    this.imageUrl,
    this.onTap,
    this.circle = false,
    this.bar,
    super.key,
  });

  final int? rank;
  final String title;
  final String? subtitle;
  final String? trailing;
  final MediaImage? media;
  final String? imageUrl;
  final VoidCallback? onTap;
  final bool circle;

  /// Optional 0–1 bar under the title.
  final double? bar;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    final hasArt = media != null || imageUrl != null;
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          if (rank != null)
            SizedBox(
              width: 28,
              child: Text(
                '$rank',
                style: NxText.display(size: 18, color: rank! <= 3 ? c.acc : c.ink3),
              ),
            ),
          if (hasArt) ...[
            SizedBox(
              width: 44,
              height: 44,
              child: NxImage(media: media, url: imageUrl, radius: circle ? 44 : NxRadius.xs),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: NxText.sans(size: 14.5, weight: FontWeight.w600, color: c.ink),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: NxText.sans(size: 12.5, color: c.ink3),
                  ),
                if (bar != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: NxProgressRail(value: bar!, color: c.acc, track: c.tint, height: 4),
                  ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            Text(trailing!, style: NxText.mono(size: 12, color: c.ink3)),
          ],
        ],
      ),
    );
    return onTap == null ? row : NxPressable(onTap: onTap!, scale: .985, child: row);
  }
}

/// 24-hour activity bars (web NxHourBars).
class NxHourBars extends StatelessWidget {
  const NxHourBars(this.values, {this.height = 72, super.key});

  final List<num> values;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    final max = values.isEmpty ? 1 : values.reduce(math.max).toDouble();
    final peak = values.isEmpty ? -1 : values.indexOf(values.reduce(math.max));
    return Column(
      children: [
        SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < values.length; i++)
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    height: max == 0 ? 2 : math.max(2, height * values[i] / max),
                    decoration: BoxDecoration(
                      color: i == peak ? c.acc : c.tint2,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final h in ['00', '06', '12', '18', '23']) Text(h, style: NxText.mono(size: 10, color: c.ink3)),
          ],
        ),
      ],
    );
  }
}

/// Labelled horizontal bar comparison (web NxRangeBar / constructor bars).
class NxBarRow extends StatelessWidget {
  const NxBarRow({required this.label, required this.value, required this.max, this.color, this.trailing, super.key});

  final String label;
  final double value;
  final double max;
  final Color? color;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: NxText.sans(size: 13, color: c.ink2),
            ),
          ),
          Expanded(
            child: NxProgressRail(value: max <= 0 ? 0 : value / max, color: color ?? c.acc, track: c.tint, height: 8),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 44,
            child: Text(
              trailing ?? value.toStringAsFixed(0),
              textAlign: TextAlign.right,
              style: NxText.mono(size: 12, color: c.ink),
            ),
          ),
        ],
      ),
    );
  }
}
