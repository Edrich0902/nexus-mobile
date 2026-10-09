import 'package:flutter/material.dart';
import 'package:nexus_mobile/design/colors.dart';
import 'package:nexus_mobile/design/tokens.g.dart';
import 'package:nexus_mobile/design/typography.dart';
import 'package:nexus_mobile/design/widgets/nx_controls.dart';
import 'package:nexus_mobile/design/widgets/nx_motion.dart';

enum StageArt { square, portrait }

/// The editorial headline at the top of a page (web NxStage, phone layout):
/// artwork, eyebrow, serif title with an italic accent tail, lede, progress
/// rail and pill actions.
class NxStage extends StatelessWidget {
  const NxStage({
    this.eyebrow,
    this.live = false,
    this.title,
    this.accent,
    this.lede,
    this.ledeWidget,
    this.progress,
    this.visual,
    this.art = StageArt.square,
    this.actions = const [],
    this.compact = false,
    this.below,
    super.key,
  });

  final String? eyebrow;
  final bool live;
  final String? title;
  final String? accent;
  final String? lede;
  final Widget? ledeWidget;
  final double? progress;
  final Widget? visual;
  final StageArt art;
  final List<Widget> actions;
  final bool compact;
  final Widget? below;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    final size = compact ? 36.0 : 40.0;
    var beat = 0;
    Widget rise(Widget child, {double distance = 10}) => NxRise(index: beat++, distance: distance, child: child);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (visual != null) ...[
            rise(
              distance: 0,
              TweenAnimationBuilder<double>(
                tween: Tween(begin: reduceMotion(context) ? 1 : .92, end: 1),
                duration: NxTiming.rise,
                curve: NxMotion.ease,
                builder: (context, s, child) =>
                    Transform.scale(scale: s, alignment: Alignment.bottomLeft, child: child),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(NxRadius.lg),
                  child: Container(
                    width: art == StageArt.portrait ? 104 : 132,
                    height: art == StageArt.portrait ? 156 : 132,
                    color: c.amb2,
                    child: visual,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
          if (eyebrow != null)
            rise(
              Row(
                children: [
                  if (live) ...[const NxLiveDot(), const SizedBox(width: 10)],
                  Flexible(child: Text(eyebrow!, style: NxText.eyebrow(context))),
                ],
              ),
            ),
          rise(
            distance: 16,
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 14),
              child: Semantics(
                header: true,
                child: Text.rich(
                  TextSpan(
                    children: [
                      if (title != null) TextSpan(text: title),
                      if (accent != null) ...[
                        if (title != null) const TextSpan(text: ' '),
                        TextSpan(
                          text: accent,
                          style: TextStyle(color: c.acc, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ],
                  ),
                  style: NxText.serif(size: size, color: c.ink),
                ),
              ),
            ),
          ),
          if (ledeWidget != null)
            rise(
              DefaultTextStyle.merge(
                style: NxText.sans(size: 15.5, color: c.ink2, height: 1.4),
                child: ledeWidget!,
              ),
            )
          else if (lede != null)
            rise(Text(lede!, style: NxText.sans(size: 15.5, color: c.ink2, height: 1.4))),
          if (progress != null)
            rise(
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: NxTiming.count,
                  curve: NxTiming.settle,
                  builder: (_, v, _) => NxProgressRail(value: v, color: c.ink),
                ),
              ),
            ),
          if (actions.isNotEmpty)
            rise(
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: actions,
                ),
              ),
            ),
          ?below,
        ],
      ),
    );
  }
}

/// Serif summary sentence with bolded ink highlights (web NxSerifSummary).
class NxSerifSummary extends StatelessWidget {
  const NxSerifSummary(this.parts, {super.key});

  /// (text, highlighted) pairs.
  final List<(String, bool)> parts;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    return Padding(
      padding: const EdgeInsets.only(top: 26),
      child: Text.rich(
        TextSpan(
          children: [
            for (final (text, on) in parts)
              TextSpan(
                text: text,
                style: TextStyle(color: on ? c.ink : c.ink3),
              ),
          ],
        ),
        style: NxText.serif(size: 21, height: 1.3, color: c.ink3).copyWith(letterSpacing: 0),
      ),
    );
  }
}
