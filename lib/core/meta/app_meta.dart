import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_mobile/core/api/api_client.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// `GET /v1/meta`: version gate, feature flags and Cloudinary delivery config.
class AppMeta {
  const AppMeta({
    required this.minVersion,
    required this.latestVersion,
    required this.features,
    required this.cloudName,
    required this.appVersion,
  });

  final String minVersion;
  final String latestVersion;
  final Map<String, bool> features;
  final String? cloudName;
  final String appVersion;

  bool feature(String key) => features[key] ?? true;

  bool get updateRequired => compareVersions(appVersion, minVersion) < 0;
  bool get updateAvailable => compareVersions(appVersion, latestVersion) < 0;
}

int compareVersions(String a, String b) {
  List<int> parts(String v) => v.split('+').first.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  final pa = parts(a);
  final pb = parts(b);
  for (var i = 0; i < 3; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x.compareTo(y);
  }
  return 0;
}

final appMetaProvider = FutureProvider<AppMeta>((ref) async {
  final info = await PackageInfo.fromPlatform();
  final api = ref.watch(apiClientProvider);
  final json = asJson(await api.get('/meta'));
  final platform = defaultTargetPlatform == TargetPlatform.android ? 'android' : 'ios';
  final min = json.obj('min_app_version');
  final features = (json.obj('features') ?? {}).map((k, v) => MapEntry(k, v == true));
  return AppMeta(
    minVersion: min?.str(platform) ?? '0.0.0',
    latestVersion: json.text('latest_app_version', info.version),
    features: features,
    cloudName: json.obj('media')?.str('cloud_name'),
    appVersion: info.version,
  );
});
