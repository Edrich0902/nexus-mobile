import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nexus_mobile/core/auth/auth.dart';
import 'package:nexus_mobile/core/media/cloudinary.dart';
import 'package:nexus_mobile/core/media/media_image.dart';
import 'package:nexus_mobile/design/colors.dart';
import 'package:nexus_mobile/design/tokens.g.dart';
import 'package:nexus_mobile/design/typography.dart';
import 'package:nexus_mobile/design/widgets/nx_controls.dart';
import 'package:nexus_mobile/design/widgets/nx_layout.dart' show NxPage;
import 'package:nexus_mobile/design/widgets/widgets.dart' show NxPage;

/// Cloudinary-aware image (web NexusImage). Records with a `public_id` are
/// delivered through the Cloudinary SDK with a named, density-appropriate
/// transform; anything else (Spotify art, mirrored URLs) loads directly.
class NxImage extends ConsumerWidget {
  const NxImage({
    this.media,
    this.url,
    this.variant,
    this.fit = BoxFit.cover,
    this.radius = 0,
    this.fallbackIcon = LucideIcons.image,
    this.background,
    this.semanticLabel,
    this.avatar = false,
    super.key,
  });

  final MediaImage? media;
  final String? url;
  final MediaVariant? variant;
  final BoxFit fit;
  final double radius;
  final IconData fallbackIcon;
  final Color? background;
  final String? semanticLabel;
  final bool avatar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.nx;
    final delivery = ref.watch(cloudinaryProvider);
    final source = media ?? (url == null ? null : MediaImage(url: url));

    Widget fallback() => ColoredBox(
      color: background ?? c.amb2,
      child: Center(child: Icon(fallbackIcon, color: c.ink4, size: 22)),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: _FillsGivenBox(
        child: LayoutBuilder(
          builder: (context, box) {
            if (source == null || source.isEmpty) return fallback();
            final dpr = MediaQuery.devicePixelRatioOf(context);
            final width = box.maxWidth.isFinite ? box.maxWidth : 480.0;
            final v = variant ?? MediaVariant.forBox(width: width, devicePixelRatio: dpr, avatar: avatar);
            final resolved = delivery.url(source, v);
            if (resolved == null) return fallback();
            final cacheW = box.maxWidth.isFinite ? (box.maxWidth * dpr).round() : null;
            return Semantics(
              image: true,
              label: semanticLabel,
              excludeSemantics: semanticLabel == null,
              child: CachedNetworkImage(
                imageUrl: resolved,
                fit: fit,
                width: double.infinity,
                height: double.infinity,
                memCacheWidth: cacheW,
                fadeInDuration: const Duration(milliseconds: 250),
                placeholder: (_, _) => ColoredBox(color: background ?? c.amb2),
                errorWidget: (_, _, _) => fallback(),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Network art has no natural size: it fills whatever box it's given. Saying
/// so (zero intrinsics) keeps [NxImage] usable inside IntrinsicHeight rows,
/// where the LayoutBuilder underneath can't answer intrinsic queries.
class _FillsGivenBox extends SingleChildRenderObjectWidget {
  const _FillsGivenBox({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderFillsGivenBox();
}

class _RenderFillsGivenBox extends RenderProxyBox {
  @override
  double computeMinIntrinsicWidth(double height) => 0;

  @override
  double computeMaxIntrinsicWidth(double height) => 0;

  @override
  double computeMinIntrinsicHeight(double width) => 0;

  @override
  double computeMaxIntrinsicHeight(double width) => 0;
}

/// Full-screen, pinch-to-zoom artwork (web NexusImage `previewable`).
Future<void> showImagePreview(BuildContext context, {MediaImage? media, String? url, String? label}) {
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black.withValues(alpha: .92),
      barrierDismissible: true,
      pageBuilder: (context, _, _) => _ImagePreview(media: media, url: url, label: label),
      transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
    ),
  );
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({this.media, this.url, this.label});

  final MediaImage? media;
  final String? url;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: InteractiveViewer(
              maxScale: 4,
              child: Center(
                child: NxImage(
                  media: media,
                  url: url,
                  variant: MediaVariant.hero,
                  fit: BoxFit.contain,
                  background: Colors.transparent,
                  semanticLabel: label,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 12,
          top: pad.top + 8,
          child: NxIconButton(
            LucideIcons.x,
            tooltip: 'Close',
            filled: true,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }
}

/// Stage artwork well: the image (tap to preview) or an "add a photo" prompt.
class NxArtWell extends StatelessWidget {
  const NxArtWell({
    required this.onAdd,
    this.media,
    this.url,
    this.label = '',
    this.addLabel = 'Add a photo',
    this.fit = BoxFit.cover,
    super.key,
  });

  final MediaImage? media;
  final String? url;
  final String label;
  final String addLabel;
  final VoidCallback onAdd;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    final has = (media != null && !media!.isEmpty) || (url != null && url!.isNotEmpty);
    if (has) {
      return GestureDetector(
        onTap: () => showImagePreview(context, media: media, url: url, label: label),
        child: NxImage(media: media, url: url, variant: MediaVariant.hero, fit: fit, semanticLabel: label),
      );
    }
    return Semantics(
      button: true,
      label: addLabel,
      excludeSemantics: true,
      child: NxPressable(
        onTap: onAdd,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: c.lineStrong),
            borderRadius: BorderRadius.circular(NxRadius.lg),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.imagePlus, size: 24, color: c.acc),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  addLabel,
                  textAlign: TextAlign.center,
                  style: NxText.sans(size: 12.5, color: c.ink3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NxAvatar extends ConsumerWidget {
  const NxAvatar({this.size = 32, this.user, super.key});

  final double size;
  final User? user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.nx;
    final u = user ?? ref.watch(currentUserProvider);
    final initials = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: c.acc.withValues(alpha: .22)),
      child: Text(
        u?.initials ?? '',
        style: NxText.sans(size: size * .39, weight: FontWeight.w600, color: c.acc),
      ),
    );
    if (u?.media == null) return initials;
    return SizedBox(
      width: size,
      height: size,
      child: NxImage(media: u!.media, radius: size, avatar: true, fallbackIcon: LucideIcons.user),
    );
  }
}

/// Cover tile for collection grids (web NxCoverCard).
class NxCoverCard extends StatelessWidget {
  const NxCoverCard({
    required this.title,
    this.media,
    this.url,
    this.subtitle,
    this.onTap,
    this.aspect = 1,
    this.badge,
    this.rating,
    this.artBackground,
    this.fit = BoxFit.cover,
    this.fallbackIcon = LucideIcons.image,
    this.circle = false,
    super.key,
  });

  final String title;
  final MediaImage? media;
  final String? url;
  final String? subtitle;
  final VoidCallback? onTap;
  final double aspect;
  final String? badge;
  final double? rating;
  final Color? artBackground;
  final BoxFit fit;
  final IconData fallbackIcon;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    final card = Column(
      crossAxisAlignment: circle ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: aspect,
          child: Stack(
            fit: StackFit.expand,
            children: [
              NxImage(
                media: media,
                url: url,
                fit: fit,
                radius: circle ? 999 : NxRadius.md,
                background: artBackground,
                fallbackIcon: fallbackIcon,
                semanticLabel: title,
              ),
              if (badge != null)
                Positioned(
                  left: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: c.amb.withValues(alpha: .78),
                      borderRadius: BorderRadius.circular(NxRadius.pill),
                    ),
                    child: Text(
                      badge!,
                      style: NxText.sans(size: 11, weight: FontWeight.w600, color: c.ink),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          maxLines: 2,
          textAlign: circle ? TextAlign.center : TextAlign.start,
          overflow: TextOverflow.ellipsis,
          style: NxText.sans(weight: FontWeight.w600, color: c.ink, height: 1.25),
        ),
        if (subtitle != null || rating != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              mainAxisAlignment: circle ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                if (subtitle != null)
                  Flexible(
                    child: Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: NxText.sans(size: 12.5, color: c.ink3),
                    ),
                  ),
                if (rating != null) ...[const SizedBox(width: 6), NxRating(rating, size: 12)],
              ],
            ),
          ),
      ],
    );
    return onTap == null ? card : NxPressable(onTap: onTap!, child: card);
  }
}

/// Shrink-wrapped grid for use inside [NxPage] children.
class NxGrid extends StatelessWidget {
  const NxGrid({required this.children, this.columns = 2, this.spacing = 14, this.runSpacing = 18, super.key});

  final List<Widget> children;
  final int columns;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = (box.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: [for (final child in children) SizedBox(width: w, child: child)],
        );
      },
    );
  }
}

/// Horizontal rail of fixed-width cards that bleeds to the screen edge.
class NxRail extends StatelessWidget {
  const NxRail({required this.children, this.itemWidth = 140, this.height = 200, super.key});

  final List<Widget> children;
  final double itemWidth;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: OverflowBox(
        maxWidth: MediaQuery.sizeOf(context).width,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: children.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (_, i) => SizedBox(width: itemWidth, child: children[i]),
        ),
      ),
    );
  }
}
