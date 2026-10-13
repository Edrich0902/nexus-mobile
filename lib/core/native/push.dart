import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_mobile/core/api/api_client.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/core/auth/auth.dart';
import 'package:nexus_mobile/core/config/app_config.dart';
import 'package:nexus_mobile/core/native/deep_links.dart';
import 'package:nexus_mobile/core/native/notifications.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Firebase options from `--dart-define`s, or null to fall back to the
/// native `google-services.json` / `GoogleService-Info.plist` if present.
FirebaseOptions? firebaseOptionsFor(TargetPlatform platform) {
  final (appId, apiKey) = switch (platform) {
    TargetPlatform.android => (AppConfig.firebaseAndroidAppId, AppConfig.firebaseAndroidApiKey),
    TargetPlatform.iOS => (AppConfig.firebaseIosAppId, AppConfig.firebaseIosApiKey),
    _ => ('', ''),
  };
  if (appId.isEmpty || apiKey.isEmpty || AppConfig.firebaseProjectId.isEmpty || AppConfig.firebaseSenderId.isEmpty) {
    return null;
  }
  return FirebaseOptions(
    apiKey: apiKey,
    appId: appId,
    messagingSenderId: AppConfig.firebaseSenderId,
    projectId: AppConfig.firebaseProjectId,
  );
}

/// Route a push payload opens: the API sends a web path in `data.route`.
String pushRoute(Map<String, dynamic> data) => safeAppPath(data['route']?.toString()) ?? '/home';

final pushProvider = Provider<PushNotifications>((ref) {
  final push = PushNotifications(ref);
  ref.onDispose(push.dispose);
  return push;
});

/// FCM registration against `POST /devices`. Without Firebase config this
/// quietly does nothing, so dev builds run without a Firebase project.
class PushNotifications {
  new(this._ref);

  final Ref _ref;
  final _subs = <StreamSubscription<Object?>>[];
  Future<bool>? _init;
  bool _enabled = false;

  static const _deviceKey = 'nexus.push.device_id';

  bool get enabled => _enabled;

  /// Initialises once, then (re-)registers this phone for the signed-in user.
  Future<void> start() async {
    if (!isMobilePlatform) return;
    if (!await (_init ??= _initialise())) return;
    try {
      if (await _token(FirebaseMessaging.instance) case final token?) await _register(token);
    } on Object {
      // Retried on the next sign-in or token refresh.
    }
  }

  Future<bool> _initialise() async {
    try {
      if (Firebase.apps.isEmpty) {
        final options = firebaseOptionsFor(defaultTargetPlatform);
        await (options == null ? Firebase.initializeApp() : Firebase.initializeApp(options: options));
      }
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return false;

      await messaging.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);
      await _ref.read(notificationsProvider).ready();
      _subs
        ..add(FirebaseMessaging.onMessage.listen(_onForeground))
        ..add(FirebaseMessaging.onMessageOpenedApp.listen(_onOpened))
        ..add(messaging.onTokenRefresh.listen(_register));
      if (await messaging.getInitialMessage() case final message?) _onOpened(message);
      return _enabled = true;
    } on Object {
      return false;
    }
  }

  Future<String?> _token(FirebaseMessaging messaging) async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      for (var attempt = 0; attempt < 5 && await messaging.getAPNSToken() == null; attempt++) {
        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }
    return await messaging.getToken();
  }

  Future<void> _register(String token) async {
    if (_ref.read(authProvider) is! SignedIn) return;
    try {
      final info = await PackageInfo.fromPlatform();
      final device = asJson(
        await _ref
            .read(apiClientProvider)
            .post(
              '/devices',
              data: {
                'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
                'push_token': token,
                'device_name': deviceName(),
                'app_version': info.version,
              },
            ),
      );
      if (device.integer('id') case final id?) {
        await (await SharedPreferences.getInstance()).setInt(_deviceKey, id);
      }
    } on Object {
      // Retried on the next launch or token refresh.
    }
  }

  /// Called before sign-out so this phone stops receiving the user's pushes.
  Future<void> unregister() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getInt(_deviceKey) case final id?) {
        await _ref.read(apiClientProvider).delete('/devices/$id');
        await prefs.remove(_deviceKey);
      }
      if (_enabled) await FirebaseMessaging.instance.deleteToken();
    } on Object {
      // Server-side cleanup also happens when FCM reports the token dead.
    }
  }

  void _onForeground(RemoteMessage message) {
    // iOS presents foreground notifications natively (presentation options).
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final n = message.notification;
    if (n == null) return;
    unawaited(
      _ref
          .read(notificationsProvider)
          .show(
            id: message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
            title: n.title ?? 'Nexus',
            body: n.body ?? '',
            route: pushRoute(message.data),
          ),
    );
  }

  void _onOpened(RemoteMessage message) => _ref.read(deepLinksProvider).open(pushRoute(message.data));

  void dispose() {
    for (final s in _subs) {
      unawaited(s.cancel());
    }
  }
}
