import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/design/debounced_search.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';
import 'package:nexus_mobile/features/listening/listening.dart';
import 'package:nexus_mobile/features/listening/player.dart';
import 'package:nexus_mobile/features/listening/spotify_api.dart';
import 'package:nexus_mobile/features/listening/spotify_browse.dart';

const _tabs = [('tracks', 'Tracks'), ('artists', 'Artists'), ('albums', 'Albums'), ('playlists', 'Playlists')];

/// Web SpotifySearchView: tracks, artists, albums and playlists from Spotify.
class SpotifySearchScreen extends ConsumerStatefulWidget {
  const SpotifySearchScreen({this.initialQuery, super.key});

  final String? initialQuery;

  @override
  ConsumerState<SpotifySearchScreen> createState() => _SpotifySearchScreenState();
}

class _SpotifySearchScreenState extends ConsumerState<SpotifySearchScreen> with DebouncedSearch {
  String _tab = 'tracks';
  Json? _results;
  bool _loading = false;
  bool _failed = false;
  CancelToken? _cancel;
  String _ran = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery?.trim() case final q? when q.isNotEmpty) {
      searchController.text = q;
      searched = q;
    }
  }

  @override
  void dispose() {
    _cancel?.cancel();
    super.dispose();
  }

  Future<void> _run(String q) async {
    _ran = q;
    _cancel?.cancel();
    if (q.isEmpty) {
      setState(() {
        _results = null;
        _loading = false;
        _failed = false;
      });
      return;
    }
    final token = _cancel = CancelToken();
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final data = await ref.read(spotifyApiProvider).search(q);
      if (token.isCancelled || !mounted) return;
      setState(() {
        _results = data;
        if (data.list(_tab).isEmpty) {
          _tab = _tabs.map((t) => t.$1).firstWhere((k) => data.list(k).isNotEmpty, orElse: () => _tab);
        }
      });
    } on Object {
      if (!token.isCancelled && mounted) setState(() => _failed = true);
    } finally {
      if (!token.isCancelled && mounted) setState(() => _loading = false);
    }
  }

  Future<void> _playlistActions(Json p) => showNxSheet<void>(
    context,
    title: p.text('name'),
    builder: (sheet) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (p.str('uri') case final uri?)
          NxListRow(
            label: 'Play',
            icon: LucideIcons.play,
            onTap: () {
              Navigator.of(sheet).pop();
              ref.read(playerProvider.notifier).playContext(uri);
            },
          ),
        NxListRow(
          label: 'Open playlist',
          icon: LucideIcons.listMusic,
          onTap: () {
            Navigator.of(sheet).pop();
            context.push('/spotify/playlists/${p.text('id')}');
          },
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (searched != _ran) {
      final q = _ran = searched;
      unawaited(Future.microtask(() => _run(q)));
    }
    final r = _results;
    final list = r?.list(_tab) ?? const <Json>[];
    final empty = r != null && _tabs.every((t) => r.list(t.$1).isEmpty);

    return NxPage(
      children: [
        const NxStage(
          compact: true,
          eyebrow: 'Listening',
          title: 'Find',
          accent: 'something new',
          lede: 'Tracks, artists, albums and playlists from Spotify. Play anything straight to your active device.',
        ),
        const SizedBox(height: 22),
        const ListeningNav(value: '/spotify/search'),
        const SizedBox(height: 16),
        if (!spotifyConnected(ref))
          const ConnectSpotifyState(body: 'Search needs Spotify linked.')
        else ...[
          NxSearchField(
            controller: searchController,
            hint: 'Songs, artists, albums…',
            autofocus: widget.initialQuery == null,
            onChanged: onSearchChanged,
            onSubmitted: submitSearch,
          ),
          if (r != null && !empty) ...[
            const SizedBox(height: 14),
            NxPillNav<String>(
              items: [
                for (final (key, label) in _tabs) (key, r.list(key).isEmpty ? label : '$label · ${r.list(key).length}'),
              ],
              value: _tab,
              onChanged: (v) => setState(() => _tab = v),
            ),
          ],
          const SizedBox(height: 16),
          if (_loading && r == null)
            const NxSkeleton(height: 260, radius: NxRadius.lg)
          else if (_failed)
            NxErrorState(error: 'Search failed. Try again.', compact: true, onRetry: () => _run(searched))
          else if (r == null)
            const NxEmptyState(
              compact: true,
              icon: LucideIcons.search,
              title: 'Search Spotify',
              body: 'Type a song, artist or album to start.',
            )
          else if (empty)
            NxEmptyState(compact: true, title: 'Nothing found', body: 'No results for “$searched”.')
          else
            switch (_tab) {
              'tracks' => TrackList(tracks: list),
              'artists' => NxGrid(children: [for (final a in list) ArtistCard(artist: a)]),
              'albums' => NxGrid(children: [for (final a in list) AlbumCard(album: a)]),
              _ => NxGrid(
                children: [
                  for (final p in list)
                    NxCoverCard(
                      title: p.text('name'),
                      subtitle: p.str('owner_name') ?? p.at('owner.display_name') as String?,
                      url: p.str('image_url'),
                      fallbackIcon: LucideIcons.listMusic,
                      onTap: () => _playlistActions(p),
                    ),
                ],
              ),
            },
        ],
      ],
    );
  }
}
