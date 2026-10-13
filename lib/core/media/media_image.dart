import 'package:nexus_mobile/core/api/json.dart';

/// Compact image payload (`media` on records): Cloudinary public id + the
/// stored secure URL as a fallback.
class MediaImage {
  const new({this.id, this.publicId, this.url});

  static MediaImage? fromJson(Json? json) {
    if (json == null) return null;
    final m = MediaImage(id: json.integer('id'), publicId: json.str('public_id'), url: json.str('url'));
    return m.isEmpty ? null : m;
  }

  /// Any record with a `media` object or a loose image url field.
  static MediaImage? of(Json json, {List<String> urlKeys = const ['image_url', 'cover_url', 'media_url']}) {
    final media = fromJson(json.obj('media'));
    if (media != null) return media;
    for (final key in urlKeys) {
      final url = json.str(key);
      if (url != null) return MediaImage(url: url);
    }
    return null;
  }

  final int? id;
  final String? publicId;
  final String? url;

  bool get isEmpty => (publicId == null || publicId!.isEmpty) && (url == null || url!.isEmpty);
}
