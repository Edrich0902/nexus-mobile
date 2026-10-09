import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_mobile/core/api/api_client.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/core/api/paged.dart';
import 'package:nexus_mobile/core/media/media_upload.dart';
import 'package:nexus_mobile/features/home/home_modules.dart';

/// What the label reader made of a photo.
class CaptureResult {
  const CaptureResult({required this.media, required this.kind, required this.confidence, required this.fields});

  factory CaptureResult.fromJson(Json json) {
    final id = json.obj('identification') ?? const {};
    return CaptureResult(
      media: json.obj('media') ?? const {},
      kind: id.str('kind') ?? 'unknown',
      confidence: id.number('confidence') ?? 0,
      fields: id.obj('fields') ?? const {},
    );
  }

  final Json media;
  final String kind;
  final double confidence;
  final Json fields;

  int? get mediaId => media.integer('id');
}

/// Kinds `/capture/commit` can create directly; books go through Open Library.
const captureCommitKinds = {'wine', 'beer', 'spirit'};

final captureApiProvider = Provider(CaptureApi.new);

class CaptureApi {
  CaptureApi(this._ref);

  final Ref _ref;

  ApiClient get _api => _ref.read(apiClientProvider);

  /// `POST /capture/identify` — uploads the photo (signed server-side to
  /// Cloudinary) and returns the kind plus pre-filled fields.
  Future<CaptureResult> identify(File photo, {String? hint, void Function(double)? onProgress}) async {
    final uploader = _ref.read(mediaUploaderProvider);
    final prepared = await uploader.prepare(photo);
    final form = FormData.fromMap({'file': await uploader.multipart(prepared), 'hint': ?hint});
    return CaptureResult.fromJson(asJson(await _api.upload('/capture/identify', form, onProgress: onProgress)));
  }

  /// `POST /capture/commit` — creates the wine / beer / spirit with the photo
  /// as its cover and queues tasting notes. Returns `{kind, id, route, analysis_status}`.
  Future<Json> commit({
    required int mediaId,
    required String kind,
    required Json fields,
    double? rating,
  }) async {
    final json = asJson(
      await _api.post(
        '/capture/commit',
        data: {'media_id': mediaId, 'kind': kind, 'fields': fields, 'rating': ?rating},
      ),
    );
    _ref
      ..invalidate(pagedProvider)
      ..invalidate(foodDrinkDashboardProvider);
    return json;
  }
}
