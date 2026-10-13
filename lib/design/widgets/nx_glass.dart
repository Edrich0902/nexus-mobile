import 'dart:math' as math;
import 'dart:ui';

import 'package:material_ui/material_ui.dart';
import 'package:nexus_mobile/design/colors.dart';

/// Frosted glass for floating chrome (iOS 26 style, identical on Android):
/// a blurred, saturated backdrop under an ambient-tinted fill, a specular
/// rim and a soft drop shadow. Inside a [BackdropGroup] every NxGlass shares
/// one backdrop read.
class NxGlass extends StatelessWidget {
  const new({required this.child, this.radius, super.key});

  final Widget child;

  /// Corner radius; null makes a capsule.
  final double? radius;

  static final _filter = ImageFilter.compose(
    outer: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
    inner: const ColorFilter.matrix(_saturate),
  );

  /// Saturation 1.6 (Rec. 709 luma), so colour under the glass glows
  /// through instead of turning grey.
  static const _saturate = <double>[
    1.47244, -.42912, -.04332, 0, 0, //
    -.12756, 1.17088, -.04332, 0, 0, //
    -.12756, -.42912, 1.55668, 0, 0, //
    0, 0, 0, 1, 0,
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    return CustomPaint(
      painter: _GlassShadow(radius),
      foregroundPainter: _GlassRim(radius, c.ink.withValues(alpha: .13)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius ?? 999),
        child: BackdropFilter.grouped(
          filter: _filter,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0, .45],
                colors: [Color.lerp(c.amb, Colors.white, .14)!.withValues(alpha: .6), c.amb.withValues(alpha: .5)],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// The raised pill that marks a selection inside [NxGlass] (the tab lens).
/// [lift] (0–1) brightens it and deepens its shadow while it is held.
class NxGlassLens extends StatelessWidget {
  const new({this.lift = 0, super.key});

  final double lift;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    return CustomPaint(
      foregroundPainter: _GlassRim(null, c.ink.withValues(alpha: .1 + .08 * lift), highlight: .32 + .2 * lift),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.ink.withValues(alpha: .13 + .07 * lift),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .4 + .15 * lift),
              blurRadius: 14 + 8 * lift,
              offset: Offset(0, 4 + 3 * lift),
              spreadRadius: -6,
            ),
          ],
        ),
      ),
    );
  }
}

RRect _shape(Size size, double? radius, [double inset = 0]) {
  final r = math.min(radius ?? double.infinity, size.shortestSide / 2);
  return RRect.fromRectAndRadius((Offset.zero & size).deflate(inset), Radius.circular(r));
}

/// Light catching the top edge, shade along the bottom.
class _GlassRim extends CustomPainter {
  const new(this.radius, this.edge, {this.highlight = .26});

  final double? radius;
  final Color edge;
  final double highlight;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: const [0, .3, .7, 1],
        colors: [
          Colors.white.withValues(alpha: highlight),
          edge,
          edge,
          Colors.black.withValues(alpha: .28),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRRect(_shape(size, radius, .5), paint);
  }

  @override
  bool shouldRepaint(_GlassRim old) => old.radius != radius || old.edge != edge || old.highlight != highlight;
}

/// Drop shadow painted only outside the shape, so it never darkens what the
/// translucent glass shows through.
class _GlassShadow extends CustomPainter {
  const new(this.radius);

  final double? radius;

  @override
  void paint(Canvas canvas, Size size) {
    final shape = _shape(size, radius);
    canvas
      ..save()
      ..clipPath(
        Path.combine(
          PathOperation.difference,
          Path()..addRect((Offset.zero & size).inflate(48)),
          Path()..addRRect(shape),
        ),
      )
      ..drawRRect(
        shape.shift(const Offset(0, 12)).deflate(6),
        Paint()
          ..color = Colors.black.withValues(alpha: .55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_GlassShadow old) => old.radius != radius;
}
