/// Build-time configuration, injected per flavour with
/// `--dart-define-from-file=config/<env>.json`.
abstract final class AppConfig {
  static const env = String.fromEnvironment('NEXUS_ENV', defaultValue: 'dev');

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://api.nexus.test',
  );

  /// Fallback only: the live cloud name comes from `GET /v1/meta` so a
  /// Cloudinary account change never needs an app release.
  static const cloudinaryCloudName = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
    defaultValue: 'nexus-hub',
  );

  static const sentryDsn = String.fromEnvironment('SENTRY_DSN');

  /// Custom URL scheme registered on both platforms for OAuth returns and
  /// deep links (`nexus://oauth/...`, `nexus://open/...`).
  static const urlScheme = 'nexus';

  static bool get isProd => env == 'prod';

  static String get apiRoot => '$apiBaseUrl/api/v1';
}
