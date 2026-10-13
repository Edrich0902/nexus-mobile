import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/core/integrations/oauth_connect.dart';
import 'package:nexus_mobile/design/profile.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';
import 'package:nexus_mobile/features/home/home_modules.dart';
import 'package:nexus_mobile/features/listening/player.dart';
import 'package:nexus_mobile/features/listening/player_sheet.dart';
import 'package:nexus_mobile/features/listening/spotify_api.dart';

// ── Helpers (web routes/spotify/listening.ts) ───────────────────────────────

/// "Time (You and I)" → ("Time", "(You and I)"); "Heroes - 2017 Remaster" →
/// ("Heroes", "2017 Remaster").
(String, String?) splitTrackTitle(String name) {
  final paren = RegExp(r'^(.+?)\s*([(\[][^)\]]+[)\]])\s*$').firstMatch(name);
  if (paren != null) return (paren[1]!, paren[2]);
  final dash = RegExp(r'^(.+?)\s+[-–]\s+(.+)$').firstMatch(name);
  if (dash != null) return (dash[1]!, dash[2]);
  return (name, null);
}

String artistNames(Json track) {
  final names = track.list('artists').map((a) => a.text('name')).where((s) => s.isNotEmpty).join(', ');
  return names.isEmpty ? 'Unknown artist' : names;
}

String formatDuration(int ms) {
  final total = ms ~/ 1000;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  return h > 0 ? '$h hr $m min' : '$m min';
}

String totalDuration(Iterable<Json> tracks) =>
    formatDuration(tracks.fold(0, (sum, t) => sum + (t.integer('duration_ms') ?? 0)));

String? releaseYear(String? date) => date == null || date.length < 4 ? null : date.substring(0, 4);

String capitalise(String? value) =>
    value == null || value.isEmpty ? '' : '${value[0].toUpperCase()}${value.substring(1)}';

/// Spotify descriptions arrive HTML-escaped and may contain links.
String plainText(String? html) {
  if (html == null) return '';
  return html
      .replaceAll(RegExp('<[^>]*>'), '')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#x27;', "'")
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&nbsp;', ' ')
      .trim();
}

const _audioTraits = [
  ('energy', 'Energy'),
  ('danceability', 'Dance'),
  ('valence', 'Mood'),
  ('acousticness', 'Acoustic'),
  ('instrumentalness', 'Instrumental'),
  ('speechiness', 'Spoken'),
];

/// 0–1 audio features (one track or an average) as meter rows.
List<ProfileAxis> audioMeters(Json? source) => [
  if (source != null)
    for (final (key, label) in _audioTraits)
      if (source.number(key) case final v?) ProfileAxis(label, v.clamp(0, 1).toDouble(), '${(v * 100).round()}%'),
];

String? largestImage(Json? json, [String key = 'images']) {
  final images = json?.list(key) ?? const [];
  return images.isEmpty ? null : images.first.str('url');
}

// ── Data ───────────────────────────────────────────────────────────────────

bool spotifyConnected(WidgetRef ref) => ref.watch(spotifyStatusProvider).value?.flag('connected') ?? false;

final recentlyPlayedProvider = FutureProvider.autoDispose<List<Json>>(
  (ref) => ref.watch(spotifyApiProvider).recentlyPlayed(),
);

final spotifyPlaylistsProvider = FutureProvider.autoDispose<List<Json>>(
  (ref) => ref.watch(spotifyApiProvider).playlists(),
);

final spotifySuggestionsProvider = FutureProvider.autoDispose<List<Json>>((ref) async {
  try {
    return await ref.watch(spotifyApiProvider).suggestions();
  } on Object {
    return const [];
  }
});

typedef ArtistPage = ({Json artist, List<Json> topTracks, List<Json> albums, String? note});

final artistProvider = FutureProvider.autoDispose.family<ArtistPage, String>((ref, id) async {
  final api = ref.watch(spotifyApiProvider);
  final (detail, tops, albums) = await (api.artist(id), api.artistTopTracks(id), api.artistAlbums(id)).wait;
  return (
    artist: detail,
    topTracks: tops.list('tracks'),
    albums: albums.list('albums'),
    note: detail.str('message') ?? tops.str('message') ?? albums.str('message'),
  );
});

final albumProvider = FutureProvider.autoDispose.family<Json, String>(
  (ref, id) => ref.watch(spotifyApiProvider).album(id),
);

final playlistProvider = FutureProvider.autoDispose.family<Json, String>(
  (ref, id) => ref.watch(spotifyApiProvider).playlist(id),
);

/// Every Spotify-backed view refreshes together after connect / sync.
void refreshListening(WidgetRef ref) => ref
  ..invalidate(spotifyStatusProvider)
  ..invalidate(spotifyTasteProvider)
  ..invalidate(recentlyPlayedProvider)
  ..invalidate(spotifyPlaylistsProvider)
  ..invalidate(spotifySuggestionsProvider);

Future<void> connectSpotify(BuildContext context, WidgetRef ref) async {
  final api = ref.read(spotifyApiProvider);
  final ok = await connectWithOAuth(
    context,
    provider: 'spotify',
    authorizationUrl: (returnTo) => api.connectUrl(returnTo: returnTo),
  );
  if (!ok) return;
  refreshListening(ref);
  if (context.mounted) showNxToast(context, 'Spotify connected. Your listening syncs in the background.');
}

Future<void> syncSpotify(BuildContext context, WidgetRef ref) async {
  try {
    final message = await ref.read(spotifyApiProvider).sync();
    if (context.mounted) showNxToast(context, message);
  } on Object catch (e) {
    if (context.mounted) showApiError(context, e, 'Could not start a sync.');
  }
}

// ── Shared widgets ─────────────────────────────────────────────────────────

/// Now / Search / Library / Stats as one full-width segmented control (web
/// ListeningNav). The Now stage carries its own queue button, so the queue
/// shortcut sits beside the nav on the other pages only.
class ListeningNav extends StatelessWidget {
  const new({required this.value, super.key});

  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: NxPillNav<String>(
          expand: true,
          items: const [
            ('/spotify', 'Now'),
            ('/spotify/search', 'Search'),
            ('/spotify/library', 'Library'),
            ('/spotify/stats', 'Stats'),
          ],
          value: value,
          onChanged: (to) => to == value ? null : context.go(to),
        ),
      ),
      if (value != '/spotify') ...[
        const SizedBox(width: 6),
        NxIconButton(LucideIcons.listMusic, tooltip: 'Queue', onPressed: () => showQueueSheet(context)),
      ],
    ],
  );
}

/// Shown on any listening page while Spotify isn't linked.
class ConnectSpotifyState extends ConsumerWidget {
  const new({this.title = 'Connect Spotify first', this.body, super.key});

  final String title;
  final String? body;

  @override
  Widget build(BuildContext context, WidgetRef ref) => NxEmptyState(
    icon: LucideIcons.headphones,
    title: title,
    body: body ?? 'Link Spotify to control playback, see what you have been playing and keep your playlists close.',
    actionLabel: 'Connect Spotify',
    onAction: () => connectSpotify(context, ref),
  );
}

/// Spotify-green mark for the not-connected stage.
class SpotifyMark extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: RadialGradient(
        center: const Alignment(-.4, -.5),
        colors: [NxAccents.spotify.withValues(alpha: .22), Colors.transparent],
      ),
    ),
    child: const Center(child: Icon(LucideIcons.audioLines, size: 64, color: NxAccents.spotify)),
  );
}

/// Track rows with liked-state refreshed for whatever is on screen.
class TrackList extends ConsumerStatefulWidget {
  const new({
    required this.tracks,
    this.meta,
    this.reason,
    this.numbered = false,
    this.contextUri,
    this.trailing,
    super.key,
  });

  final List<Json> tracks;
  final String? Function(int index, Json track)? meta;
  final String? Function(Json track)? reason;
  final bool numbered;
  final String? contextUri;
  final Widget? Function(int index, Json track)? trailing;

  @override
  ConsumerState<TrackList> createState() => _TrackListState();
}

class _TrackListState extends ConsumerState<TrackList> {
  var _uris = const <String>[];

  @override
  void initState() {
    super.initState();
    _refreshLiked();
  }

  @override
  void didUpdateWidget(TrackList old) {
    super.didUpdateWidget(old);
    _refreshLiked();
  }

  /// Parents rebuild these lists on every player poll, so only a change in
  /// the actual tracks may reach the API.
  void _refreshLiked() {
    final uris = widget.tracks.map((t) => t.str('uri')).nonNulls.toList();
    if (listEquals(uris, _uris)) return;
    _uris = uris;
    if (uris.isNotEmpty) unawaited(Future.microtask(() => ref.read(playerProvider.notifier).refreshLikedFor(uris)));
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var i = 0; i < widget.tracks.length; i++)
        TrackRow(
          track: widget.tracks[i],
          index: widget.numbered ? i : null,
          reason: widget.reason?.call(widget.tracks[i]) ?? widget.meta?.call(i, widget.tracks[i]),
          contextUri: widget.contextUri,
          trailing: widget.trailing?.call(i, widget.tracks[i]),
        ),
    ],
  );
}
