import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_mobile/features/f1/f1.dart';
import 'package:nexus_mobile/features/f1/f1_session_screen.dart';
import 'package:nexus_mobile/features/f1/f1_track_replay.dart';
import 'package:nexus_mobile/features/sports/sports.dart';

void main() {
  group('F1 helpers', () {
    test('teamColour parses bare hex with a fallback', () {
      expect(teamColour('00D7B6'), const Color(0xFF00D7B6));
      expect(teamColour('#ff8000'), const Color(0xFFFF8000));
      expect(teamColour(null), const Color(0xFF8A8A8A));
      expect(teamColour('nope'), const Color(0xFF8A8A8A));
    });

    test('driverName title-cases shouted surnames', () {
      expect(driverName('Kimi ANTONELLI'), 'Kimi Antonelli');
      expect(driverName(null, '#12'), '#12');
      expect(surname('Lando NORRIS'), 'Norris');
    });

    test('timing formats laps, gaps and segment arrays', () {
      expect(lapTime(91.586), '1:31.586');
      expect(lapTime(5812.4), '1:36:52.400');
      expect(timing(1.2345, gap: true), '+1.234');
      expect(timing('+1 LAP', gap: true), '+1 LAP');
      expect(timing([80.1, null, 79.9]), '1:20.100 / 1:19.900');
      expect(timing(null), '—');
    });

    test('countdown picks the two largest units', () {
      final now = DateTime(2026, 10, 9, 12);
      String iso(Duration d) => now.add(d).toUtc().toIso8601String();
      expect(countdown(iso(const Duration(days: 1, hours: 22)), now), ('1 day,', '22 hours'));
      expect(countdown(iso(const Duration(hours: 3, minutes: 5)), now), ('3 hours,', '5 minutes'));
      expect(countdown(iso(const Duration(minutes: 1)), now), ('In', '1 minute'));
      expect(countdown(iso(const Duration(minutes: -5)), now), isNull);
    });

    test('splitMeetingName separates Grand Prix', () {
      expect(splitMeetingName('Singapore Grand Prix'), ('Singapore', 'Grand Prix'));
      expect(splitMeetingName('Pre-Season Testing'), ('Pre-Season', 'Testing'));
      expect(splitMeetingName('Solo'), ('Solo', null));
    });

    test('rounds skip testing and cancelled meetings', () {
      final meetings = [
        {'meeting_name': 'Pre-Season Testing'},
        {'meeting_name': 'Australian Grand Prix'},
        {'meeting_name': 'Chinese Grand Prix', 'is_cancelled': true},
        {'meeting_name': 'Japanese Grand Prix'},
      ];
      expect(rounds(meetings).map((m) => m['meeting_name']), ['Australian Grand Prix', 'Japanese Grand Prix']);
    });

    test('focusSession prefers live, then next', () {
      final now = DateTime.utc(2026, 10, 9, 12);
      String at(int h) => now.add(Duration(hours: h)).toIso8601String();
      final sessions = [
        {'session_key': 1, 'date_start': at(-5), 'date_end': at(-4)},
        {'session_key': 2, 'date_start': at(-1), 'date_end': at(1)},
        {'session_key': 3, 'date_start': at(3), 'date_end': at(4)},
      ];
      expect(focusSession(sessions, now)?['session_key'], 2);
      expect(focusSession(sessions.where((s) => s['session_key'] != 2).toList(), now)?['session_key'], 3);
      expect(sessionState(sessions[0], null, now), SessionState.done);
    });

    test('sessionStatus explains where results stand', () {
      final now = DateTime.utc(2026, 10, 9, 12);
      final past = {'date_start': '2026-10-08T10:00:00Z', 'date_end': '2026-10-08T11:00:00Z'};
      expect(sessionStatus({...past, 'detail_synced': true}, now).$1, 'Results ready');
      expect(sessionStatus({...past, 'historically_available': true}, now).$1, 'Ready to sync');
      expect(sessionStatus({...past, 'is_cancelled': true}, now).$1, 'Cancelled');
      expect(sessionStatus(past, now).$1, 'Processing');
    });

    test('sortResults ranks classified finishers before retirements', () {
      final sorted = sortResults([
        {'driver_number': 1, 'position': null, 'number_of_laps': 10},
        {'driver_number': 2, 'position': 2},
        {'driver_number': 3, 'position': null, 'number_of_laps': 40},
        {'driver_number': 4, 'position': 1},
      ]);
      expect(sorted.map((r) => r['driver_number']), [4, 2, 3, 1]);
    });

    test('weatherRange collapses steady readings', () {
      final samples = [
        {'air_temperature': 21.2, 'humidity': 60},
        {'air_temperature': 23.8, 'humidity': 60.4},
      ];
      expect(weatherRange(samples, 'air_temperature', '°C'), '21–24°C');
      expect(weatherRange(samples, 'humidity', '%'), '60%');
      expect(weatherRange(samples, 'wind_speed', ' m/s'), isNull);
    });
  });

  group('ReplayModel', () {
    final payload = {
      'bounds': {'min_x': 0, 'max_x': 100, 'min_y': 0, 'max_y': 50},
      'drivers': [
        {'driver_number': 44, 'name_acronym': 'HAM', 'team_colour': 'DC0000'},
        {'driver_number': 99, 'name_acronym': 'GHO'},
      ],
      'location': [
        {'driver_number': 44, 'date': '2026-10-09T12:00:02Z', 'x': 20, 'y': 5},
        {'driver_number': 44, 'date': '2026-10-09T12:00:00Z', 'x': 0, 'y': 0},
        {'driver_number': 44, 'date': '2026-10-09T12:00:04Z', 'x': 40, 'y': 10},
        {'driver_number': 16, 'date': '2026-10-09T12:00:01Z', 'x': 5, 'y': 5},
        {'driver_number': 16, 'date': null, 'x': 5, 'y': 5},
      ],
    };

    test('groups samples per car, sorted, with a shared timeline', () {
      final m = ReplayModel.from(payload);
      expect(m.tracks[44]!.map((s) => s.x), [0, 20, 40]);
      expect(m.times, hasLength(4));
      expect(m.cars.map((c) => c.code), ['HAM']);
      expect(m.outline, hasLength(3));
      expect(m.bounds, const Rect.fromLTRB(0, 0, 100, 50));
    });

    test('positionAt returns the last sample at or before t', () {
      final m = ReplayModel.from(payload);
      final track = m.tracks[44]!;
      final t0 = track.first.t;
      expect(ReplayModel.positionAt(track, t0 - 1), isNull);
      expect(ReplayModel.positionAt(track, t0 + 3000)?.x, 20);
      expect(ReplayModel.positionAt(track, t0 + 9000)?.x, 40);
    });
  });

  group('Sports helpers', () {
    test('sizedImage swaps the TheSportsDB size suffix', () {
      expect(
        sizedImage('https://r2.thesportsdb.com/a/b.png/small', ImageSize.tiny),
        'https://r2.thesportsdb.com/a/b.png/tiny',
      );
      expect(sizedImage('https://x/b.png', ImageSize.medium), 'https://x/b.png/medium');
      expect(sizedImage(null, ImageSize.tiny), isNull);
    });

    test('teamLabel trims "Rugby" only for rugby', () {
      expect(teamLabel('Ireland Rugby', 'rugby'), 'Ireland');
      expect(teamLabel('Ireland Rugby', 'football'), 'Ireland Rugby');
      expect(teamLabel(null, 'rugby'), 'TBC');
    });

    test('eventWhen shows date only when there is no kick-off time', () {
      expect(eventWhen({'event_date': '2026-02-07'}), 'Sat 7 Feb');
      expect(eventWhen({'starts_at': '2026-02-07T00:00:00+00:00'}), 'Sat 7 Feb');
      expect(eventWhen({}), 'TBC');
      expect(eventWhen({'starts_at': '2026-02-07T18:10:00Z'}), contains(' · '));
    });

    test('resultLines strips markup and keeps lines', () {
      expect(resultLines('1. Scheffler -12<br/>2. McIlroy &amp; co -10<br>\n<b>3.</b>  Rahm -9', max: 2), [
        '1. Scheffler -12',
        '2. McIlroy & co -10',
      ]);
      expect(resultLines(null), isEmpty);
    });

    test('tableRows normalises TheSportsDB standings', () {
      final rows = tableRows({
        'rows': [
          {
            'intRank': '1',
            'strTeam': 'Arsenal',
            'intPlayed': 7,
            'intGoalDifference': 9,
            'intPoints': 17,
            'strForm': 'WWDLWW',
          },
          {'strTeam': 'Chelsea'},
        ],
      });
      expect(rows.first.rank, 1);
      expect(rows.first.form, ['W', 'D', 'L', 'W', 'W']);
      expect(rows.first.points, '17');
      expect(rows.last.rank, 2);
      expect(rows.last.played, '—');
      expect(initials('Manchester United FC'), 'MU');
    });
  });
}
