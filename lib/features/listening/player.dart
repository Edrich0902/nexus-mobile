import 'dart:async';

import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_mobile/core/api/api_client.dart';
import 'package:nexus_mobile/core/api/api_error.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/core/auth/auth.dart';
import 'package:nexus_mobile/features/listening/spotify_api.dart';

/// Spotify connection status (`/spotify/status`).
final spotifyStatusProvider = FutureProvider<Json>((ref) async {
  if (ref.watch(authProvider) is! SignedIn) return const {};
  return await ref.watch(spotifyApiProvider).status();
});

class PlayerState {
  const new({
    this.playback,
    this.liked = const {},
    this.busy = false,
    this.featuresStatus = 'idle',
    this.features,
    this.queue,
    this.syncedAt,
  });

  final Json? playback;
  final Map<String, bool> liked;
  final bool busy;
  final String featuresStatus;
  final Json? features;
  final Json? queue;

  /// When [playback] was fetched; anchors the local position clock.
  final DateTime? syncedAt;

  Json? get item => playback?.obj('item');
  bool get isPlaying => playback?.flag('is_playing') ?? false;
  bool get hasTrack => item != null;
  String? get uri => item?.str('uri');
  String? get trackId => item?.str('id');
  String get title => item?.text('name') ?? '';
  String get artists =>
      (item?.list('artists') ?? const []).map((a) => a.text('name')).where((s) => s.isNotEmpty).join(', ');
  String? get art {
    final images = item?.obj('album')?.list('images') ?? const [];
    return images.isEmpty ? null : images.first.str('url');
  }

  int get progressMs => playback?.integer('progress_ms') ?? 0;
  int get durationMs => item?.integer('duration_ms') ?? 0;
  double get progress => durationMs == 0 ? 0 : (progressMs / durationMs).clamp(0, 1);

  /// Playback position at [now], extrapolated from the last poll while playing
  /// (web useSpotifyProgress).
  int positionAt(DateTime now) {
    final at = syncedAt;
    if (!isPlaying || at == null) return progressMs;
    final ms = progressMs + now.difference(at).inMilliseconds;
    return durationMs > 0 ? ms.clamp(0, durationMs) : ms;
  }

  Json? get device => playback?.obj('device');
  String? get deviceId => device?.str('id');
  bool get shuffle => playback?.flag('shuffle_state') ?? false;
  String get repeat => playback?.text('repeat_state', 'off') ?? 'off';
  bool get isLiked => uri != null && (liked[uri] ?? false);

  PlayerState copyWith({
    Json? playback,
    bool clearPlayback = false,
    Map<String, bool>? liked,
    bool? busy,
    String? featuresStatus,
    Json? features,
    bool clearFeatures = false,
    Json? queue,
    DateTime? syncedAt,
  }) => PlayerState(
    playback: clearPlayback ? null : (playback ?? this.playback),
    liked: liked ?? this.liked,
    busy: busy ?? this.busy,
    featuresStatus: featuresStatus ?? this.featuresStatus,
    features: clearFeatures ? null : (features ?? this.features),
    queue: queue ?? this.queue,
    syncedAt: syncedAt ?? this.syncedAt,
  );
}

/// One app-wide player (web spotify.store): polls every 8s while the app is
/// foregrounded and Spotify is connected, backs off to 20s on 429, sends the
/// listening heartbeat (track character) and keeps like-state.
final playerProvider = NotifierProvider<PlayerController, PlayerState>(PlayerController.new);

class PlayerController extends Notifier<PlayerState> {
  static const _pollMs = 8000;
  static const _pollMaxMs = 20000;
  static const _resumeGap = Duration(seconds: 3);
  static const _likedFresh = Duration(minutes: 10);
  static const _likedChunk = 50;

  Timer? _timer;
  int _interval = _pollMs;
  bool _inFlight = false;
  bool _heartbeatInFlight = false;
  bool _foreground = true;
  DateTime? _lastRefreshAt;
  String? _lastHeartbeatId;
  Future<Json?>? _queueLoad;
  final _likedCheckedAt = <String, DateTime>{};
  final _likedInFlight = <String>{};

  /// Optimistic shuffle / repeat until a poll confirms (Spotify lags briefly).
  bool? _expectShuffle;
  String? _expectRepeat;

  /// Surfaces player errors to the shell's toast host.
  final errors = StreamController<String>.broadcast();

  SpotifyApi get _api => ref.read(spotifyApiProvider);

  @override
  PlayerState build() {
    final lifecycle = AppLifecycleListener(onStateChange: _onLifecycle);
    ref
      ..onDispose(() {
        lifecycle.dispose();
        _timer?.cancel();
        unawaited(errors.close());
      })
      ..listen(spotifyStatusProvider, (_, _) => _syncConnection());
    // `state` is unreadable until build returns, so the first sync waits a tick.
    scheduleMicrotask(() {
      if (ref.mounted) _syncConnection();
    });
    return const PlayerState();
  }

  /// Status reloads (pull-to-refresh, reauth checks) must not restart a
  /// running poll, or a failing call would re-fire immediately in a loop.
  void _syncConnection() {
    if (!_connected) return _stop();
    if (_timer == null) _start();
  }

  bool get _connected => ref.read(spotifyStatusProvider).value?.flag('connected') ?? false;

  void _onLifecycle(AppLifecycleState lifecycle) {
    final foreground = lifecycle == AppLifecycleState.resumed;
    if (foreground == _foreground) return;
    _foreground = foreground;
    if (_foreground && _connected) {
      _start();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _start() {
    if (!_foreground) return;
    final last = _lastRefreshAt;
    if (last == null || DateTime.now().difference(last) >= _resumeGap) unawaited(refresh());
    _restartTimer();
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _likedCheckedAt.clear();
    _expectShuffle = null;
    _expectRepeat = null;
    if (state.playback != null) state = state.copyWith(clearPlayback: true);
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(milliseconds: _interval), (_) => refresh());
  }

  Future<void> refresh() async {
    if (_inFlight || !_connected) return;
    if (ref.read(apiClientProvider).rateLimitRemaining > Duration.zero) return;
    _inFlight = true;
    _lastRefreshAt = DateTime.now();
    try {
      final p = await _api.player();
      final prevUri = state.uri;
      state = state.copyWith(playback: _applyPlaybackExpectations(p), syncedAt: DateTime.now());
      if (_interval != _pollMs) {
        _interval = _pollMs;
        _restartTimer();
      }
      if (state.uri != null && state.uri != prevUri) unawaited(_refreshLiked([state.uri!], force: true));
      unawaited(_heartbeat());
    } on Object catch (e) {
      final err = ApiError.from(e, '');
      if (err.isReauth) ref.invalidate(spotifyStatusProvider);
      if (err.isRateLimited) {
        _interval = (_interval * 2).clamp(_pollMs, _pollMaxMs);
        _restartTimer();
      }
    } finally {
      _inFlight = false;
    }
  }

  /// Keep local shuffle/repeat when Spotify's player payload is still stale.
  Json? _applyPlaybackExpectations(Json? p) {
    if (p == null) return null;
    final out = Map<String, dynamic>.from(p);
    final shuffle = _expectShuffle;
    if (shuffle != null) {
      if (out['shuffle_state'] == shuffle) {
        _expectShuffle = null;
      } else {
        out['shuffle_state'] = shuffle;
      }
    }
    final repeat = _expectRepeat;
    if (repeat != null) {
      if (out['repeat_state'] == repeat) {
        _expectRepeat = null;
      } else {
        out['repeat_state'] = repeat;
      }
    }
    return out;
  }

  void _patchPlayback(Map<String, dynamic> patch) {
    final cur = state.playback;
    if (cur == null) return;
    state = state.copyWith(playback: {...cur, ...patch});
  }

  Future<void> _heartbeat() async {
    final item = state.item;
    final id = item?.str('id');
    if (_heartbeatInFlight || id == null || item?.str('type') == 'episode') return;
    if (_lastHeartbeatId != id) {
      _lastHeartbeatId = id;
      state = state.copyWith(featuresStatus: 'idle', clearFeatures: true);
    }
    _heartbeatInFlight = true;
    try {
      final r = await _api.heartbeat({
        'spotify_id': id,
        'progress_ms': state.progressMs,
        'duration_ms': state.durationMs,
        'is_playing': state.isPlaying,
        'name': item!.str('name'),
        'uri': item.str('uri'),
        'album_name': item.at('album.name'),
        'album_image_url': state.art,
        'artists': item['artists'],
      });
      final status = r.text('features_status', 'idle');
      final features = r.obj('features');
      if (status != state.featuresStatus || !mapEquals(features, state.features)) {
        state = state.copyWith(featuresStatus: status, features: features);
      }
    } on Object {
      // Heartbeat is best effort; the poll keeps working.
    } finally {
      _heartbeatInFlight = false;
    }
  }

  /// Liked state for [uris], skipping any checked in the last [_likedFresh]
  /// or already in flight; [force] re-checks (the current track, once per
  /// change, like web).
  Future<void> _refreshLiked(Iterable<String> uris, {bool force = false}) async {
    if (!_connected) return;
    final now = DateTime.now();
    final wanted = <String>{
      for (final u in uris)
        if (u.isNotEmpty &&
            !_likedInFlight.contains(u) &&
            (force || !(_likedCheckedAt[u]?.isAfter(now.subtract(_likedFresh)) ?? false)))
          u,
    }.toList();
    if (wanted.isEmpty) return;
    _likedInFlight.addAll(wanted);
    try {
      for (var i = 0; i < wanted.length; i += _likedChunk) {
        final chunk = wanted.sublist(i, (i + _likedChunk).clamp(0, wanted.length));
        try {
          final r = await _api.libraryContains(chunk);
          if (!ref.mounted) return;
          final checked = DateTime.now();
          Map<String, bool>? next;
          for (var j = 0; j < chunk.length && j < r.length; j++) {
            _likedCheckedAt[chunk[j]] = checked;
            if (state.liked[chunk[j]] != r[j]) (next ??= {...state.liked})[chunk[j]] = r[j];
          }
          if (next != null) state = state.copyWith(liked: next);
        } on Object {
          // best effort; unmarked URIs retry on the next request
        }
      }
    } finally {
      _likedInFlight.removeAll(wanted);
    }
  }

  Future<void> refreshLikedFor(Iterable<String> uris) => _refreshLiked(uris);

  Future<bool> _control(Future<void> Function() action, String fallback) async {
    state = state.copyWith(busy: true);
    try {
      await action();
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await refresh();
      return true;
    } on Object catch (e) {
      final err = ApiError.from(e, fallback);
      if (err.isReauth) ref.invalidate(spotifyStatusProvider);
      errors.add(err.message);
      return false;
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<bool> play([Json payload = const {}]) => _control(() => _api.play(payload), 'Unable to start playback');
  Future<bool> playUri(String uri) => play({
    'uris': [uri],
  });
  Future<bool> playContext(String contextUri, {String? offsetUri}) => play({
    'context_uri': contextUri,
    if (offsetUri != null) 'offset': {'uri': offsetUri},
  });
  Future<bool> pause() => _control(() => _api.pause(state.deviceId), 'Unable to pause');
  Future<bool> toggle() => state.isPlaying ? pause() : play();
  Future<bool> next() => _control(() => _api.next(state.deviceId), 'Unable to skip');
  Future<bool> previous() => _control(() => _api.previous(state.deviceId), 'Unable to go previous');
  Future<bool> seek(int ms) => _control(() => _api.seek(ms, state.deviceId), 'Unable to seek');
  Future<bool> volume(double pct) =>
      _control(() => _api.volume(pct.round().clamp(0, 100), state.deviceId), 'Unable to set volume');
  Future<bool> transfer(String deviceId) => _control(() => _api.transfer(deviceId), 'Unable to transfer playback');
  Future<bool> setShuffle(bool on) async {
    final prev = state.shuffle;
    _expectShuffle = on;
    _patchPlayback({'shuffle_state': on});
    final ok = await _control(() => _api.shuffle(on, state.deviceId), 'Unable to update shuffle');
    if (!ok) {
      _expectShuffle = null;
      _patchPlayback({'shuffle_state': prev});
    }
    return ok;
  }

  Future<bool> cycleRepeat() async {
    final prev = state.repeat;
    final next = switch (prev) {
      'off' => 'context',
      'context' => 'track',
      _ => 'off',
    };
    _expectRepeat = next;
    _patchPlayback({'repeat_state': next});
    final ok = await _control(() => _api.repeat(next, state.deviceId), 'Unable to update repeat');
    if (!ok) {
      _expectRepeat = null;
      _patchPlayback({'repeat_state': prev});
    }
    return ok;
  }

  Future<bool> toggleLike([String? uri]) async {
    final target = uri ?? state.uri;
    if (target == null) return false;
    final was = state.liked[target] ?? false;
    _likedCheckedAt[target] = DateTime.now();
    state = state.copyWith(liked: {...state.liked, target: !was});
    try {
      if (was) {
        await _api.removeLibrary([target]);
      } else {
        await _api.saveLibrary([target]);
      }
      return true;
    } on Object catch (e) {
      state = state.copyWith(liked: {...state.liked, target: was});
      errors.add(ApiError.from(e, 'Unable to update library').message);
      return false;
    }
  }

  Future<bool> queueTrack(String uri) async {
    try {
      await _api.addToQueue(uri, state.deviceId);
      return true;
    } on Object catch (e) {
      errors.add(ApiError.from(e, 'Unable to add to queue').message);
      return false;
    }
  }

  Future<Json?> fetchQueue() => _queueLoad ??= () async {
    try {
      final q = await _api.queue();
      state = state.copyWith(queue: q);
      return q;
    } on Object catch (e) {
      errors.add(ApiError.from(e, 'Unable to load queue').message);
      return null;
    } finally {
      _queueLoad = null;
    }
  }();
}
