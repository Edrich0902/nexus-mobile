import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_mobile/core/native/deep_links.dart';

bool get isMobilePlatform =>
    !kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android);

final notificationsProvider = Provider<LocalNotifications>(LocalNotifications.new);

/// On-device notifications: foreground pushes on Android and the ongoing F1
/// session notification. Every notification carries a route as its payload.
class LocalNotifications {
  new(this._ref);

  final Ref _ref;
  final plugin = FlutterLocalNotificationsPlugin();
  Future<bool>? _ready;

  static const icon = 'ic_stat_nexus';

  static const updates = AndroidNotificationChannel(
    'nexus_default',
    'Updates',
    description: 'Analysis results and other things that finish in the background.',
    importance: Importance.high,
  );

  static const live = AndroidNotificationChannel(
    'nexus_live',
    'Live sessions',
    description: 'Countdown and live status for F1 sessions.',
    importance: Importance.low,
    playSound: false,
    enableVibration: false,
  );

  Future<bool> ready() => _ready ??= _init();

  Future<bool> _init() async {
    if (!isMobilePlatform) return false;
    try {
      await plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings(icon),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (response) => _open(response.payload),
      );
      final android = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(updates);
      await android?.createNotificationChannel(live);
      final launch = await plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) _open(launch?.notificationResponse?.payload);
      return true;
    } on Object {
      return false;
    }
  }

  void _open(String? route) {
    if (safeAppPath(route) case final path?) _ref.read(deepLinksProvider).open(path);
  }

  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? route,
    AndroidNotificationDetails? android,
  }) async {
    if (!await ready()) return;
    try {
      await plugin.show(
        id: id,
        title: title,
        body: body,
        payload: route,
        notificationDetails: NotificationDetails(
          android:
              android ??
              AndroidNotificationDetails(
                updates.id,
                updates.name,
                channelDescription: updates.description,
                importance: Importance.high,
                priority: Priority.high,
                icon: icon,
              ),
          iOS: const DarwinNotificationDetails(),
        ),
      );
    } on Object {
      // Notification permission revoked or channel missing — nothing to do.
    }
  }

  Future<void> cancel(int id) async {
    if (!await ready()) return;
    try {
      await plugin.cancel(id: id);
    } on Object {
      // already gone
    }
  }
}
