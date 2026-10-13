import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/core/api/polling.dart';
import 'package:nexus_mobile/design/ambient.dart';
import 'package:nexus_mobile/design/palettes.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';
import 'package:nexus_mobile/features/listening/listening.dart';
import 'package:nexus_mobile/features/listening/live_position.dart';
import 'package:nexus_mobile/features/listening/player.dart';
import 'package:nexus_mobile/features/listening/spotify_api.dart';

String formatMs(int ms) {
  final s = (ms / 1000).floor();
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// Full player (web dock expanded), tinted from the album art.
Future<void> showPlayerSheet(BuildContext context) =>
    showNxSheet<void>(context, expand: true, builder: (_) => const PlayerPanel());

class PlayerPanel extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<PlayerPanel> createState() => _PlayerPanelState();
}

class _PlayerPanelState extends ConsumerState<PlayerPanel> {
  double? _dragging;

  Future<void> _seek(double ms) async {
    setState(() => _dragging = ms);
    await ref.read(playerProvider.notifier).seek(ms.round());
    if (mounted) setState(() => _dragging = null);
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(playerProvider);
    final ctl = ref.read(playerProvider.notifier);
    final ambient = ref.watch(artAmbientProvider(p.art));
    final c = context.nx;

    if (!p.hasTrack) {
      return NxEmptyState(
        icon: LucideIcons.music,
        title: 'Nothing playing',
        body: 'Start something on Spotify and it shows up here.',
        actionLabel: 'Choose a device',
        onAction: () => showDevicesSheet(context),
      );
    }

    return AmbientOverride(
      ambient: ambient,
      child: ListView(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: NxImage(
              url: p.art,
              radius: NxRadius.xl,
              fallbackIcon: LucideIcons.music,
              semanticLabel: 'Album art',
            ),
          ),
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.title, style: NxText.serif(size: 32, color: c.ink, height: 1.05), maxLines: 2),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () {
                        final id = p.item?.list('artists').firstOrNull?.str('id');
                        if (id == null) return;
                        Navigator.of(context).pop();
                        GoRouter.of(context).go('/spotify/artists/$id');
                      },
                      child: Text(p.artists, style: NxText.sans(size: 15, color: c.ink2)),
                    ),
                  ],
                ),
              ),
              NxIconButton(
                LucideIcons.heart,
                tooltip: p.isLiked ? 'Remove from Liked Songs' : 'Save to Liked Songs',
                color: p.isLiked ? c.acc : null,
                filled: p.isLiked,
                onPressed: ctl.toggleLike,
              ),
            ],
          ),
          const SizedBox(height: 10),
          LiveTrackPosition(
            builder: (context, position, duration) {
              final max = (duration == 0 ? 1 : duration).toDouble();
              final value = (_dragging ?? position.toDouble()).clamp(0, max).toDouble();
              return Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: SliderComponentShape.noOverlay,
                      activeTrackColor: c.acc,
                      inactiveTrackColor: c.tint2,
                      thumbColor: c.acc,
                    ),
                    child: Slider(
                      value: value,
                      max: max,
                      semanticFormatterCallback: (v) => formatMs(v.round()),
                      onChanged: (v) => setState(() => _dragging = v),
                      onChangeEnd: _seek,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(formatMs(value.round()), style: NxText.mono(color: c.ink3)),
                      const Spacer(),
                      Text(formatMs(duration), style: NxText.mono(color: c.ink3)),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              NxIconButton(
                LucideIcons.shuffle,
                tooltip: p.shuffle ? 'Shuffle on' : 'Shuffle off',
                color: p.shuffle ? c.acc : null,
                onPressed: () => ctl.setShuffle(!p.shuffle),
              ),
              NxIconButton(
                LucideIcons.skipBack,
                tooltip: 'Previous',
                size: 52,
                onPressed: p.busy ? null : ctl.previous,
              ),
              PlayToggle(
                playing: p.isPlaying,
                size: 72,
                color: c.acc,
                iconColor: c.accInk,
                onPressed: p.busy ? null : ctl.toggle,
              ),
              NxIconButton(LucideIcons.skipForward, tooltip: 'Next', size: 52, onPressed: p.busy ? null : ctl.next),
              NxIconButton(
                p.repeat == 'track' ? LucideIcons.repeat1 : LucideIcons.repeat,
                tooltip: 'Repeat ${p.repeat}',
                color: p.repeat == 'off' ? null : c.acc,
                onPressed: ctl.cycleRepeat,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(LucideIcons.volume1, size: 18, color: c.ink3),
              Expanded(
                child: _VolumeSlider(
                  value: (p.device?.integer('volume_percent') ?? 50).toDouble(),
                  enabled: p.device?.integer('volume_percent') != null,
                  onChanged: ctl.volume,
                ),
              ),
              Icon(LucideIcons.volume2, size: 18, color: c.ink3),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: NxButton(
                  p.device?.str('name') ?? 'Devices',
                  icon: LucideIcons.speaker,
                  variant: NxButtonVariant.secondary,
                  compact: true,
                  onPressed: () => showDevicesSheet(context),
                ),
              ),
              const SizedBox(width: 8),
              NxButton(
                'Queue',
                icon: LucideIcons.listMusic,
                variant: NxButtonVariant.secondary,
                compact: true,
                onPressed: () => showQueueSheet(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Round play / pause button; the icon cross-fades between states.
class PlayToggle extends StatelessWidget {
  const new({required this.playing, required this.onPressed, this.size = 50, this.color, this.iconColor, super.key});

  final bool playing;
  final VoidCallback? onPressed;
  final double size;
  final Color? color;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    return Semantics(
      button: true,
      label: playing ? 'Pause' : 'Play',
      excludeSemantics: true,
      child: IgnorePointer(
        ignoring: onPressed == null,
        child: NxPressable(
          onTap: () => onPressed?.call(),
          scale: .92,
          child: AnimatedOpacity(
            duration: NxTiming.fast,
            opacity: onPressed == null ? .55 : 1,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(color: color ?? c.ink, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: AnimatedSwitcher(
                duration: NxTiming.fast,
                transitionBuilder: (child, a) => ScaleTransition(
                  scale: Tween<double>(begin: .6, end: 1).animate(a),
                  child: FadeTransition(opacity: a, child: child),
                ),
                child: Icon(
                  playing ? LucideIcons.pause : LucideIcons.play,
                  key: ValueKey(playing),
                  size: size * .42,
                  color: iconColor ?? c.amb,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VolumeSlider extends StatefulWidget {
  const new({required this.value, required this.enabled, required this.onChanged});

  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  State<_VolumeSlider> createState() => _VolumeSliderState();
}

class _VolumeSliderState extends State<_VolumeSlider> {
  double? _local;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        activeTrackColor: c.ink2,
        inactiveTrackColor: c.tint2,
        thumbColor: c.ink,
      ),
      child: Slider(
        value: (_local ?? widget.value).clamp(0, 100),
        max: 100,
        label: 'Volume',
        onChanged: widget.enabled ? (v) => setState(() => _local = v) : null,
        onChangeEnd: (v) {
          widget.onChanged(v);
          Future<void>.delayed(const Duration(seconds: 2), () {
            if (mounted) setState(() => _local = null);
          });
        },
      ),
    );
  }
}

/// Reusable Spotify track row: art, title, artists, tap to play, long-press
/// or menu for queue / like / playlist.
class TrackRow extends ConsumerWidget {
  const new({required this.track, this.reason, this.index, this.contextUri, this.trailing, super.key});

  final Json track;
  final String? reason;
  final int? index;
  final String? contextUri;
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.nx;
    final uri = track.str('uri');
    final playing = ref.watch(playerProvider.select((p) => p.uri)) == uri && uri != null;
    final liked = ref.watch(playerProvider.select((p) => uri != null && (p.liked[uri] ?? false)));
    final art = track.str('album_image_url') ?? track.at('album.images.0.url') as String?;
    final artists = track.list('artists').map((a) => a.text('name')).where((s) => s.isNotEmpty).join(', ');
    final ctl = ref.read(playerProvider.notifier);

    return InkWell(
      onTap: uri == null
          ? null
          : () => contextUri != null ? ctl.playContext(contextUri!, offsetUri: uri) : ctl.playUri(uri),
      onLongPress: uri == null ? null : () => showTrackActions(context, ref, track),
      borderRadius: BorderRadius.circular(NxRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            if (index != null)
              SizedBox(
                width: 28,
                child: Text('${index! + 1}', style: NxText.mono(color: playing ? c.acc : c.ink4)),
              ),
            if (index == null)
              SizedBox(
                width: 44,
                height: 44,
                child: NxImage(url: art, radius: 8, fallbackIcon: LucideIcons.music),
              ),
            if (index == null) const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.text('name'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: NxText.sans(size: 14.5, weight: FontWeight.w500, color: playing ? c.acc : c.ink),
                  ),
                  Text(
                    [artists, ?reason].where((s) => s.isNotEmpty).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: NxText.sans(size: 12.5, color: c.ink3),
                  ),
                ],
              ),
            ),
            if (liked) Icon(LucideIcons.heart, size: 14, color: c.acc),
            ?trailing,
            NxIconButton(
              LucideIcons.ellipsis,
              tooltip: 'More',
              size: 36,
              onPressed: uri == null ? null : () => showTrackActions(context, ref, track),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showTrackActions(BuildContext context, WidgetRef ref, Json track) {
  final uri = track.str('uri')!;
  final ctl = ref.read(playerProvider.notifier);
  final liked = ref.read(playerProvider).liked[uri] ?? false;
  return showNxSheet<void>(
    context,
    title: track.text('name'),
    builder: (sheet) {
      void close() => Navigator.of(sheet).pop();
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          NxListRow(
            label: 'Play',
            icon: LucideIcons.play,
            onTap: () {
              close();
              ctl.playUri(uri);
            },
          ),
          NxListRow(
            label: 'Add to queue',
            icon: LucideIcons.listPlus,
            onTap: () async {
              close();
              if (await ctl.queueTrack(uri) && context.mounted) showNxToast(context, 'Added to queue');
            },
          ),
          NxListRow(
            label: liked ? 'Remove from Liked Songs' : 'Save to Liked Songs',
            icon: LucideIcons.heart,
            onTap: () {
              close();
              ctl.toggleLike(uri);
            },
          ),
          NxListRow(
            label: 'Add to playlist',
            icon: LucideIcons.listMusic,
            onTap: () {
              close();
              showAddToPlaylistSheet(context, uri);
            },
          ),
          if (track.list('artists').firstOrNull?.str('id') case final artistId?)
            NxListRow(
              label: 'Go to artist',
              icon: LucideIcons.micVocal,
              onTap: () {
                close();
                GoRouter.of(context).push('/spotify/artists/$artistId');
              },
            ),
          if (track.str('album_id') ?? track.at('album.id') case final String albumId)
            NxListRow(
              label: 'Go to album',
              icon: LucideIcons.discAlbum,
              onTap: () {
                close();
                GoRouter.of(context).push('/spotify/albums/$albumId');
              },
            ),
        ],
      );
    },
  );
}

final _devicesProvider = FutureProvider.autoDispose<List<Json>>((ref) => ref.watch(spotifyApiProvider).devices());

Future<void> showDevicesSheet(BuildContext context) => showNxSheet<void>(
  context,
  title: 'Play on',
  builder: (_) => Consumer(
    builder: (context, ref, _) {
      final c = context.nx;
      return NxAsync(
        value: ref.watch(_devicesProvider),
        onRetry: () => ref.invalidate(_devicesProvider),
        data: (devices) => devices.isEmpty
            ? const NxEmptyState(
                icon: LucideIcons.speaker,
                title: 'No devices',
                body: 'Open Spotify on a phone, computer or speaker and it shows up here.',
                compact: true,
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final d in devices)
                    NxListRow(
                      label: d.text('name'),
                      detail: d.text('type'),
                      icon: switch (d.text('type').toLowerCase()) {
                        'computer' => LucideIcons.laptop,
                        'smartphone' => LucideIcons.smartphone,
                        _ => LucideIcons.speaker,
                      },
                      trailing: d.flag('is_active') ? Icon(LucideIcons.check, color: c.acc, size: 18) : null,
                      onTap: d.flag('is_restricted')
                          ? null
                          : () {
                              Navigator.of(context).pop();
                              ref.read(playerProvider.notifier).transfer(d.text('id'));
                            },
                    ),
                ],
              ),
      );
    },
  ),
);

Future<void> showQueueSheet(BuildContext context) =>
    showNxSheet<void>(context, title: 'Up next', expand: true, builder: (_) => const _QueueBody());

class _QueueBody extends ConsumerStatefulWidget {
  const new();

  @override
  ConsumerState<_QueueBody> createState() => _QueueBodyState();
}

class _QueueBodyState extends ConsumerState<_QueueBody> {
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    unawaited(ref.read(playerProvider.notifier).fetchQueue());
    _refresh = foregroundPoll(const Duration(seconds: 10), () => ref.read(playerProvider.notifier).fetchQueue());
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  Json _asTrack(Json item) => {...item, 'album_image_url': item.at('album.images.0.url')};

  @override
  Widget build(BuildContext context) {
    final q = ref.watch(playerProvider.select((p) => p.queue));
    if (q == null) return const NxPageSkeleton(art: false);
    final items = q.list('queue');
    if (items.isEmpty) {
      return const NxEmptyState(icon: LucideIcons.listMusic, title: 'Queue is empty', compact: true);
    }
    return ListView(children: [for (final i in items) TrackRow(track: _asTrack(i))]);
  }
}

Future<void> showAddToPlaylistSheet(BuildContext context, String uri) => showNxSheet<void>(
  context,
  title: 'Add to playlist',
  expand: true,
  builder: (_) => Consumer(
    builder: (context, ref, _) => NxAsync(
      value: ref.watch(spotifyPlaylistsProvider),
      data: (lists) {
        final own = lists.where((p) => p.flag('is_owner') || p.flag('collaborative')).toList();
        return ListView(
          children: [
            for (final p in own)
              NxListRow(
                label: p.text('name'),
                detail: '${p.integer('item_count') ?? 0} tracks',
                icon: LucideIcons.listMusic,
                onTap: () async {
                  Navigator.of(context).pop();
                  try {
                    await ref.read(spotifyApiProvider).addPlaylistItems(p.text('id'), [uri]);
                    if (context.mounted) showNxToast(context, 'Added to ${p.text('name')}');
                  } on Object catch (e) {
                    if (context.mounted) showApiError(context, e, 'Unable to add to playlist');
                  }
                },
              ),
          ],
        );
      },
    ),
  ),
);
