import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/core/config/app_config.dart';
import 'package:nexus_mobile/core/native/notifications.dart';
import 'package:nexus_mobile/features/home/home_modules.dart';
import 'package:nexus_mobile/features/home/hub_api.dart';
import 'package:nexus_mobile/features/listening/player.dart';

/// Home-screen widgets: (iOS kind, Android receiver class).
const homeWidgetKinds = [
  ('NexusListening', 'ListeningWidget'),
  ('NexusNextRace', 'NextRaceWidget'),
  ('NexusTonight', 'TonightWidget'),
  ('NexusQuickLog', 'QuickLogWidget'),
];

/// Every key the native widgets read; cleared on sign-out.
const homeWidgetKeys = [
  'listening_title',
  'listening_artist',
  'listening_state',
  'race_label',
  'race_title',
  'race_sub',
  'race_when',
  'race_route',
  'tonight_title',
  'tonight_sub',
  'tonight_route',
];

String _joined(Iterable<String?> parts) => parts.whereType<String>().where((s) => s.isNotEmpty).join(' · ');

/// Flat string map the native widgets render. Values are pre-formatted in
/// the user's locale so Swift / Kotlin stay presentation-only. `Tonight`
/// keys are omitted (not blanked) when there's no pick, so the last bottle
/// stays on the widget through the day.
Map<String, String> widgetSnapshot({PlayerState? player, Json? f1Home, Json? now}) {
  final moment = now?.str('moment');
  final snapshot = <String, String>{
    'listening_title': (player?.hasTrack ?? false) ? player!.title : 'Nothing playing',
    'listening_artist': (player?.hasTrack ?? false) ? player!.artists : 'Open Nexus to pick something',
    'listening_state': (player?.hasTrack ?? false) ? (player!.isPlaying ? 'Playing' : 'Paused') : '',
  };

  final meeting = f1Home?.obj('next_meeting');
  if (moment == 'race') {
    final session = now!.obj('session');
    snapshot.addAll({
      'race_label': now.text('eyebrow', 'Formula 1'),
      'race_title': [now.str('title'), now.str('accent')].whereType<String>().join(' '),
      'race_sub': now.text('lede'),
      'race_when': _when(session?.date('starts_at')),
      'race_route': now.list('actions').firstOrNull?.str('to') ?? '/f1',
    });
  } else if (meeting != null) {
    snapshot.addAll({
      'race_label': 'Next race',
      'race_title': meeting.text('meeting_name', 'Formula 1'),
      'race_sub': _joined([meeting.str('circuit_short_name'), meeting.str('country_name')]),
      'race_when': _when(meeting.date('date_start')),
      'race_route': '/f1/meetings/${meeting.integer('meeting_key') ?? ''}',
    });
  } else {
    snapshot.addAll({
      'race_label': 'Formula 1',
      'race_title': 'No race scheduled',
      'race_sub': '',
      'race_when': '',
      'race_route': '/f1',
    });
  }

  if (moment == 'cellar') {
    snapshot.addAll({
      'tonight_title': now!.text('accent', 'A bottle from your cellar'),
      'tonight_sub': now.text('lede'),
      'tonight_route': now.list('actions').firstOrNull?.str('to') ?? '/cellar',
    });
  }
  return snapshot;
}

String _when(DateTime? at) => at == null ? '' : DateFormat('EEE d MMM · HH:mm').format(at);

final homeWidgetSyncProvider = Provider<HomeWidgetSync>((ref) {
  final sync = HomeWidgetSync(ref);
  ref.onDispose(sync.dispose);
  return sync;
});

/// Mirrors now-playing, the next race and tonight's bottle into the native
/// widget store. Writes are debounced and skipped when nothing changed.
class HomeWidgetSync {
  new(this._ref);

  final Ref _ref;
  final _subs = <ProviderSubscription<Object?>>[];
  AppLifecycleListener? _lifecycle;
  Timer? _debounce;
  Map<String, String> _written = const {};
  bool _groupSet = false;

  void start() {
    if (!isMobilePlatform || _subs.isNotEmpty) return;
    _subs.addAll([
      _ref.listen(playerProvider.select((p) => (p.title, p.artists, p.isPlaying)), (_, _) => _schedule()),
      _ref.listen(f1HomeProvider, (_, _) => _schedule()),
      _ref.listen(nowProvider, (_, _) => _schedule()),
    ]);
    _lifecycle = AppLifecycleListener(onPause: () => unawaited(_flush()));
    _schedule();
  }

  void stop() {
    for (final s in _subs) {
      s.close();
    }
    _subs.clear();
    _lifecycle?.dispose();
    _lifecycle = null;
    _debounce?.cancel();
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () => unawaited(_flush()));
  }

  Future<void> _flush() async {
    _debounce?.cancel();
    final next = widgetSnapshot(
      player: _ref.read(playerProvider),
      f1Home: _ref.read(f1HomeProvider).value,
      now: _ref.read(nowProvider).value,
    );
    if (next.entries.every((e) => _written[e.key] == e.value)) return;
    await _write(next);
  }

  /// Wipes personal data from the widgets (sign-out).
  Future<void> clear() async {
    stop();
    if (!isMobilePlatform) return;
    await _write({for (final k in homeWidgetKeys) k: ''});
  }

  Future<void> _write(Map<String, String> values) async {
    try {
      if (!_groupSet && defaultTargetPlatform == TargetPlatform.iOS) {
        await HomeWidget.setAppGroupId(AppConfig.appGroupId);
        _groupSet = true;
      }
      for (final e in values.entries) {
        if (_written[e.key] != e.value) await HomeWidget.saveWidgetData<String>(e.key, e.value);
      }
      _written = {..._written, ...values};
      for (final (ios, android) in homeWidgetKinds) {
        await HomeWidget.updateWidget(iOSName: ios, qualifiedAndroidName: 'app.nexus.nexus_mobile.widgets.$android');
      }
    } on Object {
      // Widget extension not installed yet — data is retried on the next change.
    }
  }

  void dispose() => stop();
}
