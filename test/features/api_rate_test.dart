import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_mobile/core/api/api_client.dart';
import 'package:nexus_mobile/core/auth/auth.dart';
import 'package:nexus_mobile/design/palettes.dart';
import 'package:nexus_mobile/features/listening/listening.dart';
import 'package:nexus_mobile/features/listening/player.dart';

import '../support/fakes.dart';

const _contains = 'GET /spotify/library/contains';

Future<void> _ticks([int n = 10]) async {
  for (var i = 0; i < n; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Map<String, Handler> _spotify({Handler? contains}) => {
  'GET /spotify/status': (_, _) => {'connected': true},
  'GET /spotify/player': (_, _) => {'is_playing': false},
  _contains:
      contains ??
      (q, _) => {
        'contains': [for (final _ in (q!['uris'] as String).split(',')) true],
      },
};

/// Rebuilds a fresh (but identical) track list on every player change, the
/// way the Listening screen builds its sections.
class _FreshTracks extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(playerProvider);
    return SingleChildScrollView(
      child: TrackList(
        numbered: true,
        tracks: [
          for (final id in ['a', 'b']) {'uri': 'spotify:track:$id', 'name': 'Track $id', 'artists': const <Object>[]},
        ],
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a track list rebuilt with fresh but identical tracks checks liked state once', (tester) async {
    final api = FakeApi(_spotify());
    await tester.pumpWidget(
      nexusTestApp(
        const _FreshTracks(),
        overrides: [apiClientProvider.overrideWithValue(api), authProvider.overrideWith(SignedInAuth.new)],
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final container = ProviderScope.containerOf(tester.element(find.byType(_FreshTracks)));
    await container.read(playerProvider.notifier).refresh();
    await tester.pump();
    await container.read(playerProvider.notifier).refresh();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(api.calls.where((c) => c == _contains), hasLength(1));
    expect(container.read(playerProvider).liked, {'spotify:track:a': true, 'spotify:track:b': true});
  });

  test('liked checks skip known and in-flight URIs and only ask for new ones', () async {
    final gate = Completer<void>();
    final asked = <String>[];
    final api = FakeApi(
      _spotify(
        contains: (q, _) async {
          asked.add(q!['uris'] as String);
          await gate.future;
          return {
            'contains': [for (final _ in (q['uris'] as String).split(',')) false],
          };
        },
      ),
    );
    final container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(api), authProvider.overrideWith(SignedInAuth.new)],
    );
    addTearDown(container.dispose);
    await container.read(spotifyStatusProvider.future);
    final sub = container.listen(playerProvider, (_, _) {});
    addTearDown(sub.close);
    final player = container.read(playerProvider.notifier);

    final first = player.refreshLikedFor(['u1', 'u2']);
    final duplicate = player.refreshLikedFor(['u1', 'u2']);
    gate.complete();
    await Future.wait([first, duplicate]);
    await player.refreshLikedFor(['u1', 'u2']);
    await player.refreshLikedFor(['u1', 'u2', 'u3']);

    expect(asked, ['u1,u2', 'u3']);
  });

  test('liked checks stay bounded at 50 URIs per request', () async {
    final sizes = <int>[];
    final api = FakeApi(
      _spotify(
        contains: (q, _) {
          final uris = (q!['uris'] as String).split(',');
          sizes.add(uris.length);
          return {'contains': List.filled(uris.length, false)};
        },
      ),
    );
    final container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(api), authProvider.overrideWith(SignedInAuth.new)],
    );
    addTearDown(container.dispose);
    await container.read(spotifyStatusProvider.future);
    final sub = container.listen(playerProvider, (_, _) {});
    addTearDown(sub.close);

    await container.read(playerProvider.notifier).refreshLikedFor([for (var i = 0; i < 120; i++) 'u$i']);

    expect(sizes, [50, 50, 20]);
  });

  test('a Spotify status reload does not fire an extra player request', () async {
    final api = FakeApi(_spotify());
    final container = ProviderContainer(
      overrides: [apiClientProvider.overrideWithValue(api), authProvider.overrideWith(SignedInAuth.new)],
    );
    addTearDown(container.dispose);
    await container.read(spotifyStatusProvider.future);
    final sub = container.listen(playerProvider, (_, _) {});
    addTearDown(sub.close);
    await _ticks();

    for (var i = 0; i < 3; i++) {
      container.invalidate(spotifyStatusProvider);
      await container.read(spotifyStatusProvider.future);
      await _ticks();
    }

    expect(api.calls.where((c) => c == 'GET /spotify/player'), hasLength(1));
    expect(api.calls.where((c) => c.contains('/spotify/listening/settings')), isEmpty);
  });

  test('palette lookups never repeat for URLs in flight or waiting out their backoff', () async {
    final gate = Completer<void>();
    final api = FakeApi({
      'POST /palettes': (_, _) async {
        await gate.future;
        return {'palettes': <String, dynamic>{}};
      },
    });
    final container = ProviderContainer(overrides: [apiClientProvider.overrideWithValue(api)]);
    addTearDown(container.dispose);
    final cache = container.read(paletteCacheProvider.notifier);
    const urls = ['https://img/a.jpg', 'https://img/b.jpg'];

    for (var i = 0; i < 5; i++) {
      cache.want(urls);
    }
    gate.complete();
    await _ticks();
    for (var i = 0; i < 5; i++) {
      cache.want(urls);
    }

    expect(api.calls, ['POST /palettes']);
  });
}
