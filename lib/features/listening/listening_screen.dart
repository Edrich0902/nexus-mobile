import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/core/format.dart';
import 'package:nexus_mobile/design/art_ambient.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';
import 'package:nexus_mobile/features/collections/collection_fields.dart';
import 'package:nexus_mobile/features/home/home_modules.dart';
import 'package:nexus_mobile/features/listening/listening.dart';
import 'package:nexus_mobile/features/listening/player.dart';
import 'package:nexus_mobile/features/listening/player_sheet.dart';
import 'package:nexus_mobile/features/listening/spotify_api.dart';
import 'package:nexus_mobile/features/listening/spotify_playlist.dart';

typedef _Hero = ({bool live, String name, String? uri, String? art, String? album, List<Json> artists, DateTime? when});

/// Listening home (web SpotifyView): the live or last track as the stage,
/// listening fields, recent plays, track character, playlists, on repeat and
/// suggestions.
class ListeningScreen extends ConsumerWidget {
  const ListeningScreen({super.key});

  _Hero? _hero(PlayerState p, List<Json> recent) {
    if (p.item case final item? when item.str('name') != null) {
      return (
        live: true,
        name: item.text('name'),
        uri: item.str('uri'),
        art: p.art,
        album: item.obj('album')?.str('name'),
        artists: item.list('artists').where((a) => a.str('id') != null).toList(),
        when: null,
      );
    }
    final last = recent.map((r) => (r, r.obj('track'))).where((e) => e.$2 != null).firstOrNull;
    if (last == null) return null;
    final (row, track) = (last.$1, last.$2!);
    return (
      live: false,
      name: track.text('name'),
      uri: track.str('uri'),
      art: track.str('album_image_url'),
      album: track.str('album_name'),
      artists: track.list('artists').where((a) => a.str('id') != null).toList(),
      when: DateTime.tryParse(row.text('played_at')),
    );
  }

  Future<void> _refresh(WidgetRef ref) async {
    refreshListening(ref);
    await ref.read(playerProvider.notifier).refresh();
  }

  Future<void> _disconnect(BuildContext context, WidgetRef ref) async {
    final ok = await showNxConfirm(
      context,
      message: 'Disconnect Spotify from Nexus?',
      confirmLabel: 'Disconnect',
      cancelLabel: 'Cancel',
    );
    if (!ok) return;
    try {
      await ref.read(spotifyApiProvider).disconnect();
      refreshListening(ref);
    } on Object catch (e) {
      if (context.mounted) showApiError(context, e, 'Could not disconnect.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(spotifyStatusProvider);
    if (status.isLoading && !status.hasValue) return const NxPageSkeleton();
    if (!(status.value?.flag('connected') ?? false)) {
      return NxPage(
        onRefresh: () async => ref.invalidate(spotifyStatusProvider),
        children: [
          NxStage(
            eyebrow: 'Listening',
            title: 'Bring your',
            accent: 'music in',
            lede:
                'Connect Spotify to control playback from anywhere in Nexus, see what you have been playing and keep your playlists close. Audio stays on Spotify.',
            visual: const SpotifyMark(),
            actions: [NxButton('Connect Spotify', onPressed: () => connectSpotify(context, ref))],
          ),
        ],
      );
    }

    final c = context.nx;
    final player = ref.watch(playerProvider);
    final recentAsync = ref.watch(recentlyPlayedProvider);
    final recent = (recentAsync.value ?? const <Json>[]).where((r) => r.obj('track') != null).take(8).toList();
    final taste = ref.watch(spotifyTasteProvider).value;
    final summary = taste?.obj('summary');
    final playlists = ref.watch(spotifyPlaylistsProvider);
    final suggestions = ref.watch(spotifySuggestionsProvider).value ?? const [];
    final onRepeat = (taste?.list('on_repeat') ?? const []).take(6).toList();
    final genres = (taste?.list('genres') ?? const []).take(8).map((g) => capitalise(g.str('genre'))).toList();
    final hero = _hero(player, recentAsync.value ?? const []);
    final (title, accent) = hero == null ? ('Your', 'listening') : splitTrackTitle(hero.name);
    final device = player.device?.str('name');
    final own = (playlists.value ?? const []).where((p) => p.flag('is_owner')).length;

    return ArtAmbient(
      url: hero?.art,
      child: NxPage(
        onRefresh: () => _refresh(ref),
        children: [
          NxStage(
            live: (hero?.live ?? false) && player.isPlaying,
            eyebrow: hero == null
                ? 'Listening'
                : hero.live
                ? '${player.isPlaying ? 'Now playing' : 'Paused'}${device == null ? '' : ' · $device'}'
                : 'Last played · ${relativeTime(hero.when)}',
            title: title,
            accent: accent,
            progress: (hero?.live ?? false) && player.durationMs > 0 ? player.progress : null,
            visual: hero?.art == null ? Icon(LucideIcons.headphones, size: 48, color: c.ink3) : NxImage(url: hero!.art),
            ledeWidget: hero == null ? null : _ArtistLinks(artists: hero.artists, album: hero.album),
            lede: hero == null ? 'Nothing has played yet. Start something on Spotify and it shows up here.' : null,
            actions: [
              if (hero != null)
                NxButton(
                  hero.live ? (player.isPlaying ? 'Pause' : 'Resume') : 'Play again',
                  icon: hero.live && player.isPlaying ? LucideIcons.pause : LucideIcons.play,
                  onPressed: player.busy
                      ? null
                      : () {
                          final ctl = ref.read(playerProvider.notifier);
                          if (hero.live) {
                            unawaited(ctl.toggle());
                          } else if (hero.uri case final uri?) {
                            unawaited(ctl.playUri(uri));
                          }
                        },
                ),
              NxButton(
                'Queue',
                icon: LucideIcons.listMusic,
                variant: NxButtonVariant.secondary,
                onPressed: () => showQueueSheet(context),
              ),
              if (hero?.uri case final uri?)
                NxIconButton(
                  LucideIcons.plus,
                  tooltip: 'Add to playlist',
                  filled: true,
                  onPressed: () => showAddToPlaylistSheet(context, uri),
                ),
            ],
          ),
          const SizedBox(height: 22),
          CollectionFields(
            section: SectionKey.listening,
            fields: [
              CollectionField(
                key: 'plays',
                label: 'Plays this week',
                value: summary?.integer('plays_last_7d')?.toString() ?? '—',
                sub: summary == null
                    ? 'Sync to count your plays'
                    : plural(summary.integer('unique_tracks_last_7d') ?? 0, 'different track'),
                span: 2,
              ),
              if (summary?.str('top_genre') case final genre?)
                CollectionField(
                  key: 'genre',
                  label: 'Top genre',
                  title: capitalise(genre),
                  variant: FieldVariant.tint,
                  to: '/spotify/stats',
                )
              else
                const CollectionField(
                  key: 'genre',
                  label: 'Top genre',
                  title: 'After a sync',
                  variant: FieldVariant.outline,
                ),
              CollectionField(
                key: 'peak',
                label: 'You listen most',
                title: capitalise(summary?.str('peak_bucket')).ifBlank('—'),
                variant: summary?.str('peak_bucket') == null ? FieldVariant.outline : FieldVariant.tint,
              ),
              CollectionField(
                key: 'playlists',
                label: 'Playlists',
                value: '${playlists.value?.length ?? '—'}',
                sub: own > 0 ? '$own made by you' : null,
                variant: FieldVariant.outline,
                span: 2,
              ),
            ],
          ),
          const SizedBox(height: 22),
          ListeningNav(
            value: '/spotify',
            trailing: [
              NxIconButton(
                LucideIcons.refreshCw,
                tooltip: 'Sync with Spotify',
                onPressed: () => syncSpotify(context, ref),
              ),
              NxIconButton(LucideIcons.unplug, tooltip: 'Disconnect', onPressed: () => _disconnect(context, ref)),
            ],
          ),
          if (status.value?.flag('needs_reauth') ?? false) ...[
            const SizedBox(height: 18),
            NxPanel(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      [
                        'Spotify needs re-authorising',
                        if (status.value!.strings('missing_scopes') case final s when s.isNotEmpty)
                          '(missing ${s.join(', ')})',
                      ].join(' '),
                      style: NxText.sans(size: 13.5, color: c.ink2),
                    ),
                  ),
                  NxButton('Reconnect', compact: true, onPressed: () => connectSpotify(context, ref)),
                ],
              ),
            ),
          ],
          NxSectionHeader(
            'Recently played',
            actionLabel: 'Your stats',
            onAction: () => context.go('/spotify/stats'),
          ),
          if (recentAsync.isLoading && recent.isEmpty)
            const NxSkeleton(height: 200, radius: NxRadius.lg)
          else if (recent.isEmpty)
            Text('No recent plays yet. Listen on Spotify, then sync.', style: NxText.muted(context, size: 14))
          else
            TrackList(
              tracks: [for (final r in recent) r.obj('track')!],
              meta: (i, _) => relativeTime(DateTime.tryParse(recent[i].text('played_at'))),
            ),
          if (player.hasTrack) ...[
            const NxSectionHeader('Track character'),
            NxPanel(child: TrackCharacter(player: player)),
          ],
          if (player.similar.isNotEmpty) ...[
            const NxSectionHeader('Similar to this'),
            TrackList(
              tracks: [for (final s in player.similar.take(6)) s.obj('track') ?? const {}],
              meta: (i, _) => player.similar[i].str('reason'),
            ),
          ],
          NxSectionHeader(
            'Playlists',
            actionLabel: 'New playlist',
            onAction: () async {
              final created = await showPlaylistSheet(context);
              if (created?.str('id') case final id? when context.mounted) {
                unawaited(context.push('/spotify/playlists/$id'));
              }
            },
          ),
          if (playlists.isLoading && !playlists.hasValue)
            const NxSkeleton(height: 180, radius: NxRadius.lg)
          else if (playlists.value?.isEmpty ?? true)
            Text('No playlists synced yet.', style: NxText.muted(context, size: 14))
          else
            NxGrid(
              children: [
                for (final p in playlists.value!)
                  NxCoverCard(
                    title: p.text('name'),
                    subtitle: plural(p.integer('item_count') ?? 0, 'track'),
                    url: p.str('image_url'),
                    fallbackIcon: LucideIcons.listMusic,
                    onTap: () => context.push('/spotify/playlists/${p.text('id')}'),
                  ),
              ],
            ),
          const NxSectionHeader('On repeat'),
          if (onRepeat.isEmpty)
            Text(
              'Play a track a few times this week and it lands here.',
              style: NxText.muted(context, size: 14),
            )
          else
            TrackList(
              tracks: [for (final r in onRepeat) r.obj('track') ?? const {}],
              numbered: true,
              meta: (i, _) => plural(onRepeat[i].integer('play_count') ?? 0, 'play'),
            ),
          const NxSectionHeader('For you'),
          if (genres.isNotEmpty) ...[
            NxChipRow(children: [for (final g in genres) NxChip(g)]),
            const SizedBox(height: 12),
          ],
          if (suggestions.isEmpty)
            Text('Suggestions appear once recent and top tracks sync.', style: NxText.muted(context, size: 14))
          else
            TrackList(
              tracks: [for (final s in suggestions.take(6)) s.obj('track') ?? const {}],
              meta: (i, _) => suggestions[i].str('reason'),
            ),
        ],
      ),
    );
  }
}

extension on String {
  String ifBlank(String fallback) => isEmpty ? fallback : this;
}

class _ArtistLinks extends StatelessWidget {
  const _ArtistLinks({required this.artists, this.album});

  final List<Json> artists;
  final String? album;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    final style = NxText.sans(size: 15.5, color: c.ink2, height: 1.45);
    return Wrap(
      children: [
        for (var i = 0; i < artists.length; i++)
          GestureDetector(
            onTap: () => context.push('/spotify/artists/${artists[i].text('id')}'),
            child: Text(
              '${artists[i].text('name')}${i < artists.length - 1 ? ', ' : ''}',
              style: style.copyWith(decoration: TextDecoration.underline, decorationColor: c.line),
            ),
          ),
        if (album != null) Text(' · $album', style: style),
      ],
    );
  }
}

const _keys = ['C', 'C♯', 'D', 'D♯', 'E', 'F', 'F♯', 'G', 'G♯', 'A', 'A♯', 'B'];

/// Tempo, key and audio meters for the playing track (web NexusSpotifyTrackMetrics).
class TrackCharacter extends StatelessWidget {
  const TrackCharacter({required this.player, super.key});

  final PlayerState player;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    final f = player.features;
    final meters = audioMeters(f);
    if (player.featuresStatus == 'loading' || (player.featuresStatus == 'idle' && player.hasTrack)) {
      return const NxSkeleton(height: 120, radius: NxRadius.md);
    }
    if (player.featuresStatus != 'ready' || meters.isEmpty) {
      return Text('No acoustic profile for this track yet.', style: NxText.muted(context, size: 14));
    }
    final tempo = f?.number('tempo')?.round();
    final key = f?.integer('key');
    final mode = switch (f?.integer('mode')) {
      1 => ' major',
      0 => ' minor',
      _ => '',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tempo != null || (key != null && key >= 0))
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                if (tempo != null) ...[
                  Text('$tempo', style: NxText.serif(color: c.ink)),
                  const SizedBox(width: 6),
                  Text('bpm', style: NxText.sans(size: 13, color: c.ink3)),
                  const SizedBox(width: 28),
                ],
                if (key != null && key >= 0 && key < _keys.length)
                  Text('${_keys[key]}$mode', style: NxText.serif(size: 30, color: c.ink)),
              ],
            ),
          ),
        NxMeters(meters, labelWidth: 90, showWords: true),
      ],
    );
  }
}
