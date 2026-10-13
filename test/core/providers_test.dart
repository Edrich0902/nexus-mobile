import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_mobile/core/api/api_client.dart';
import 'package:nexus_mobile/core/api/paged.dart';
import 'package:nexus_mobile/core/auth/auth.dart';
import 'package:nexus_mobile/core/auth/session.dart';
import 'package:nexus_mobile/core/native/push.dart';

import '../support/fakes.dart';

Future<AuthState> _settled(ProviderContainer container) async {
  var state = container.read<AuthState>(authProvider);
  for (var i = 0; i < 20 && state is AuthUnknown; i++) {
    await Future<void>.delayed(Duration.zero);
    state = container.read<AuthState>(authProvider);
  }
  return state;
}

void main() {
  group('AuthController', () {
    late MemorySessionStore store;
    late FakeApi api;
    late FakePush push;
    late ProviderContainer container;

    setUp(() {
      store = MemorySessionStore();
      api = FakeApi({
        'POST /auth/login': (_, data) => {
          'token': 'secret-token',
          'expires_at': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
          'user': {'id': 7, 'name': 'Edrich Smith', 'email': 'e@example.com'},
        },
        'GET /auth/me': (_, _) => {'id': 7, 'name': 'Edrich Smith', 'email': 'e@example.com'},
        'POST /auth/logout': (_, _) => null,
      });
      container = ProviderContainer(
        overrides: [
          sessionStoreProvider.overrideWithValue(store),
          apiClientProvider.overrideWithValue(api),
          pushProvider.overrideWith((ref) => push = FakePush(ref)),
        ],
      );
      addTearDown(container.dispose);
    });

    test('starts signed out without a stored session', () async {
      expect(await _settled(container), isA<SignedOut>());
      expect(api.calls, isEmpty);
    });

    test('restores a stored session via /auth/me', () async {
      store.stored = AuthSession(token: 't', expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)));
      final state = await _settled(container);
      expect(state, isA<SignedIn>());
      expect((state as SignedIn).user.firstName, 'Edrich');
    });

    test('drops an expired session without calling the API', () async {
      store.stored = AuthSession(token: 't', expiresAt: DateTime.now().toUtc().subtract(const Duration(minutes: 1)));
      expect(await _settled(container), isA<SignedOut>());
      expect(store.stored, isNull);
      expect(api.calls, isEmpty);
    });

    test('login stores the token; logout unregisters push and clears it', () async {
      await _settled(container);
      await container.read(authProvider.notifier).login(email: 'e@example.com', password: 'pw');
      expect(container.read(authProvider), isA<SignedIn>());
      expect(store.stored?.token, 'secret-token');

      await container.read(authProvider.notifier).logout();
      expect(push.unregistered, 1);
      expect(api.calls.last, 'POST /auth/logout');
      expect(store.stored, isNull);
      expect(container.read(authProvider), isA<SignedOut>());
    });
  });

  group('pagedProvider', () {
    test('loads the first page and appends the next without duplicates', () async {
      final api = FakeApi({
        'GET /wines': (query, _) => switch (query?['page']) {
          1 => {
            'data': [
              {'id': 1},
              {'id': 2},
            ],
            'current_page': 1,
            'last_page': 2,
            'total': 3,
          },
          _ => {
            'data': [
              {'id': 2},
              {'id': 3},
            ],
            'current_page': 2,
            'last_page': 2,
            'total': 3,
          },
        },
      });
      final container = ProviderContainer(
        overrides: [apiClientProvider.overrideWithValue(api), authProvider.overrideWith(SignedInAuth.new)],
      );
      addTearDown(container.dispose);
      final query = PageQuery('/wines', const {'q': 'douro', 'empty': ''});
      final sub = container.listen(pagedProvider(query), (_, _) {});
      addTearDown(sub.close);

      final first = await container.read(pagedProvider(query).future);
      expect(first.items.map((i) => i['id']), [1, 2]);
      expect(first.hasMore, isTrue);
      expect(first.remaining, 1);

      await container.read(pagedProvider(query).notifier).loadMore();
      final next = container.read(pagedProvider(query)).value!;
      expect(next.items.map((i) => i['id']), [1, 2, 3]);
      expect(next.hasMore, isFalse);
      expect(api.calls, ['GET /wines', 'GET /wines']);
    });
  });
}
