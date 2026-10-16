import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nexus_mobile/core/api/api_client.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';
import 'package:nexus_mobile/features/home/home_modules.dart';
import 'package:nexus_mobile/features/home/home_refresh.dart';

// ── Helpers (web routes/sports/sports.ts) ─────────────────────────────────

const sportLabels = {
  'football': 'Football',
  'tennis': 'Tennis',
  'rugby': 'Rugby',
  'golf': 'Golf',
  'darts': 'Darts',
  'field-hockey': 'Field Hockey',
};

enum ImageSize { tiny, small, medium }

/// TheSportsDB serves resized artwork at /tiny (50px), /small (250px) and
/// /medium (500px).
String? sizedImage(String? url, ImageSize size) {
  if (url == null || url.isEmpty) return null;
  return '${url.replaceFirst(RegExp(r'/(tiny|small|medium)/?$'), '')}/${size.name}';
}

/// National rugby sides arrive as "Ireland Rugby"; the sport is already on screen.
String teamLabel(String? name, String sport) {
  if (name == null || name.isEmpty) return 'TBC';
  return sport == 'rugby' ? name.replaceFirst(RegExp(r'\s+Rugby$', caseSensitive: false), '') : name;
}

bool hasMatchup(Json e) => e.str('home_team') != null && e.str('away_team') != null;

bool hasScore(Json e) => e['home_score'] != null || e['away_score'] != null;

String eventName(Json e) => e.text('name').replaceAll(RegExp(r'\s{2,}'), ' ').trim();

/// "Sat 5 Feb · 20:10", or just the date when the feed has no kick-off time.
String eventWhen(Json e) {
  final iso = e.str('starts_at') ?? e.str('event_date');
  if (iso == null) return 'TBC';
  final dateOnly = iso.length == 10 || RegExp(r'T00:00:00(\.000)?(Z|\+00:00)$').hasMatch(iso);
  final d = DateTime.tryParse(iso.length == 10 ? '${iso}T00:00:00Z' : iso);
  if (d == null) return 'TBC';
  final date = DateFormat('EEE d MMM');
  if (dateOnly) return date.format(d.toUtc());
  final local = d.toLocal();
  return '${date.format(local)} · ${DateFormat('HH:mm').format(local)}';
}

/// Result text arrives as HTML fragments; keep the lines, drop the markup.
List<String> resultLines(String? raw, {int max = 6}) {
  if (raw == null || raw.isEmpty) return const [];
  final text = raw
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp('<[^>]+>'), '')
      .replaceAll('&amp;', '&')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&#39;', "'")
      .replaceAll('&quot;', '"');
  return text
      .split(RegExp(r'\r?\n'))
      .map((l) => l.replaceAll(RegExp(r'[ \t]+'), ' ').trim())
      .where((l) => l.isNotEmpty)
      .take(max)
      .toList();
}

typedef StandingRow = ({
  int rank,
  String team,
  String? badge,
  String played,
  String gd,
  String points,
  List<String> form,
  String note,
});

List<StandingRow> tableRows(Json block, {int limit = 20}) {
  String s(Object? v) => v == null || v == '' ? '—' : '$v';
  return [
    for (final (i, row) in block.list('rows').take(limit).indexed)
      (
        rank: row.integer('intRank') ?? i + 1,
        team: s(row['strTeam'] ?? row['name']),
        badge: row.str('strBadge'),
        played: s(row['intPlayed']),
        gd: s(row['intGoalDifference']),
        points: s(row['intPoints']),
        form: switch (row.str('strForm')) {
          final f? => f.substring(f.length > 5 ? f.length - 5 : 0).split(''),
          null => const <String>[],
        },
        note: row.text('strDescription'),
      ),
  ];
}

String initials(String? label) =>
    (label ?? '?').split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join();

// ── Data ───────────────────────────────────────────────────────────────────

final sportOverviewProvider = FutureProvider.autoDispose.family<Json, String>(
  (ref, sport) async => asJson(await ref.watch(apiClientProvider).get('/sports/$sport')),
);

Future<void> syncSports(BuildContext context, WidgetRef ref, String sport) async {
  try {
    final before = ref.read(sportsHomeProvider).value?.str('computed_at');
    await ref.read(apiClientProvider).post('/sports/sync', data: {'type': 'all'});
    ref.invalidate(sportOverviewProvider(sport));
    if (context.mounted) showNxToast(context, 'Sync queued.');
    unawaited(
      pollHomeSurfacesAfterSync(
        ref,
        isFresh: () {
          final at = ref.read(sportsHomeProvider).value?.str('computed_at');
          return at != null && at != before;
        },
      ),
    );
  } on Object catch (e) {
    if (context.mounted) showApiError(context, e, 'Sync failed.');
  }
}
