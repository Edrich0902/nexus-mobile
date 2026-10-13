import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/core/format.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';
import 'package:nexus_mobile/features/listening/listening.dart';
import 'package:nexus_mobile/features/listening/player.dart';
import 'package:nexus_mobile/features/listening/spotify_api.dart';
import 'package:nexus_mobile/features/listening/spotify_browse.dart';

/// Web SpotifyLibraryView: liked songs, saved albums and followed artists,
/// 30 at a time.
class SpotifyLibraryScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<SpotifyLibraryScreen> createState() => _SpotifyLibraryScreenState();
}

class _SpotifyLibraryScreenState extends ConsumerState<SpotifyLibraryScreen> {
  static const _page = 30;

  String _tab = 'tracks';
  bool _loading = false;
  bool _failed = false;
  int _generation = 0;

  List<Json> _tracks = const [];
  List<Json> _albums = const [];
  List<Json> _artists = const [];
  int? _tracksTotal;
  int? _albumsTotal;
  String? _artistsAfter;
  bool _artistsHasNext = false;

  bool get _missingFollowScope =>
      (ref.read(spotifyStatusProvider).value?.strings('missing_scopes') ?? const []).contains('user-follow-read');

  @override
  void initState() {
    super.initState();
    unawaited(_load(reset: true));
  }

  Future<void> _load({required bool reset}) async {
    final generation = ++_generation;
    final tab = _tab;
    final api = ref.read(spotifyApiProvider);
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      switch (tab) {
        case 'tracks':
          final data = await api.libraryTracks(limit: _page, offset: reset ? 0 : _tracks.length);
          if (generation != _generation) return;
          final page = [for (final i in data.list('items')) ?i.obj('track')];
          setState(() {
            _tracks = reset ? page : [..._tracks, ...page];
            _tracksTotal = data.integer('total');
          });
        case 'albums':
          final data = await api.libraryAlbums(limit: _page, offset: reset ? 0 : _albums.length);
          if (generation != _generation) return;
          final page = [for (final i in data.list('items')) ?i.obj('album')];
          setState(() {
            _albums = reset ? page : [..._albums, ...page];
            _albumsTotal = data.integer('total');
          });
        default:
          if (_missingFollowScope) return;
          final data = await api.libraryArtists(limit: _page, after: reset ? null : _artistsAfter);
          if (generation != _generation) return;
          setState(() {
            _artists = reset ? data.list('artists') : [..._artists, ...data.list('artists')];
            _artistsHasNext = data.flag('next');
            _artistsAfter = data.obj('cursors')?.str('after');
          });
      }
    } on Object {
      if (generation == _generation && mounted) setState(() => _failed = true);
    } finally {
      if (generation == _generation && mounted) setState(() => _loading = false);
    }
  }

  bool get _canLoadMore => switch (_tab) {
    'tracks' => _tracks.length < (_tracksTotal ?? 0),
    'albums' => _albums.length < (_albumsTotal ?? 0),
    _ => _artistsHasNext && !_missingFollowScope,
  };

  int get _count => switch (_tab) {
    'tracks' => _tracks.length,
    'albums' => _albums.length,
    _ => _artists.length,
  };

  @override
  Widget build(BuildContext context) {
    final connected = spotifyConnected(ref);
    return NxPage(
      onRefresh: () => _load(reset: true),
      children: [
        NxStage(
          compact: true,
          eyebrow: 'Listening',
          title: 'Your',
          accent: 'library',
          lede: _tracksTotal == null
              ? 'Liked songs, the albums you saved and the artists you follow.'
              : '${compactNumber(_tracksTotal!)} liked songs, the albums you saved and the artists you follow.',
        ),
        const SizedBox(height: 22),
        const ListeningNav(value: '/spotify/library'),
        const SizedBox(height: 16),
        if (!connected)
          const ConnectSpotifyState()
        else ...[
          NxPillNav<String>(
            items: [
              ('tracks', _tracksTotal == null ? 'Liked songs' : 'Liked songs · $_tracksTotal'),
              ('albums', _albumsTotal == null ? 'Albums' : 'Albums · $_albumsTotal'),
              ('artists', 'Artists'),
            ],
            value: _tab,
            onChanged: (v) {
              if (v == _tab) return;
              setState(() => _tab = v);
              unawaited(_load(reset: true));
            },
          ),
          const SizedBox(height: 16),
          if (_tab == 'artists' && _missingFollowScope)
            NxEmptyState(
              compact: true,
              title: 'Reconnect to see artists',
              body: 'Spotify needs permission to read who you follow.',
              actionLabel: 'Reconnect',
              onAction: () => connectSpotify(context, ref),
            )
          else if (_loading && _count == 0)
            const NxSkeleton(height: 280, radius: NxRadius.lg)
          else if (_failed && _count == 0)
            NxErrorState(error: 'Could not load your library.', compact: true, onRetry: () => _load(reset: true))
          else if (_count == 0)
            NxEmptyState(
              compact: true,
              title: switch (_tab) {
                'tracks' => 'No liked songs',
                'albums' => 'No saved albums',
                _ => 'Not following anyone yet',
              },
            )
          else ...[
            switch (_tab) {
              'tracks' => TrackList(tracks: _tracks),
              'albums' => NxGrid(children: [for (final a in _albums) AlbumCard(album: a)]),
              _ => NxGrid(children: [for (final a in _artists) ArtistCard(artist: a)]),
            },
            if (_canLoadMore)
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Center(
                  child: NxButton(
                    'Show more',
                    variant: NxButtonVariant.secondary,
                    loading: _loading,
                    onPressed: _loading ? null : () => _load(reset: false),
                  ),
                ),
              ),
          ],
        ],
      ],
    );
  }
}
