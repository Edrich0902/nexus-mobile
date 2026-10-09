import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/core/format.dart';
import 'package:nexus_mobile/design/profile.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';
import 'package:nexus_mobile/features/collections/collection_fields.dart';
import 'package:nexus_mobile/features/home/home_modules.dart';
import 'package:nexus_mobile/features/listening/listening.dart';
import 'package:nexus_mobile/features/listening/player.dart';

const _ranges = [('short_term', '4 weeks'), ('medium_term', '6 months'), ('long_term', 'All time')];
const _dayparts = ['morning', 'afternoon', 'evening', 'night'];
const _daypartHours = {
  'morning': '05:00 to 12:00',
  'afternoon': '12:00 to 17:00',
  'evening': '17:00 to 22:00',
  'night': '22:00 to 05:00',
};

/// Web SpotifyStatsView: how you listen — top artists and tracks by range,
/// dayparts, weekdays, on repeat, genres and the sound of your week.
class SpotifyStatsScreen extends ConsumerStatefulWidget {
  const SpotifyStatsScreen({super.key});

  @override
  ConsumerState<SpotifyStatsScreen> createState() => _SpotifyStatsScreenState();
}

class _SpotifyStatsScreenState extends ConsumerState<SpotifyStatsScreen> {
  String _range = 'short_term';

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(spotifyStatusProvider);
    final tasteAsync = ref.watch(spotifyTasteProvider);
    final taste = tasteAsync.value;
    final connected = status.value?.flag('connected') ?? false;
    final s = taste?.obj('summary');
    final loading = status.isLoading || (connected && tasteAsync.isLoading && taste == null);
    final ready = connected && taste != null && taste.isNotEmpty;

    final lede = s == null
        ? 'What you play, when you play it and what keeps coming back.'
        : [
            '${plural(s.integer('plays_last_7d') ?? 0, 'play')} this week across ${plural(s.integer('unique_tracks_last_7d') ?? 0, 'track')}.',
            if (s.str('top_genre') case final g?)
              'Mostly $g${s.str('peak_bucket') == null ? '' : ', mostly in the ${s.str('peak_bucket')}'}.',
          ].join(' ');

    return NxPage(
      onRefresh: () async {
        ref.invalidate(spotifyTasteProvider);
        await ref.read(spotifyTasteProvider.future);
      },
      children: [
        NxStage(compact: true, eyebrow: 'Listening', title: 'How you', accent: 'listen', lede: lede),
        const SizedBox(height: 22),
        const ListeningNav(value: '/spotify/stats'),
        const SizedBox(height: 16),
        if (loading)
          const NxSkeleton(height: 320, radius: NxRadius.lg)
        else if (!connected)
          const ConnectSpotifyState(body: 'Stats build up from what you play once Spotify is linked.')
        else if (!ready)
          NxEmptyState(
            icon: LucideIcons.headphones,
            title: 'Not enough listening yet',
            body: 'Play some music, sync, and check back.',
            actionLabel: 'Sync now',
            onAction: () => syncSpotify(context, ref),
          )
        else
          ..._ready(context, taste, s),
      ],
    );
  }

  List<Widget> _ready(BuildContext context, Json taste, Json? s) {
    final topArtists = (taste.obj('top_artists')?.list(_range) ?? const []).take(10).toList();
    final topTracks = (taste.obj('top_tracks')?.list(_range) ?? const []).take(10).toList();
    final onRepeat = taste.list('on_repeat').take(8).toList();
    final buckets = taste.obj('time_of_day')?.list('buckets') ?? const [];
    final counts = [
      for (final d in _dayparts)
        buckets.firstWhere((b) => b.str('bucket') == d, orElse: () => const {}).integer('count') ?? 0,
    ];
    final total = counts.fold(0, (a, b) => a + b);
    final peakIndex = total == 0 ? -1 : counts.indexOf(counts.reduce(math.max));
    final peak = peakIndex < 0 ? null : _dayparts[peakIndex];
    final weekdays = taste.obj('time_of_day')?.list('weekday') ?? const [];
    final genres = taste.list('genres').take(8).toList();
    final maxGenre = genres.fold<int>(1, (m, g) => math.max(m, g.integer('count') ?? 0));
    final dna = audioMeters(taste.obj('audio_metrics')?.obj('7d')?.obj('averages'));
    Widget empty(String text) => Text(text, style: NxText.muted(context, size: 14));

    return [
      CollectionFields(
        section: SectionKey.listening,
        fields: [
          CollectionField(
            key: 'plays',
            label: 'Plays · 7 days',
            value: '${s?.integer('plays_last_7d') ?? '—'}',
            span: 2,
          ),
          CollectionField(
            key: 'unique',
            label: 'Different tracks',
            value: '${s?.integer('unique_tracks_last_7d') ?? '—'}',
            variant: FieldVariant.tint,
          ),
          CollectionField(
            key: 'genre',
            label: 'Top genre',
            title: s?.str('top_genre') == null ? '—' : capitalise(s!.str('top_genre')),
            variant: s?.str('top_genre') == null ? FieldVariant.outline : FieldVariant.tint,
          ),
          CollectionField(
            key: 'peak',
            label: 'Peak',
            title: s?.str('peak_bucket') == null ? '—' : capitalise(s!.str('peak_bucket')),
            variant: FieldVariant.outline,
            span: 2,
          ),
        ],
      ),
      const SizedBox(height: 22),
      NxPillNav<String>(expand: true, items: _ranges, value: _range, onChanged: (v) => setState(() => _range = v)),
      const NxSectionHeader('Top artists', top: 22),
      if (topArtists.isEmpty)
        empty('No top artists for this range yet.')
      else
        NxPanel(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              for (var i = 0; i < topArtists.length; i++)
                if (topArtists[i].obj('artist') case final a?)
                  NxRankRow(
                    rank: i + 1,
                    title: a.text('name'),
                    subtitle: capitalise(a.strings('genres').firstOrNull).isEmpty
                        ? null
                        : capitalise(a.strings('genres').first),
                    imageUrl: largestImage(a),
                    circle: true,
                    onTap: () => context.push('/spotify/artists/${a.text('id')}'),
                  ),
            ],
          ),
        ),
      const NxSectionHeader('When you listen'),
      NxPanel(
        child: total == 0
            ? empty('Not enough plays to see a pattern yet.')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  NxHourBars(counts, height: 120, ticks: _dayparts.map(capitalise).toList()),
                  if (peak != null)
                    NxSerifSummary([
                      ('Your ', false),
                      ('${peak}s', true),
                      (' are the loudest: ', false),
                      ('${(counts[peakIndex] / total * 100).round()}%', true),
                      (' of everything you play lands between ${_daypartHours[peak]}.', false),
                    ]),
                ],
              ),
      ),
      const NxSectionHeader('By weekday'),
      NxPanel(
        child: weekdays.any((d) => (d.integer('count') ?? 0) > 0)
            ? NxHourBars(
                [for (final d in weekdays) d.integer('count') ?? 0],
                height: 120,
                ticks: [for (final d in weekdays) d.text('day').padRight(3).substring(0, 3)],
              )
            : empty('Not enough plays to see a pattern yet.'),
      ),
      const NxSectionHeader('Top tracks'),
      if (topTracks.isEmpty)
        empty('No top tracks for this range yet.')
      else
        NxPanel(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              for (var i = 0; i < topTracks.length; i++)
                if (topTracks[i].obj('track') case final t?)
                  NxRankRow(
                    rank: i + 1,
                    title: t.text('name'),
                    subtitle: artistNames(t),
                    imageUrl: t.str('album_image_url'),
                    onTap: t.str('album_id') == null
                        ? null
                        : () => context.push('/spotify/albums/${t.str('album_id')}'),
                  ),
            ],
          ),
        ),
      const NxSectionHeader('On repeat'),
      if (onRepeat.isEmpty)
        empty('Play the same track twice in a week to see it here.')
      else
        TrackList(
          tracks: [for (final r in onRepeat) r.obj('track') ?? const {}],
          meta: (i, _) => '${onRepeat[i].integer('play_count') ?? 0}×',
        ),
      const NxSectionHeader('Genres'),
      NxPanel(
        child: genres.isEmpty
            ? empty('Genres appear once your top artists sync.')
            : NxMeters(
                [
                  for (final g in genres)
                    ProfileAxis(
                      capitalise(g.str('genre')),
                      (g.integer('count') ?? 0) / maxGenre,
                      '${g.integer('count') ?? 0}',
                    ),
                ],
                labelWidth: 110,
                showWords: true,
              ),
      ),
      const NxSectionHeader('Sound of your week'),
      NxPanel(
        child: dna.isEmpty
            ? empty('An acoustic profile builds as you listen to full tracks.')
            : NxMeters(dna, labelWidth: 90, showWords: true),
      ),
    ];
  }
}
