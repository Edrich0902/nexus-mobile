import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_mobile/core/api/api_client.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:path_provider/path_provider.dart';

final mediaUploaderProvider = Provider<MediaUploader>((ref) => MediaUploader(ref.watch(apiClientProvider)));

/// Uploads go through the Nexus API, which signs the Cloudinary upload with
/// server-held credentials and applies the `nexus_master` incoming transform.
/// The app never holds a Cloudinary key or an unsigned preset.
class MediaUploader {
  new(this._api);

  final ApiClient _api;

  /// Longest edge + quality match web `downscaleImageFile`.
  static const maxEdge = 2560;
  static const quality = 85;

  /// Downscale + re-encode to JPEG (also normalises HEIC from the iOS camera).
  Future<File> prepare(File source) async {
    final dir = await getTemporaryDirectory();
    final target = '${dir.path}/nx_${DateTime.now().microsecondsSinceEpoch}.jpg';
    // The plugin scales by the smaller of w/minWidth and h/minHeight, so the
    // bounds are derived from the real size to cap the longest edge.
    var (w, h) = (maxEdge, maxEdge);
    try {
      final buffer = await ui.ImmutableBuffer.fromFilePath(source.path);
      final desc = await ui.ImageDescriptor.encoded(buffer);
      final longest = desc.width > desc.height ? desc.width : desc.height;
      final scale = longest > maxEdge ? maxEdge / longest : 1.0;
      (w, h) = ((desc.width * scale).round(), (desc.height * scale).round());
      desc.dispose();
      buffer.dispose();
    } on Object {
      // Unknown format for the engine (e.g. HEIC on Android): fall back to a square bound.
    }
    final out = await FlutterImageCompress.compressAndGetFile(
      source.absolute.path,
      target,
      minWidth: w,
      minHeight: h,
      quality: quality,
    );
    return out == null ? source : File(out.path);
  }

  Future<MultipartFile> multipart(File file) => MultipartFile.fromFile(file.path, filename: file.uri.pathSegments.last);

  /// `POST /media` — returns the MediaAsset JSON.
  Future<Json> upload(
    File file, {
    required String collection,
    String? attachType,
    int? attachId,
    String role = 'cover',
    String? altText,
    void Function(double)? onProgress,
  }) async {
    final prepared = await prepare(file);
    final form = FormData.fromMap({
      'file': await multipart(prepared),
      'collection': collection,
      'role': role,
      'alt_text': ?altText,
      if (attachType != null && attachId != null) ...{
        'attach_to[type]': attachType,
        'attach_to[id]': attachId.toString(),
      },
    });
    final json = asJson(await _api.upload('/media', form, onProgress: onProgress));
    return json.obj('data') ?? json;
  }
}
