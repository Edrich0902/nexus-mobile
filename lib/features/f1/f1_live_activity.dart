import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:live_activities/live_activities.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/core/config/app_config.dart';
import 'package:nexus_mobile/core/native/notifications.dart';
import 'package:nexus_mobile/features/home/hub_api.dart';

/// How long before lights-out the Live Activity / ongoing notification shows.
const liveLeadTime = Duration(hours: 1);

/// Sessions without an end time are assumed to run this long.
const _fallbackLength = Duration(hours: 2);

typedef F1LiveSession = ({
  String id,
  String title,
  String session,
  String circuit,
  DateTime startsAt,
  DateTime endsAt,
  String route,
});

/// The race moment from `GET /now` when it's inside the live window.
F1LiveSession? liveSessionFrom(Json? now, DateTime clock) {
  if (now?.str('moment') != 'race') return null;
  final session = now!.obj('session');
  final startsAt = session?.date('starts_at');
  if (session == null || startsAt == null) return null;
  final endsAt = session.date('ends_at') ?? startsAt.add(_fallbackLength);
  if (clock.isBefore(startsAt.subtract(liveLeadTime)) || !clock.isBefore(endsAt)) return null;
  final key = now.obj('subject')?.integer('id');
  return (
    id: 'f1-${key ?? startsAt.millisecondsSinceEpoch}',
    title: [now.str('title'), now.str('accent')].whereType<String>().join(' '),
    session: session.text('name', 'Session'),
    circuit: now.text('lede'),
    startsAt: startsAt,
    endsAt: endsAt,
    route: now.list('actions').firstOrNull?.str('to') ?? '/f1',
  );
}

final f1LiveActivityProvider = Provider<F1LiveActivity>((ref) {
  final live = F1LiveActivity(ref);
  ref.onDispose(live.dispose);
  return live;
});

/// iOS: an ActivityKit Live Activity (lock screen + Dynamic Island) whose
/// countdown runs natively from the start / end timestamps.
/// Android: an ongoing, silent notification with a chronometer.
class F1LiveActivity {
  F1LiveActivity(this._ref);

  final Ref _ref;
  final _activities = LiveActivities();
  ProviderSubscription<AsyncValue<Json>>? _sub;
  Timer? _tick;
  Future<bool>? _ready;
  String? _current;

  static const _notificationId = 7001;

  void start() {
    if (!isMobilePlatform || _sub != null) return;
    _sub = _ref.listen(nowProvider, (_, _) => unawaited(_sync()), fireImmediately: true);
    // Re-check each minute so the window opens / closes without a refetch.
    _tick = Timer.periodic(const Duration(minutes: 1), (_) => unawaited(_sync()));
  }

  Future<void> stop() async {
    _sub?.close();
    _sub = null;
    _tick?.cancel();
    _tick = null;
    await _end();
  }

  Future<bool> _init() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return true;
    try {
      await _activities.init(appGroupId: AppConfig.appGroupId, urlScheme: AppConfig.urlScheme);
      return await _activities.areActivitiesSupported() && await _activities.areActivitiesEnabled();
    } on Object {
      return false;
    }
  }

  Future<void> _sync() async {
    final live = liveSessionFrom(_ref.read(nowProvider).value, DateTime.now());
    if (live == null) return _end();
    if (!await (_ready ??= _init())) return;
    if (_current != null && _current != live.id) await _end();
    _current = live.id;
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _activities.createOrUpdateActivity(live.id, {
          'title': live.title,
          'session': live.session,
          'circuit': live.circuit,
          'startsAt': live.startsAt.millisecondsSinceEpoch / 1000,
          'endsAt': live.endsAt.millisecondsSinceEpoch / 1000,
          'route': live.route,
        }, staleIn: live.endsAt.difference(DateTime.now()));
      } else {
        await _android(live);
      }
    } on Object {
      // Activities disabled mid-session; nothing to show.
    }
  }

  Future<void> _android(F1LiveSession live) {
    final started = !DateTime.now().isBefore(live.startsAt);
    const channel = LocalNotifications.live;
    return _ref
        .read(notificationsProvider)
        .show(
          id: _notificationId,
          title: started ? '${live.session} · live' : '${live.session} · lights out soon',
          body: [live.title, live.circuit].where((s) => s.isNotEmpty).join(' · '),
          route: live.route,
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            icon: LocalNotifications.icon,
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
            autoCancel: false,
            onlyAlertOnce: true,
            silent: true,
            category: AndroidNotificationCategory.event,
            when: live.startsAt.millisecondsSinceEpoch,
            usesChronometer: true,
            chronometerCountDown: !started,
            timeoutAfter: live.endsAt.difference(DateTime.now()).inMilliseconds,
          ),
        );
  }

  Future<void> _end() async {
    final id = _current;
    _current = null;
    if (id == null) return;
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _activities.endActivity(id);
      } else {
        await _ref.read(notificationsProvider).cancel(_notificationId);
      }
    } on Object {
      // already ended
    }
  }

  void dispose() => unawaited(stop());
}
