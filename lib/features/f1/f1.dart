import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nexus_mobile/core/api/api_client.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/core/api/providers.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';
import 'package:nexus_mobile/features/home/home_modules.dart';

// ── Helpers (web routes/f1/f1.ts) ──────────────────────────────────────────

const _fallbackTeam = Color(0xFF8A8A8A);

/// OpenF1 sends team colours as bare hex ("00D7B6").
Color teamColour(String? raw) {
  final hex = (raw ?? '').trim().replaceFirst('#', '');
  if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(hex)) return _fallbackTeam;
  return Color(int.parse('FF$hex', radix: 16));
}

/// "Kimi ANTONELLI" → "Kimi Antonelli".
String driverName(String? name, [String fallback = 'Unknown']) {
  if (name == null || name.trim().isEmpty) return fallback;
  return name
      .split(RegExp(r'\s+'))
      .map((w) => w == w.toUpperCase() && w.length > 1 ? '${w[0]}${w.substring(1).toLowerCase()}' : w)
      .join(' ');
}

String surname(String? name) {
  final full = driverName(name, '');
  return full.isEmpty ? '' : full.split(' ').last;
}

/// Team colour per team name, taken from the driver standings.
Map<String, Color> teamColours(List<Json> drivers) {
  final out = <String, Color>{};
  for (final d in drivers) {
    final (team, colour) = (d.str('team_name'), d.str('team_colour'));
    if (team != null && colour != null) out.putIfAbsent(team, () => teamColour(colour));
  }
  return out;
}

bool isTesting(Json meeting) => RegExp('testing', caseSensitive: false).hasMatch(meeting.text('meeting_name'));

/// Championship rounds only (pre-season testing excluded).
List<Json> rounds(List<Json> meetings) => [
  for (final m in meetings)
    if (!isTesting(m) && !m.flag('is_cancelled')) m,
];

DateTime? _at(String? value) => value == null ? null : DateTime.tryParse(value)?.toLocal();

enum SessionState { done, live, next, upcoming }

/// The session that is live now, or the next one to start.
Json? focusSession(List<Json> sessions, DateTime now) {
  final list = sessions.where((s) => !s.flag('is_cancelled')).toList();
  for (final s in list) {
    final (start, end) = (_at(s.str('date_start')), _at(s.str('date_end')));
    if (start != null && end != null && !start.isAfter(now) && now.isBefore(end)) return s;
  }
  for (final s in list) {
    if (_at(s.str('date_start'))?.isAfter(now) ?? false) return s;
  }
  return null;
}

SessionState sessionState(Json session, Json? focus, DateTime now) {
  final start = _at(session.str('date_start')) ?? DateTime(0);
  final end = _at(session.str('date_end')) ?? start;
  if (!now.isBefore(end)) return SessionState.done;
  if (!now.isBefore(start)) return SessionState.live;
  return focus?.integer('session_key') == session.integer('session_key') ? SessionState.next : SessionState.upcoming;
}

String _unit(int n, String word) => '$n $word${n == 1 ? '' : 's'}';

/// Countdown as serif title + italic accent: ("1 day,", "22 hours").
(String, String)? countdown(String? target, DateTime now) {
  final t = _at(target);
  if (t == null || !t.isAfter(now)) return null;
  final mins = t.difference(now).inMinutes;
  final (days, hours, minutes) = (mins ~/ 1440, (mins % 1440) ~/ 60, mins % 60);
  if (days > 0) return ('${_unit(days, 'day')},', _unit(hours, 'hour'));
  if (hours > 0) return ('${_unit(hours, 'hour')},', _unit(minutes, 'minute'));
  return ('In', _unit(minutes < 1 ? 1 : minutes, 'minute'));
}

/// "Fri 10:30" in the viewer's own timezone.
String sessionWhen(String? value) {
  final t = _at(value);
  return t == null ? 'TBC' : DateFormat('EEE HH:mm').format(t);
}

/// "9–11 Oct" or "30 Sep – 2 Oct".
String meetingDates(Json meeting) {
  final (s, e) = (_at(meeting.str('date_start')), _at(meeting.str('date_end')));
  if (s == null) return 'TBC';
  if (e == null || !e.isAfter(s) || (e.day == s.day && e.month == s.month)) return DateFormat('d MMM').format(s);
  if (e.month == s.month) return '${s.day}–${DateFormat('d MMM').format(e)}';
  return '${DateFormat('d MMM').format(s)} – ${DateFormat('d MMM').format(e)}';
}

/// "Marina Bay, Singapore" without repeating a city-state's name.
String meetingPlace(Json meeting) => {
  ?(meeting.str('circuit_short_name') ?? meeting.str('location')),
  ?meeting.str('country_name'),
}.join(', ');

SessionState meetingState(Json meeting, DateTime now) {
  final s = _at(meeting.str('date_start')) ?? DateTime(0);
  final e = _at(meeting.str('date_end')) ?? s;
  if (!now.isBefore(e)) return SessionState.done;
  if (!now.isBefore(s)) return SessionState.live;
  return SessionState.upcoming;
}

/// 91.586 → "1:31.586"; 5812.4 → "1:36:52.400".
String lapTime(num seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = (seconds % 60).toStringAsFixed(3).padLeft(6, '0');
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$s';
  return m > 0 ? '$m:$s' : s;
}

/// OpenF1 durations / gaps are numbers, strings ("+1 LAP") or per-segment
/// arrays (qualifying).
String timing(Object? value, {bool gap = false}) {
  if (value == null || value == '') return '—';
  if (value is List) {
    final parts = value.where((v) => v != null).toList();
    return parts.isEmpty ? '—' : parts.map((v) => timing(v, gap: gap)).join(' / ');
  }
  if (value is num) return gap ? '+${value.toStringAsFixed(3)}' : lapTime(value);
  return value.toString();
}

String timeOfDay(String? value) {
  final t = _at(value);
  return t == null ? '—' : DateFormat('HH:mm').format(t);
}

/// "Singapore Grand Prix" → ("Singapore", "Grand Prix").
(String, String?) splitMeetingName(String name) {
  final gp = RegExp(r'^(.*?)\s+(Grand Prix)$', caseSensitive: false).firstMatch(name);
  if (gp != null && gp[1]!.isNotEmpty) return (gp[1]!, gp[2]);
  final words = name.trim().split(RegExp(r'\s+'));
  if (words.length < 2) return (name, null);
  return (words.sublist(0, words.length - 1).join(' '), words.last);
}

enum StatusTone { ok, live, muted, pending }

/// Where a session's data stands, from the viewer's point of view.
(String, StatusTone) sessionStatus(Json session, DateTime now) {
  if (session.flag('is_cancelled')) return ('Cancelled', StatusTone.muted);
  if (session.flag('detail_synced')) return ('Results ready', StatusTone.ok);
  final start = _at(session.str('date_start')) ?? DateTime(0);
  final end = _at(session.str('date_end')) ?? start;
  if (now.isBefore(start)) return ('Upcoming', StatusTone.muted);
  if (now.isBefore(end)) return ('Live now', StatusTone.live);
  if (session.flag('historically_available')) return ('Ready to sync', StatusTone.pending);
  return ('Processing', StatusTone.pending);
}

// ── Data ───────────────────────────────────────────────────────────────────

/// A clock that ticks every 30s for countdowns and session states.
final f1ClockProvider = StreamProvider.autoDispose<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(seconds: 30), (_) => DateTime.now());
});

final f1StatusProvider = softJsonProvider('/f1/status');

/// Season calendar plus driver / constructor standings (web loadSeason).
final f1SeasonProvider = FutureProvider.autoDispose<({Json season, Json standings})>((ref) async {
  final api = ref.watch(apiClientProvider);
  Future<Json> standings() async {
    try {
      return asJson(await api.get('/f1/standings'));
    } on Object {
      return const {};
    }
  }

  final (season, table) = await (api.get('/f1/season').then(asJson), standings()).wait;
  return (season: season, standings: table);
});

final f1MeetingProvider = FutureProvider.autoDispose.family<Json, int>(
  (ref, key) async => asJson(await ref.watch(apiClientProvider).get('/f1/meetings/$key')),
);

final f1SessionProvider = FutureProvider.autoDispose.family<({Json detail, Json analysis}), int>((ref, key) async {
  final api = ref.watch(apiClientProvider);
  final detail = asJson(await api.get('/f1/sessions/$key'));
  Json analysis;
  try {
    analysis = asJson(await api.get('/f1/sessions/$key/analysis'));
  } on Object {
    analysis = const {};
  }
  return (detail: detail, analysis: analysis);
});

final f1ApiProvider = Provider(F1Api.new);

class F1Api {
  F1Api(this._ref);

  final Ref _ref;

  ApiClient get _api => _ref.read(apiClientProvider);

  Future<void> sync({String type = 'all'}) async {
    await _api.post('/f1/sync', data: {'type': type});
    _ref
      ..invalidate(f1SeasonProvider)
      ..invalidate(f1HomeProvider)
      ..invalidate(f1StatusProvider);
  }

  Future<Json> replay(int sessionKey, {int? driver}) async =>
      asJson(await _api.get('/f1/sessions/$sessionKey/replay', query: {'driver_number': driver}));

  Future<String?> replayStatus(int sessionKey) async =>
      asJson(await _api.get('/f1/sessions/$sessionKey/replay/status')).str('status');

  Future<void> retryReplay(int sessionKey) => _api.post('/f1/sessions/$sessionKey/replay/retry');
}

Future<void> syncF1(BuildContext context, WidgetRef ref) async {
  try {
    await ref.read(f1ApiProvider).sync();
    if (context.mounted) showNxToast(context, 'Sync queued.');
  } on Object catch (e) {
    if (context.mounted) showApiError(context, e, 'Sync failed.');
  }
}
