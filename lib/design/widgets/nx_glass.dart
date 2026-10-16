import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nexus_mobile/design/colors.dart';
import 'package:nexus_mobile/design/tokens.g.dart';

/// Frosted glass for floating chrome (iOS 26 style, identical on Android):
/// a blurred, saturated backdrop under an ambient-tinted fill, a specular
/// rim and a soft drop shadow. Inside a [BackdropGroup] every NxGlass shares
/// one backdrop read.
class NxGlass extends StatelessWidget {
  const new({required this.child, this.radius, this.thick = false, super.key});

  final Widget child;

  /// Corner radius; null makes a capsule.
  final double? radius;

  /// Heavier frost for surfaces that carry reading and forms (sheets,
  /// toasts), so text stays legible over whatever sits behind.
  final bool thick;

  static final _filter = ImageFilter.compose(
    outer: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
    inner: const ColorFilter.matrix(_saturate),
  );

  static final _thickFilter = ImageFilter.compose(
    outer: ImageFilter.blur(sigmaX: 34, sigmaY: 34),
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
          filter: thick ? _thickFilter : _filter,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: thick ? const [0, .2] : const [0, .45],
                colors: thick
                    ? [Color.lerp(c.amb, Colors.white, .1)!.withValues(alpha: .8), c.amb.withValues(alpha: .74)]
                    : [Color.lerp(c.amb, Colors.white, .14)!.withValues(alpha: .6), c.amb.withValues(alpha: .5)],
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
  Widget build(BuildContext context) => DecoratedBox(decoration: nxLens(context.nx, lift: lift));
}

/// Raised glass selection (tab lens, segmented controls).
ShapeDecoration nxLens(NexusColors c, {double lift = 0, double radius = NxRadius.pill}) => ShapeDecoration(
  color: c.ink.withValues(alpha: .13 + .07 * lift),
  shadows: [
    BoxShadow(
      color: Colors.black.withValues(alpha: .4 + .15 * lift),
      blurRadius: 14 + 8 * lift,
      offset: Offset(0, 4 + 3 * lift),
      spreadRadius: -6,
    ),
  ],
  shape: NxGlassBorder.raised(c, radius: radius, edge: .1 + .08 * lift, highlight: .32 + .2 * lift),
);

/// Recessed glass for inputs: a darker pane lit along its bottom lip.
ShapeDecoration nxWell(NexusColors c, {double radius = NxRadius.md}) => ShapeDecoration(
  color: nxWellFill,
  shape: NxGlassBorder.recessed(c, radius: radius),
);

const nxWellFill = Color(0x2E000000);

/// A glass edge for any rounded shape: light on the top lip and shade on
/// the bottom when [NxGlassBorder.raised], the reverse when
/// [NxGlassBorder.recessed]. It is an
/// [InputBorder], so text fields use it straight from the theme.
class NxGlassBorder extends InputBorder {
  const new({required this.colors, this.radius = NxRadius.md, this.width = 1}) : super(borderSide: BorderSide.none);

  factory raised(NexusColors c, {double radius = NxRadius.md, double edge = .12, double highlight = .22}) =>
      NxGlassBorder(
        radius: radius,
        colors: [
          Colors.white.withValues(alpha: highlight),
          c.ink.withValues(alpha: edge),
          c.ink.withValues(alpha: edge),
          Colors.black.withValues(alpha: .28),
        ],
      );

  factory recessed(NexusColors c, {double radius = NxRadius.md}) => NxGlassBorder(
    radius: radius,
    colors: [
      Colors.black.withValues(alpha: .42),
      c.ink.withValues(alpha: .1),
      c.ink.withValues(alpha: .1),
      Colors.white.withValues(alpha: .16),
    ],
  );

  factory solid(Color color, {double radius = NxRadius.md, double width = 1.5}) =>
      NxGlassBorder(radius: radius, width: width, colors: [color, color, color, color]);

  /// Top, upper edge, lower edge, bottom.
  final List<Color> colors;
  final double radius;
  final double width;

  RRect _rrect(Rect rect) => RRect.fromRectAndRadius(rect, Radius.circular(math.min(radius, rect.shortestSide / 2)));

  @override
  bool get isOutline => true;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(width);

  @override
  NxGlassBorder copyWith({BorderSide? borderSide}) => this;

  @override
  ShapeBorder scale(double t) => NxGlassBorder(colors: colors, radius: radius * t, width: width * t);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => Path()..addRRect(_rrect(rect).deflate(width));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => Path()..addRRect(_rrect(rect));

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) => a is NxGlassBorder ? _lerp(a, this, t) : super.lerpFrom(a, t);

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) => b is NxGlassBorder ? _lerp(this, b, t) : super.lerpTo(b, t);

  static NxGlassBorder _lerp(NxGlassBorder a, NxGlassBorder b, double t) => NxGlassBorder(
    colors: [for (var i = 0; i < 4; i++) Color.lerp(a.colors[i], b.colors[i], t)!],
    radius: lerpDouble(a.radius, b.radius, t)!,
    width: lerpDouble(a.width, b.width, t)!,
  );

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    double? gapStart,
    double gapExtent = 0,
    double gapPercentage = 0,
    TextDirection? textDirection,
  }) {
    canvas.drawRRect(
      _rrect(rect).deflate(width / 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0, .3, .7, 1],
          colors: colors,
        ).createShader(rect),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is NxGlassBorder && listEquals(other.colors, colors) && other.radius == radius && other.width == width;

  @override
  int get hashCode => Object.hash(Object.hashAll(colors), radius, width);
}

RRect _shape(Size size, double? radius, [double inset = 0]) {
  final r = math.min(radius ?? double.infinity, size.shortestSide / 2);
  return RRect.fromRectAndRadius((Offset.zero & size).deflate(inset), Radius.circular(r));
}

/// Light catching the top edge, shade along the bottom.
class _GlassRim extends CustomPainter {
  const new(this.radius, this.edge);

  final double? radius;
  final Color edge;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: const [0, .3, .7, 1],
        colors: [Colors.white.withValues(alpha: .26), edge, edge, Colors.black.withValues(alpha: .28)],
      ).createShader(Offset.zero & size);
    canvas.drawRRect(_shape(size, radius, .5), paint);
  }

  @override
  bool shouldRepaint(_GlassRim old) => old.radius != radius || old.edge != edge;
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
