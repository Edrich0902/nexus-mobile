import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_mobile/core/api/api_client.dart';
import 'package:nexus_mobile/core/auth/auth.dart';
import 'package:nexus_mobile/features/listening/listening.dart';
import 'package:nexus_mobile/features/listening/player.dart';

import '../support/fakes.dart';

Future<void> _ticks([int n = 10]) async {
  for (var i = 0; i < n; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('player starts while Spotify status is loading, then polls once connected', () async {
    final status = Completer<Object?>();
    final api = FakeApi({
      'GET /spotify/status': (_, _) => status.future,
      'GET /spotify/player': (_, _) => {'is_playing': false},
      'GET /spotify/listening/settings': (_, _) => {'auto_queue_enabled': true},
    });
    final container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(api), authProvider.overrideWith(SignedInAuth.new)],
    );
    addTearDown(container.dispose);
    final sub = container.listen(playerProvider, (_, _) {});
    addTearDown(sub.close);

    await _ticks();
    expect(container.read(playerProvider).settings, isNull);
    expect(api.calls, ['GET /spotify/status']);

    status.complete({'connected': true});
    await _ticks();
    expect(api.calls, containsAll(['GET /spotify/player', 'GET /spotify/listening/settings']));
    expect(container.read(playerProvider).autoQueue, isTrue);
  });

  test('player already connected at build still loads settings', () async {
    final api = FakeApi({
      'GET /spotify/status': (_, _) => {'connected': true},
      'GET /spotify/player': (_, _) => {'is_playing': false},
      'GET /spotify/listening/settings': (_, _) => {'auto_queue_enabled': true},
    });
    final container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(api), authProvider.overrideWith(SignedInAuth.new)],
    );
    addTearDown(container.dispose);
    await container.read(spotifyStatusProvider.future);
    final sub = container.listen(playerProvider, (_, _) {});
    addTearDown(sub.close);

    await _ticks();
    expect(container.read(playerProvider).autoQueue, isTrue);
  });

  test('splitTrackTitle pulls the accent from brackets or a dash', () {
    expect(splitTrackTitle('Time (You and I)'), ('Time', '(You and I)'));
    expect(splitTrackTitle('Heroes - 2017 Remaster'), ('Heroes', '2017 Remaster'));
    expect(splitTrackTitle('Plain'), ('Plain', null));
  });

  test('durations and years', () {
    expect(formatDuration(3 * 60 * 1000 + 59 * 1000), '3 min');
    expect(formatDuration(65 * 60 * 1000), '1 hr 5 min');
    expect(
      totalDuration([
        {'duration_ms': 60000},
        {'duration_ms': 120000},
      ]),
      '3 min',
    );
    expect(releaseYear('2019-04-01'), '2019');
    expect(releaseYear(null), isNull);
  });

  test('plainText strips tags and entities', () {
    expect(plainText('Rock &amp; roll <a href="x">here</a>'), 'Rock & roll here');
    expect(plainText(null), '');
  });

  test('audioMeters clamps and labels known traits only', () {
    final rows = audioMeters({'energy': 1.4, 'valence': .5, 'tempo': 120});
    expect(rows.map((r) => r.label), ['Energy', 'Mood']);
    expect(rows.first.value, 1);
    expect(rows.last.word, '50%');
    expect(audioMeters(null), isEmpty);
  });
}
