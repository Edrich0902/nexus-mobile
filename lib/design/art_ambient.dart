import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_mobile/core/media/cloudinary.dart';
import 'package:nexus_mobile/core/media/media_image.dart';
import 'package:nexus_mobile/design/ambient.dart';
import 'package:nexus_mobile/design/ambient_palette.dart';
import 'package:nexus_mobile/design/palettes.dart';

/// Artwork (label, cover, album art) tints the ambient, falling back to [fallback].
class ArtAmbient extends ConsumerWidget {
  const ArtAmbient({required this.child, this.media, this.url, this.fallback, super.key});

  final MediaImage? media;
  final String? url;
  final Ambient? fallback;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thumb = ref.watch(cloudinaryProvider).url(media, MediaVariant.thumb) ?? url;
    final ambient = ref.watch(artAmbientProvider(thumb)) ?? fallback;
    return AmbientOverride(ambient: ambient, child: child);
  }
}
