import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nexus_mobile/core/media/cloudinary.dart';
import 'package:nexus_mobile/core/media/media_image.dart';
import 'package:nexus_mobile/design/ambient_palette.dart';
import 'package:nexus_mobile/design/colors.dart';
import 'package:nexus_mobile/design/tokens.g.dart';
import 'package:nexus_mobile/design/typography.dart';
import 'package:nexus_mobile/design/widgets/nx_controls.dart';
import 'package:nexus_mobile/design/widgets/nx_field_flip.dart';
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
    this.imageUrl,
    this.imageMedia,
    this.contentKey,
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

  /// Optional cover / label art for media slides.
  final String? imageUrl;
  final MediaImage? imageMedia;

  /// When set, body content flips/fades whenever this key changes.
  final Object? contentKey;

  static final _statLike = RegExp(r'^[\d#.,\s/%+\-−kdKmMbB]+$');

  bool get _hasImage => (imageUrl != null && imageUrl!.isNotEmpty) || (imageMedia != null && !imageMedia!.isEmpty);

  bool get _isStatValue {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return false;
    if (v.length <= 5) return true;
    return _statLike.hasMatch(v);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    final effective = bg == null && variant == FieldVariant.solid ? FieldVariant.surface : variant;
    final (Color background, Color fg, Color valueColor, Border? border) = switch (effective) {
      FieldVariant.solid => (bg!, ink ?? inkFor(bg!), ink ?? inkFor(bg!), null),
      FieldVariant.tint => (
        bg!.withValues(alpha: .18),
        c.ink,
        legibleOn(bg!, Color.alphaBlend(bg!.withValues(alpha: .18), c.amb), min: 3),
        null,
      ),
      FieldVariant.outline => (Colors.transparent, c.ink, c.ink, Border.all(color: c.lineStrong)),
      FieldVariant.surface => (c.surface2, c.ink, c.ink, null),
    };

    final body = _FieldBody(
      fg: fg,
      valueColor: valueColor,
      label: label,
      aside: aside,
      value: value,
      valueSize: valueSize,
      sub: sub,
      pips: pips,
      progress: progress,
      isStat: _isStatValue,
      hasImage: _hasImage,
      imageUrl: imageUrl,
      imageMedia: imageMedia,
      child: child,
    );

    // Media cards hug their art; count/stat slides keep a floor height.
    final floor = _hasImage ? 0.0 : minHeight;

    final framed = Container(
      constraints: BoxConstraints(minHeight: floor),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(NxRadius.xl), border: border),
      clipBehavior: Clip.hardEdge,
      child: DefaultTextStyle(
        style: NxText.sans(color: fg),
        child: contentKey == null ? body : NxFieldFlip(contentKey: contentKey!, child: body),
      ),
    );

    final sized = AnimatedSize(
      duration: reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 580),
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      clipBehavior: Clip.hardEdge,
      child: framed,
    );

    if (onTap == null) return sized;
    return NxPressable(onTap: onTap!, child: sized);
  }
}

class _FieldBody extends StatelessWidget {
  const new({
    required this.fg,
    required this.valueColor,
    required this.isStat,
    required this.hasImage,
    this.label,
    this.aside,
    this.value,
    this.valueSize = 44,
    this.sub,
    this.pips,
    this.progress,
    this.child,
    this.imageUrl,
    this.imageMedia,
  });

  final Color fg;
  final Color valueColor;
  final bool isStat;
  final bool hasImage;
  final String? label;
  final String? aside;
  final String? value;
  final double valueSize;
  final String? sub;
  final (int, int)? pips;
  final double? progress;
  final Widget? child;
  final String? imageUrl;
  final MediaImage? imageMedia;

  Widget? get _labelRow {
    if (label == null && aside == null) return null;
    return Opacity(
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
    );
  }

  Widget? get _subLine {
    if (sub == null || sub!.isEmpty) return null;
    return Padding(
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
    );
  }

  List<Widget> get _meta {
    return [
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
    ];
  }

  @override
  Widget build(BuildContext context) {
    // Media slides: art above the title at the image's real aspect ratio.
    // Natural height (no Spacer/Expanded) so cards grow/shrink with the art.
    if (hasImage && child == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ?_labelRow,
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: _FieldMedia(media: imageMedia, url: imageUrl, aspectHint: imageMedia?.aspectRatio),
          ),
          if (value != null && value!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _ValueText(value: value!, size: valueSize, color: valueColor, isStat: false),
            ),
          ?_subLine,
          ..._meta,
        ],
      );
    }

    // Unbounded-height safe: bento rows top-align and do not stretch.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ?_labelRow,
        if (child != null)
          Padding(padding: const EdgeInsets.only(top: 8), child: child!)
        else if (value != null && value!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _ValueText(value: value!, size: valueSize, color: valueColor, isStat: isStat),
          ),
        ?_subLine,
        ..._meta,
      ],
    );
  }
}

/// Field cover: uncropped hero delivery at a known aspect.
///
/// Uses [AspectRatio] (not [LayoutBuilder]) so grid bentos that measure with
/// [IntrinsicHeight] — e.g. the More screen — still lay out cleanly.
class _FieldMedia extends ConsumerWidget {
  const new({this.media, this.url, this.aspectHint});

  final MediaImage? media;
  final String? url;
  final double? aspectHint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.nx;
    final delivery = ref.watch(cloudinaryProvider);
    final source = media ?? (url == null ? null : MediaImage(url: url));
    final resolved = source == null || source.isEmpty ? null : delivery.url(source, MediaVariant.hero);
    final aspect = aspectHint != null && aspectHint! > 0.2 && aspectHint! < 3.5 ? aspectHint! : 1.0;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheW = ((MediaQuery.sizeOf(context).width / 2) * dpr).round();

    return ClipRRect(
      borderRadius: BorderRadius.circular(NxRadius.md),
      child: AspectRatio(
        aspectRatio: aspect,
        child: ColoredBox(
          color: Colors.black.withValues(alpha: .12),
          child: resolved == null
              ? Center(child: Icon(LucideIcons.image, color: c.ink4, size: 22))
              : CachedNetworkImage(
                  imageUrl: resolved,
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  width: double.infinity,
                  height: double.infinity,
                  memCacheWidth: cacheW,
                  fadeInDuration: const Duration(milliseconds: 280),
                  placeholder: (_, _) => ColoredBox(color: Colors.black.withValues(alpha: .08)),
                  errorWidget: (_, _, _) => Center(child: Icon(LucideIcons.image, color: c.ink4, size: 22)),
                ),
        ),
      ),
    );
  }
}

class _ValueText extends StatelessWidget {
  const new({required this.value, required this.size, required this.color, required this.isStat});

  final String value;
  final double size;
  final Color color;
  final bool isStat;

  @override
  Widget build(BuildContext context) {
    if (isStat) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.bottomLeft,
        child: NxCountUp(
          value,
          style: NxText.display(size: size, color: color),
        ),
      );
    }
    // Titles / messages: stay readable — never FittedBox-squash into oblivion.
    final readable = size.clamp(20.0, 28.0);
    return Align(
      alignment: Alignment.bottomLeft,
      child: Text(
        value,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: NxText.display(size: readable, color: color).copyWith(height: 1.05, letterSpacing: -0.03),
      ),
    );
  }
}

enum _LabelSlot { label, aside }

/// Label left, aside right. When both don't fit, the label keeps its width
/// (up to ~half the row) and the aside ellipsises into what's left.
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
