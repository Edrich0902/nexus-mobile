import 'package:cloudinary_url_gen/cloudinary.dart';
import 'package:cloudinary_url_gen/transformation/named_transformation.dart';
import 'package:cloudinary_url_gen/transformation/transformation.dart';
import 'package:flutter/painting.dart' show BoxFit;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_mobile/core/config/app_config.dart';
import 'package:nexus_mobile/core/media/media_image.dart';
import 'package:nexus_mobile/core/meta/app_meta.dart';

/// Named delivery variants. The Cloudinary account runs Strict
/// transformations, so clients may only request these (created server-side by
/// `php artisan media:sync-transformations`) — never ad-hoc `w_`/`c_` params.
enum MediaVariant {
  thumb('nexus_thumb'),
  thumbHd('nexus_thumb_hd'),
  card('nexus_card'),
  cardHd('nexus_card_hd'),
  hero('nexus_hero'),
  avatar('nexus_avatar');

  new(this.transform);
  final String transform;

  /// Pick the density-appropriate variant for a logical box. Thumbs and cards
  /// crop to a fixed shape (1:1, 3:2), so they only serve art that covers a box
  /// of roughly that shape; anything else — a bottle in a tall panel, contained
  /// art — gets the uncropped hero, or the crop would cut the subject.
  static MediaVariant forBox({
    required double width,
    required double height,
    required double devicePixelRatio,
    BoxFit fit = BoxFit.cover,
    bool avatar = false,
  }) {
    if (avatar) return MediaVariant.avatar;
    if (fit != BoxFit.cover || !height.isFinite || height <= 0) return MediaVariant.hero;
    final aspect = width / height;
    final px = width * devicePixelRatio;
    if (aspect >= .8 && aspect <= 1.25) {
      if (px <= 160) return MediaVariant.thumb;
      if (px <= 480) return MediaVariant.thumbHd;
    } else if (aspect > 1.25 && aspect <= 2) {
      if (px <= 480) return MediaVariant.card;
      if (px <= 960) return MediaVariant.cardHd;
    }
    return MediaVariant.hero;
  }

  bool get isSquare => this == thumb || this == thumbHd || this == avatar;
}

final cloudinaryProvider = Provider<CloudinaryDelivery>((ref) {
  final meta = ref.watch(appMetaProvider).value;
  final cloudName = meta?.cloudName ?? AppConfig.cloudinaryCloudName;
  return CloudinaryDelivery(cloudName.isEmpty ? null : cloudName);
});

/// Builds delivery URLs with the official Cloudinary Dart SDK.
class CloudinaryDelivery {
  new(String? cloudName)
    : _cloudinary = cloudName == null
          ? null
          : (Cloudinary.fromCloudName(cloudName: cloudName)
              ..config.urlConfig.secure = true
              ..config.urlConfig.analytics = false);

  final Cloudinary? _cloudinary;

  bool get enabled => _cloudinary != null;

  String? url(MediaImage? media, MediaVariant variant) {
    if (media == null) return null;
    final publicId = media.publicId;
    if (_cloudinary != null && publicId != null && publicId.isNotEmpty) {
      return (_cloudinary.image(
        publicId,
      )..transformation(Transformation()..add(NamedTransformation(variant.transform)))).toString();
    }
    final url = media.url;
    return url == null ? null : rewriteUrl(url, variant);
  }

  /// Swap or insert the named transform on an existing Cloudinary URL
  /// (e.g. mirrored covers delivered as full `secure_url`s).
  static String rewriteUrl(String url, MediaVariant variant) {
    if (!url.contains('res.cloudinary.com') || !url.contains('/image/upload/')) return url;
    return url.replaceFirstMapped(RegExp('(/image/upload/)(?:t_[^/]+/)?'), (m) => '${m[1]}t_${variant.transform}/');
  }
}
