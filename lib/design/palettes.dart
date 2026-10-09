import 'dart:async';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_mobile/core/api/api_client.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/design/ambient_palette.dart';

/// Session-wide artwork palette cache (web `usePalettes`): one batched
/// `POST /palettes` per page of artwork, retrying URLs the API is still
/// extracting with backoff.
final paletteCacheProvider = NotifierProvider<PaletteCache, Map<String, Json>>(PaletteCache.new);

class PaletteCache extends Notifier<Map<String, Json>> {
  static const _batch = 60;
  static const _maxTries = 5;
  final _tries = <String, int>{};
  Timer? _timer;

  @override
  Map<String, Json> build() {
    ref.onDispose(() => _timer?.cancel());
    return const {};
  }

  Json? of(String? url) => url == null ? null : state[url];

  void want(Iterable<String?> urls) {
    final missing = _missing(urls);
    if (missing.isNotEmpty) unawaited(_fetch(missing, urls.toList()));
  }

  List<String> _missing(Iterable<String?> urls) => {
    for (final u in urls)
      if (u != null && u.startsWith('https://') && !state.containsKey(u) && (_tries[u] ?? 0) < _maxTries) u,
  }.toList();

  Future<void> _fetch(List<String> missing, List<String?> all) async {
    _timer?.cancel();
    final api = ref.read(apiClientProvider);
    for (var i = 0; i < missing.length; i += _batch) {
      final chunk = missing.sublist(i, i + _batch > missing.length ? missing.length : i + _batch);
      for (final u in chunk) {
        _tries[u] = (_tries[u] ?? 0) + 1;
      }
      try {
        final res = asJson(await api.post('/palettes', data: {'urls': chunk}));
        final got = res.obj('palettes') ?? {};
        if (got.isNotEmpty) {
          state = {...state, for (final e in got.entries) e.key: asJson(e.value)};
        }
      } on Object {
        for (final u in chunk) {
          _tries[u] = _maxTries;
        }
      }
    }
    final left = _missing(all);
    if (left.isNotEmpty) {
      final attempt = left.map((u) => _tries[u] ?? 1).reduce((a, b) => a < b ? a : b);
      _timer = Timer(Duration(milliseconds: 2000 * (1 << (attempt - 1))), () => want(all));
    }
  }
}

/// Single palette lookup (`GET /palette?url=`), for stage artwork.
final paletteProvider = FutureProvider.family<Json?, String>((ref, url) async {
  if (!url.startsWith('https://')) return null;
  try {
    final json = asJson(await ref.read(apiClientProvider).get('/palette', query: {'url': url}));
    return json.obj('palette') ?? (json.containsKey('dominant') ? json : null);
  } on Object {
    return null;
  }
});

/// Ambient for a palette payload (`{dominant, vibrant, light, …}`).
Ambient? ambientFromJson(Json? palette) {
  if (palette == null) return null;
  final dominant = parseHex(palette.str('dominant'));
  if (dominant == null) return null;
  return ambientFromPalette(
    dominant: dominant,
    vibrant: parseHex(palette.str('vibrant')) ?? dominant,
    light: parseHex(palette.str('light')) ?? const Color(0xFFF6EFE9),
  );
}

/// Ambient for a piece of artwork; null until the palette is ready.
final artAmbientProvider = Provider.family<Ambient?, String?>((ref, url) {
  if (url == null) return null;
  return ambientFromJson(ref.watch(paletteProvider(url)).value);
});
