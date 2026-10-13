import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:nexus_mobile/core/api/api_client.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/core/auth/auth.dart';

String? _tz;

/// IANA zone (e.g. Africa/Johannesburg); the API rejects abbreviations.
Future<String?> localTimezone() async {
  if (_tz != null) return _tz;
  try {
    return _tz = (await FlutterTimezone.getLocalTimezone()).identifier;
  } on Object {
    return null;
  }
}

final hubApiProvider = Provider<HubApi>((ref) => HubApi(ref.watch(apiClientProvider)));

/// Mirrors web `services/hub.service.ts`.
class HubApi {
  new(this._api);

  final ApiClient _api;

  Future<Json> now() async => asJson(await _api.get('/now', query: {'tz': await localTimezone()}));

  Future<Json> activity({String? cursor, int limit = 30}) async =>
      asJson(await _api.get('/activity', query: {'cursor': cursor, 'limit': limit}));

  Future<List<Json>> search(String q, {CancelToken? cancel}) async =>
      asJson(await _api.get('/search', query: {'q': q}, cancel: cancel)).list('groups');
}

/// Search result type → app path (web `command/search-source.ts`).
String? searchItemPath(Json item) {
  final id = item.str('id');
  return switch (item.str('type')) {
    'cellar_wine' => '/cellar/wines/$id',
    'beer_beer' => '/beer/beers/$id',
    'spirit_spirit' => '/spirits/$id',
    'kitchen_recipe' => '/kitchen/recipes/$id',
    'library_book' => '/library/books/$id',
    'github_repo' => '/github/${item.text('owner')}/${item.text('repo')}',
    'spotify_playlist' => '/spotify/playlists/$id',
    _ => null,
  };
}

/// The single most relevant "moment" (music, race, tonight's bottle, greeting).
final nowProvider = FutureProvider<Json>((ref) async {
  if (ref.watch(authProvider) is! SignedIn) return const {};
  return await ref.watch(hubApiProvider).now();
});
