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

  /// Web host whose https links open in the app (universal / app links).
  static const webHost = String.fromEnvironment('WEB_HOST');

  /// Shared container for home-screen widgets and Live Activities (iOS).
  static const appGroupId = 'group.app.nexus.nexusMobile';

  /// Numeric App Store id, for the "update required" store link.
  static const appStoreId = String.fromEnvironment('APP_STORE_ID');

  static const androidPackage = 'app.nexus.nexus_mobile';

  static const firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const firebaseSenderId = String.fromEnvironment('FIREBASE_SENDER_ID');
  static const firebaseAndroidAppId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  static const firebaseAndroidApiKey = String.fromEnvironment('FIREBASE_ANDROID_API_KEY');
  static const firebaseIosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const firebaseIosApiKey = String.fromEnvironment('FIREBASE_IOS_API_KEY');

  static bool get isProd => env == 'prod';

  static String get apiRoot => '$apiBaseUrl/api/v1';
}
