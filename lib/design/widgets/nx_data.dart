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
  const new({required this.value, required this.label, this.sub, this.size = 40, super.key});

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
  const new(this.rows, {this.labelWidth = 70, this.showWords = false, this.stacked = false, super.key});

  final List<ProfileAxis> rows;
  final double labelWidth;
  final bool showWords;

  /// Label above a full-width bar, for narrow columns (print cards) where a
  /// side label would squeeze the bar or wrap.
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    final labelStyle = NxText.sans(size: 12, color: c.ink3, height: 1.2);
    Widget label(String text) =>
        Text(text, maxLines: 1, softWrap: false, overflow: TextOverflow.fade, style: labelStyle);
    Widget bar(ProfileAxis r) => TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: math.max(.06, r.value)),
      duration: const Duration(milliseconds: 800),
      curve: NxMotion.ease,
      builder: (_, v, _) => NxProgressRail(value: v, color: c.acc, track: c.tint2, height: 4),
    );

    return Column(
      children: [
        for (final (i, r) in rows.indexed)
          Padding(
            padding: EdgeInsets.only(bottom: i == rows.length - 1 ? 0 : (stacked ? 9 : 6)),
            child: Semantics(
              label: '${r.label}: ${r.word}',
              excludeSemantics: true,
              child: stacked
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [label(r.label), const SizedBox(height: 5), bar(r)],
                    )
                  : Row(
                      children: [
                        SizedBox(width: labelWidth, child: label(r.label)),
                        const SizedBox(width: 8),
                        Expanded(child: bar(r)),
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
  const new(this.values, {this.size = 88, super.key});

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
          painter: _RadarPainter(values: values, grow: t, grid: c.ink, acc: c.acc),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  new({required this.values, required this.grow, required this.grid, required this.acc});

  final List<double> values;
  final double grow;

  /// Ink the grid is drawn from. Print panels are saturated mid-tones where
  /// the page's hairline alphas vanish, so the grid uses stronger ones.
  final Color grid;
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

    for (final (f, alpha) in [(.33, .22), (.66, .22), (1.0, .36)]) {
      canvas.drawPath(
        Path()..addPolygon([for (var i = 0; i < n; i++) at(i, radius * f)], true),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = grid.withValues(alpha: alpha),
      );
    }
    final spokePaint = Paint()
      ..strokeWidth = 1
      ..color = grid.withValues(alpha: .18);
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
  bool shouldRepaint(_RadarPainter old) =>
      old.grow != grow || old.values != values || old.acc != acc || old.grid != grid;
}

/// Ranked row with optional artwork (web NxRankList item).
class NxRankRow extends StatelessWidget {
  const new({
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
              child: Text('$rank', style: NxText.display(size: 18, color: rank! <= 3 ? c.acc : c.ink3)),
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

/// Activity bars (web NxHourBars). Defaults to 24-hour ticks; pass [ticks]
/// (one per bar) for dayparts or weekdays.
class NxHourBars extends StatelessWidget {
  const new(this.values, {this.height = 72, this.ticks, super.key});

  final List<num> values;
  final double height;
  final List<String>? ticks;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    // Not `reduce(math.max)`: callers pass List<int> as List<num>, and the
    // tear-off's (num, num) => num then fails the runtime (int, int) => int check.
    var max = 0.0;
    var peak = -1;
    for (var i = 0; i < values.length; i++) {
      if (values[i] > max) {
        max = values[i].toDouble();
        peak = i;
      }
    }
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
        if (ticks case final labels?)
          Row(
            children: [
              for (var i = 0; i < labels.length; i++)
                Expanded(
                  child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: NxText.mono(size: 10, color: i == peak ? c.ink : c.ink3),
                  ),
                ),
            ],
          )
        else
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

/// Doughnut with a legend (web NexusChart `type="doughnut"`).
class NxDonut extends StatelessWidget {
  const new(this.segments, {this.size = 132, this.centre, this.centreLabel, super.key});

  /// (label, value, colour)
  final List<(String, num, Color)> segments;
  final double size;
  final String? centre;
  final String? centreLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    final total = segments.fold<num>(0, (s, e) => s + e.$2);
    return Semantics(
      label: segments.map((s) => '${s.$1} ${s.$2}').join(', '),
      excludeSemantics: true,
      child: Row(
        children: [
          SizedBox.square(
            dimension: size,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 900),
              curve: NxMotion.ease,
              builder: (_, t, child) => CustomPaint(
                painter: _DonutPainter(segments: segments, total: total, sweep: t, track: c.tint),
                child: child,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(centre ?? '$total', style: NxText.display(size: 30, color: c.ink)),
                    if (centreLabel != null) Text(centreLabel!, style: NxText.sans(size: 11.5, color: c.ink3)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (label, value, colour) in segments)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(color: colour, borderRadius: BorderRadius.circular(3)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(label, style: NxText.sans(size: 13.5, color: c.ink2)),
                        ),
                        Text('$value', style: NxText.mono(size: 12.5, color: c.ink)),
                      ],
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

class _DonutPainter extends CustomPainter {
  new({required this.segments, required this.total, required this.sweep, required this.track});

  final List<(String, num, Color)> segments;
  final num total;
  final double sweep;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 16.0;
    final rect = Offset.zero & size;
    final arc = rect.deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawArc(arc, 0, math.pi * 2, false, base);
    if (total <= 0) return;
    const gap = .035;
    var start = -math.pi / 2;
    for (final (_, value, colour) in segments) {
      final full = value / total * math.pi * 2;
      final draw = math.max(0, full * sweep - (segments.length > 1 ? gap : 0)).toDouble();
      canvas.drawArc(
        arc,
        start,
        draw,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.butt
          ..color = colour,
      );
      start += full * sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.sweep != sweep || old.segments != segments || old.track != track;
}

/// Labelled horizontal bar comparison (web NxRangeBar / constructor bars).
class NxBarRow extends StatelessWidget {
  const new({required this.label, required this.value, required this.max, this.color, this.trailing, super.key});

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
