import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_mobile/core/native/deep_links.dart';
import 'package:nexus_mobile/core/native/push.dart';
import 'package:nexus_mobile/core/native/shortcuts.dart';
import 'package:nexus_mobile/features/f1/f1_live_activity.dart';
import 'package:nexus_mobile/features/home/home_widgets.dart';
import 'package:nexus_mobile/features/listening/player.dart';

void main() {
  group('deep links', () {
    test('safeAppPath only allows same-app absolute paths', () {
      expect(safeAppPath('/cellar/wines/3'), '/cellar/wines/3');
      expect(safeAppPath(' /f1 '), '/f1');
      expect(safeAppPath('//evil.example/x'), isNull);
      expect(safeAppPath('https://evil.example'), isNull);
      expect(safeAppPath('/../etc'), isNull);
      expect(safeAppPath(r'/a\b'), isNull);
      expect(safeAppPath(''), isNull);
      expect(safeAppPath(null), isNull);
      expect(safeAppPath('/${'a' * 600}'), isNull);
    });

    test('appPathFromUri maps the custom scheme and the web host', () {
      expect(appPathFromUri(Uri.parse('nexus://open/cellar/wines/3')), '/cellar/wines/3');
      expect(appPathFromUri(Uri.parse('nexus://open/capture?kind=wine')), '/capture?kind=wine');
      expect(appPathFromUri(Uri.parse('nexus://open')), '/home');
      expect(appPathFromUri(Uri.parse('nexus://oauth/spotify?connected=1')), isNull);
      expect(
        appPathFromUri(Uri.parse('https://nexus.example/f1/sessions/9'), webHost: 'nexus.example'),
        '/f1/sessions/9',
      );
      expect(appPathFromUri(Uri.parse('https://other.example/f1'), webHost: 'nexus.example'), isNull);
      expect(appPathFromUri(Uri.parse('https://nexus.example/f1')), isNull);
      expect(appPathFromUri(Uri.parse('http://nexus.example/f1'), webHost: 'nexus.example'), isNull);
    });

    test('push payload routes fall back to home', () {
      expect(pushRoute({'route': '/beer/beers/4'}), '/beer/beers/4');
      expect(pushRoute({'route': '//evil'}), '/home');
      expect(pushRoute({}), '/home');
    });

    test('firebase options need every define', () {
      expect(firebaseOptionsFor(TargetPlatform.android), isNull);
      expect(firebaseOptionsFor(TargetPlatform.iOS), isNull);
    });

    test('shortcuts resolve to capture modes', () {
      expect(shortcutPath('log_wine'), '/capture?kind=wine');
      expect(shortcutPath('scan_book'), '/capture?kind=book&mode=barcode');
      expect(shortcutPath('nope'), isNull);
      for (final s in appShortcuts) {
        expect(safeAppPath(s.path), s.path);
      }
    });
  });

  group('widgetSnapshot', () {
    test('defaults when nothing is known', () {
      final s = widgetSnapshot();
      expect(s['listening_title'], 'Nothing playing');
      expect(s['listening_state'], '');
      expect(s['race_title'], 'No race scheduled');
      expect(s['race_route'], '/f1');
      expect(s.containsKey('tonight_title'), isFalse);
    });

    test('now playing and the next meeting', () {
      final s = widgetSnapshot(
        player: const PlayerState(
          playback: {
            'is_playing': true,
            'item': {
              'name': 'Maria También',
              'artists': [
                {'name': 'Khruangbin'},
              ],
            },
          },
        ),
        f1Home: {
          'next_meeting': {
            'meeting_key': 1250,
            'meeting_name': 'Singapore Grand Prix',
            'circuit_short_name': 'Marina Bay',
            'country_name': 'Singapore',
            'date_start': '2026-10-02T09:30:00Z',
          },
        },
      );
      expect(s['listening_title'], 'Maria También');
      expect(s['listening_artist'], 'Khruangbin');
      expect(s['listening_state'], 'Playing');
      expect(s['race_label'], 'Next race');
      expect(s['race_title'], 'Singapore Grand Prix');
      expect(s['race_sub'], 'Marina Bay · Singapore');
      expect(s['race_when'], isNotEmpty);
      expect(s['race_route'], '/f1/meetings/1250');
    });

    test('a race moment wins over the calendar; cellar fills tonight', () {
      final race = widgetSnapshot(
        now: {
          'moment': 'race',
          'eyebrow': 'Live · Race',
          'title': 'Singapore',
          'accent': 'Grand Prix',
          'lede': 'Marina Bay',
          'session': {'starts_at': '2026-10-04T12:00:00Z'},
          'actions': [
            {'to': '/f1/sessions/9900'},
          ],
        },
        f1Home: {
          'next_meeting': {'meeting_name': 'Other'},
        },
      );
      expect(race['race_label'], 'Live · Race');
      expect(race['race_title'], 'Singapore Grand Prix');
      expect(race['race_route'], '/f1/sessions/9900');

      final cellar = widgetSnapshot(
        now: {
          'moment': 'cellar',
          'accent': '2019 Chryseia',
          'lede': 'Douro',
          'actions': [
            {'to': '/cellar/wines/7'},
          ],
        },
      );
      expect(cellar['tonight_title'], '2019 Chryseia');
      expect(cellar['tonight_route'], '/cellar/wines/7');
    });
  });

  group('liveSessionFrom', () {
    final start = DateTime.utc(2026, 10, 4, 12);
    final now = {
      'moment': 'race',
      'title': 'Singapore',
      'accent': 'Grand Prix',
      'lede': 'Marina Bay · Singapore',
      'subject': {'type': 'f1_session', 'id': 9900},
      'session': {'name': 'Race', 'starts_at': '2026-10-04T12:00:00Z', 'ends_at': '2026-10-04T14:00:00Z'},
      'actions': [
        {'to': '/f1/sessions/9900'},
      ],
    };

    test('opens an hour before lights-out and closes at the end', () {
      expect(liveSessionFrom(now, start.subtract(const Duration(hours: 2))), isNull);
      final live = liveSessionFrom(now, start.subtract(const Duration(minutes: 30)));
      expect(live?.id, 'f1-9900');
      expect(live?.title, 'Singapore Grand Prix');
      expect(live?.session, 'Race');
      expect(live?.route, '/f1/sessions/9900');
      expect(liveSessionFrom(now, start.add(const Duration(hours: 1))), isNotNull);
      expect(liveSessionFrom(now, start.add(const Duration(hours: 2))), isNull);
    });

    test('assumes two hours when the end is unknown; ignores other moments', () {
      final open = {
        ...now,
        'session': {'name': 'Race', 'starts_at': '2026-10-04T12:00:00Z'},
      };
      expect(liveSessionFrom(open, start.add(const Duration(minutes: 119))), isNotNull);
      expect(liveSessionFrom(open, start.add(const Duration(minutes: 121))), isNull);
      expect(liveSessionFrom({'moment': 'music'}, start), isNull);
      expect(liveSessionFrom(null, start), isNull);
    });
  });
}
