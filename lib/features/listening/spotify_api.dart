import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_mobile/core/api/api_client.dart';
import 'package:nexus_mobile/core/api/json.dart';

final spotifyApiProvider = Provider<SpotifyApi>((ref) => SpotifyApi(ref.watch(apiClientProvider)));

/// Mirrors web `services/spotify.service.ts`.
class SpotifyApi {
  SpotifyApi(this._api);

  final ApiClient _api;
  static const _b = '/spotify';

  Map<String, dynamic>? _dev(String? id) => id == null ? null : {'device_id': id};

  Future<String> connectUrl({String? returnTo}) async =>
      asJson(await _api.get('$_b/connect', query: {'return_to': returnTo})).text('url');
  Future<Json> status() async => asJson(await _api.get('$_b/status'));
  Future<void> disconnect() => _api.post('$_b/disconnect');
  Future<String> sync() async => asJson(await _api.post('$_b/sync')).text('message', 'Sync queued');

  Future<Json> player() async => asJson(await _api.get('$_b/player'));
  Future<List<Json>> devices() async => asJson(await _api.get('$_b/player/devices')).list('devices');
  Future<void> transfer(String deviceId, {bool play = true}) => _api.put(
    '$_b/player',
    data: {
      'device_ids': [deviceId],
      'play': play,
    },
  );
  Future<void> play([Json payload = const {}]) => _api.put('$_b/player/play', data: payload);
  Future<void> pause([String? deviceId]) =>
      _api.dio.put<dynamic>('$_b/player/pause', data: {}, queryParameters: _dev(deviceId));
  Future<void> next([String? deviceId]) => _api.post('$_b/player/next', data: {}, query: _dev(deviceId));
  Future<void> previous([String? deviceId]) => _api.post('$_b/player/previous', data: {}, query: _dev(deviceId));
  Future<void> seek(int ms, [String? deviceId]) =>
      _api.put('$_b/player/seek', data: {'position_ms': ms, ...?_dev(deviceId)});
  Future<void> volume(int pct, [String? deviceId]) =>
      _api.put('$_b/player/volume', data: {'volume_percent': pct, ...?_dev(deviceId)});
  Future<void> shuffle(bool state, [String? deviceId]) =>
      _api.put('$_b/player/shuffle', data: {'state': state, ...?_dev(deviceId)});
  Future<void> repeat(String state, [String? deviceId]) =>
      _api.put('$_b/player/repeat', data: {'state': state, ...?_dev(deviceId)});
  Future<Json> queue() async => asJson(await _api.get('$_b/player/queue'));
  Future<void> addToQueue(String uri, [String? deviceId]) =>
      _api.post('$_b/player/queue', data: {'uri': uri, ...?_dev(deviceId)});

  Future<Json> search(String q, {String type = 'track,artist,album,playlist', int limit = 10}) async =>
      asJson(await _api.get('$_b/search', query: {'q': q, 'type': type, 'limit': limit}));
  Future<Json> artist(String id) async => asJson(await _api.get('$_b/artists/$id'));
  Future<Json> artistTopTracks(String id) async => asJson(await _api.get('$_b/artists/$id/top-tracks'));
  Future<Json> artistAlbums(String id, {int limit = 20}) async =>
      asJson(await _api.get('$_b/artists/$id/albums', query: {'limit': limit}));
  Future<Json> album(String id) async => asJson(await _api.get('$_b/albums/$id'));

  Future<Json> libraryTracks({int limit = 20, int offset = 0}) async =>
      asJson(await _api.get('$_b/library/tracks', query: {'limit': limit, 'offset': offset}));
  Future<Json> libraryAlbums({int limit = 20, int offset = 0}) async =>
      asJson(await _api.get('$_b/library/albums', query: {'limit': limit, 'offset': offset}));
  Future<Json> libraryArtists({int limit = 20, String? after}) async =>
      asJson(await _api.get('$_b/library/artists', query: {'limit': limit, 'after': after}));
  Future<void> saveLibrary(List<String> uris) => _api.put('$_b/library', data: {'uris': uris});
  Future<void> removeLibrary(List<String> uris) => _api.delete('$_b/library', data: {'uris': uris});
  Future<List<bool>> libraryContains(List<String> uris) async {
    final r = asJson(await _api.get('$_b/library/contains', query: {'uris': uris.join(',')}));
    return (r['contains'] as List? ?? const []).map((e) => e == true).toList();
  }

  Future<List<Json>> playlists({int perPage = 50}) async =>
      asJsonList(await _api.get('$_b/playlists', query: {'per_page': perPage}));
  Future<List<String>> playlistsContaining(String uri) async =>
      asJson(await _api.get('$_b/playlists/containing', query: {'uri': uri})).strings('playlist_ids');
  Future<Json> playlist(String id, {bool refresh = false}) async =>
      asJson(await _api.get('$_b/playlists/$id', query: refresh ? {'refresh': 1} : null));
  Future<Json> createPlaylist(Json payload) async => asJson(await _api.post('$_b/playlists', data: payload));
  Future<Json> updatePlaylist(String id, Json payload) async =>
      asJson(await _api.put('$_b/playlists/$id', data: payload));
  Future<void> deletePlaylist(String id) => _api.delete('$_b/playlists/$id');
  Future<void> addPlaylistItems(String id, List<String> uris) =>
      _api.post('$_b/playlists/$id/items', data: {'uris': uris});

  /// Removes the given occurrences; a position pins one copy when a track appears twice.
  Future<void> removePlaylistItems(String id, List<({String uri, int? position})> items) => _api.delete(
    '$_b/playlists/$id/items',
    data: {
      'items': [
        for (final i in items)
          {
            'uri': i.uri,
            'positions': ?(i.position == null ? null : [i.position]),
          },
      ],
    },
  );

  Future<List<Json>> recentlyPlayed({int perPage = 24}) async =>
      asJsonList(await _api.get('$_b/recently-played', query: {'per_page': perPage}));
  Future<List<Json>> top(String type, {String range = 'medium_term'}) async =>
      asJsonList(await _api.get('$_b/top/$type', query: {'time_range': range}));
  Future<Json> taste() async => asJson(await _api.get('$_b/taste'));
  Future<List<Json>> suggestions() async => asJson(await _api.get('$_b/suggestions')).list('items');
  Future<Json> heartbeat(Json payload) async => asJson(await _api.post('$_b/listening/heartbeat', data: payload));
  Future<Json> listeningProfile() async => asJson(await _api.get('$_b/listening/profile'));
}
