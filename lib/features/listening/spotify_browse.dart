import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/core/format.dart';
import 'package:nexus_mobile/design/art_ambient.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';
import 'package:nexus_mobile/features/listening/listening.dart';
import 'package:nexus_mobile/features/listening/player.dart';

/// Album / single cover that opens the album page.
class AlbumCard extends StatelessWidget {
  const new({required this.album, super.key});

  final Json album;

  @override
  Widget build(BuildContext context) => NxCoverCard(
    title: album.text('name'),
    subtitle: [
      releaseYear(album.str('release_date')),
      if (album.list('artists').isNotEmpty) artistNames(album),
    ].nonNulls.join(' · '),
    url: album.str('image_url') ?? largestImage(album),
    fallbackIcon: LucideIcons.discAlbum,
    onTap: () => context.push('/spotify/albums/${album.text('id')}'),
  );
}

/// Artist portrait that opens the artist page.
class ArtistCard extends StatelessWidget {
  const new({required this.artist, super.key});

  final Json artist;

  @override
  Widget build(BuildContext context) => NxCoverCard(
    title: artist.text('name'),
    subtitle: capitalise(artist.strings('genres').firstOrNull),
    url: largestImage(artist),
    circle: true,
    fallbackIcon: LucideIcons.micVocal,
    onTap: () => context.push('/spotify/artists/${artist.text('id')}'),
  );
}

/// Web SpotifyArtistView: portrait stage, popular tracks, albums and singles.
class ArtistScreen extends ConsumerWidget {
  const new({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) => NxAsync(
    value: ref.watch(artistProvider(id)),
    onRetry: () => ref.invalidate(artistProvider(id)),
    data: (page) {
      final c = context.nx;
      final artist = page.artist;
      final image = largestImage(artist);
      final followers = artist.integer('followers');
      final genres = artist.strings('genres').take(6).map(capitalise).toList();
      final main = page.albums.where((a) => !{'single', 'compilation'}.contains(a.str('album_type'))).toList();
      final singles = page.albums.where((a) => a.str('album_type') == 'single').toList();
      return ArtAmbient(
        url: image,
        child: NxPage(
          onRefresh: () async => ref.invalidate(artistProvider(id)),
          children: [
            NxStage(
              eyebrow: followers == null ? 'Artist' : 'Artist · ${compactNumber(followers)} followers',
              title: artist.text('name', 'Artist'),
              visual: image == null ? Icon(LucideIcons.micVocal, size: 48, color: c.ink3) : NxImage(url: image),
              ledeWidget: genres.isEmpty ? null : NxChipRow(children: [for (final g in genres) NxChip(g)]),
              actions: [
                NxButton(
                  'Play',
                  icon: LucideIcons.play,
                  onPressed: page.topTracks.firstOrNull?.str('uri') == null
                      ? null
                      : () => ref.read(playerProvider.notifier).playUri(page.topTracks.first.str('uri')!),
                ),
              ],
            ),
            if (page.note case final note?)
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Text(note, style: NxText.muted(context)),
              ),
            const NxSectionHeader('Popular'),
            if (page.topTracks.isEmpty)
              Text('No top tracks available.', style: NxText.muted(context, size: 14))
            else
              TrackList(tracks: page.topTracks.take(10).toList(), numbered: true),
            for (final (title, list) in [('Albums', main), ('Singles & EPs', singles)])
              if (list.isNotEmpty) ...[
                NxSectionHeader(title),
                NxGrid(children: [for (final a in list) AlbumCard(album: a)]),
              ],
          ],
        ),
      );
    },
  );
}

/// Web SpotifyAlbumView: cover stage and the numbered track list.
class AlbumScreen extends ConsumerWidget {
  const new({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) => NxAsync(
    value: ref.watch(albumProvider(id)),
    onRetry: () => ref.invalidate(albumProvider(id)),
    data: (album) {
      final c = context.nx;
      final tracks = [
        for (final t in album.list('tracks'))
          {
            ...t,
            'album_name': album.str('name'),
            'album_image_url': album.str('image_url'),
            'album_id': album.str('id'),
          },
      ];
      final (title, accent) = splitTrackTitle(album.text('name', 'Album'));
      final n = album.integer('total_tracks') ?? tracks.length;
      final artists = album.list('artists').where((a) => a.str('id') != null).toList();
      return ArtAmbient(
        url: album.str('image_url'),
        child: NxPage(
          onRefresh: () async => ref.invalidate(albumProvider(id)),
          children: [
            NxStage(
              eyebrow: ['Album', ?releaseYear(album.str('release_date'))].join(' · '),
              title: title,
              accent: accent,
              visual: album.str('image_url') == null
                  ? Icon(LucideIcons.discAlbum, size: 48, color: c.ink3)
                  : NxImage(url: album.str('image_url')),
              ledeWidget: Wrap(
                children: [
                  for (var i = 0; i < artists.length; i++)
                    GestureDetector(
                      onTap: () => context.push('/spotify/artists/${artists[i].text('id')}'),
                      child: Text(
                        '${artists[i].text('name')}${i < artists.length - 1 ? ', ' : ''}',
                        style: NxText.sans(size: 15.5, color: c.ink2).copyWith(decoration: TextDecoration.underline),
                      ),
                    ),
                  Text(
                    ' · ${plural(n, 'track')}${tracks.isEmpty ? '' : ' · ${totalDuration(tracks)}'}',
                    style: NxText.sans(size: 15.5, color: c.ink2),
                  ),
                ],
              ),
              actions: [
                NxButton(
                  'Play',
                  icon: LucideIcons.play,
                  onPressed: album.str('uri') == null
                      ? null
                      : () => ref.read(playerProvider.notifier).playContext(album.str('uri')!),
                ),
              ],
            ),
            if (album.str('message') case final note?)
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Text(note, style: NxText.muted(context)),
              ),
            const NxSectionHeader('Tracks'),
            TrackList(tracks: tracks, numbered: true, contextUri: album.str('uri')),
          ],
        ),
      );
    },
  );
}
