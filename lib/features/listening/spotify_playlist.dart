import 'dart:async';

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
import 'package:nexus_mobile/features/listening/spotify_api.dart';

/// Create (no [playlist]) or rename / redescribe a playlist. Resolves with the
/// saved playlist.
Future<Json?> showPlaylistSheet(BuildContext context, {Json? playlist}) => showNxSheet<Json>(
  context,
  title: playlist == null ? 'New playlist' : 'Edit playlist',
  builder: (_) => _PlaylistForm(playlist: playlist),
);

class _PlaylistForm extends ConsumerStatefulWidget {
  const _PlaylistForm({this.playlist});

  final Json? playlist;

  @override
  ConsumerState<_PlaylistForm> createState() => _PlaylistFormState();
}

class _PlaylistFormState extends ConsumerState<_PlaylistForm> {
  late final _name = TextEditingController(text: widget.playlist?.str('name'));
  late final _description = TextEditingController(text: plainText(widget.playlist?.str('description')));
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    final api = ref.read(spotifyApiProvider);
    final payload = {'name': name, 'description': _description.text.trim()};
    try {
      final saved = widget.playlist == null
          ? await api.createPlaylist(payload)
          : await api.updatePlaylist(widget.playlist!.text('id'), payload);
      ref.invalidate(spotifyPlaylistsProvider);
      if (widget.playlist != null) ref.invalidate(playlistProvider(widget.playlist!.text('id')));
      if (mounted) Navigator.of(context).pop(saved);
    } on Object catch (e) {
      if (mounted) showApiError(context, e, 'Could not save the playlist.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      NxForm(
        children: [
          NxTextField(label: 'Name', controller: _name, autofocus: widget.playlist == null),
          NxTextField(label: 'Description', controller: _description, maxLines: 3),
        ],
      ),
      NxSheetActions(
        label: widget.playlist == null ? 'Create playlist' : 'Save',
        busy: _saving,
        onSubmit: _name.text.trim().isEmpty ? null : _save,
      ),
    ],
  );
}

/// One playlist (web SpotifyPlaylistView): tracks, play from any row, edit,
/// refresh from Spotify, remove tracks and delete / unfollow.
class PlaylistScreen extends ConsumerStatefulWidget {
  const PlaylistScreen({required this.id, super.key});

  final String id;

  @override
  ConsumerState<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends ConsumerState<PlaylistScreen> {
  bool _refreshing = false;

  Future<void> _refreshFromSpotify() async {
    setState(() => _refreshing = true);
    try {
      await ref.read(spotifyApiProvider).playlist(widget.id, refresh: true);
      ref.invalidate(playlistProvider(widget.id));
    } on Object catch (e) {
      if (mounted) showApiError(context, e, 'Could not refresh from Spotify.');
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _delete(Json p) async {
    final owner = p.flag('is_owner');
    final ok = await showNxConfirm(
      context,
      message: owner ? 'Delete this playlist from your Spotify?' : 'Unfollow this playlist?',
      confirmLabel: owner ? 'Delete' : 'Unfollow',
      cancelLabel: 'Cancel',
    );
    if (!ok) return;
    try {
      await ref.read(spotifyApiProvider).deletePlaylist(widget.id);
      ref.invalidate(spotifyPlaylistsProvider);
      if (mounted) context.go('/spotify');
    } on Object catch (e) {
      if (mounted) showApiError(context, e, 'Could not remove the playlist.');
    }
  }

  Future<void> _removeTrack(String uri, int? position) async {
    try {
      await ref.read(spotifyApiProvider).removePlaylistItems(widget.id, [(uri: uri, position: position)]);
      ref
        ..invalidate(playlistProvider(widget.id))
        ..invalidate(spotifyPlaylistsProvider);
      if (mounted) showNxToast(context, 'Removed from playlist');
    } on Object catch (e) {
      if (mounted) showApiError(context, e, 'Unable to remove track');
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(playlistProvider(widget.id));
    return NxAsync(
      value: async,
      onRetry: () => ref.invalidate(playlistProvider(widget.id)),
      data: (p) {
        final c = context.nx;
        final items = p.list('items').where((i) => i.obj('track') != null).toList();
        final tracks = [for (final i in items) i.obj('track')!];
        final owner = p.flag('is_owner');
        final description = plainText(p.str('description'));
        final count = p.integer('item_count') ?? tracks.length;
        final lede = [
          plural(count, 'track'),
          if (tracks.isNotEmpty) totalDuration(tracks),
          if (p.str('synced_at') case final at?) 'synced ${relativeTime(DateTime.tryParse(at))}',
        ].join(' · ');
        return ArtAmbient(
          url: p.str('image_url'),
          child: NxPage(
            onRefresh: () async => ref.invalidate(playlistProvider(widget.id)),
            children: [
              NxStage(
                eyebrow: owner ? 'Your playlist' : 'Playlist',
                title: p.text('name', 'Playlist'),
                ledeWidget: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(description, style: NxText.sans(size: 15.5, color: c.ink2, height: 1.45)),
                      ),
                    Text(lede, style: NxText.sans(size: 13.5, color: c.ink3)),
                  ],
                ),
                visual: p.str('image_url') == null
                    ? Icon(LucideIcons.listMusic, size: 48, color: c.ink3)
                    : NxImage(url: p.str('image_url')),
                actions: [
                  NxButton(
                    'Play',
                    icon: LucideIcons.play,
                    onPressed: p.str('uri') == null || tracks.isEmpty
                        ? null
                        : () => ref.read(playerProvider.notifier).playContext(p.str('uri')!),
                  ),
                  if (owner)
                    NxIconButton(
                      LucideIcons.pencil,
                      tooltip: 'Edit',
                      filled: true,
                      onPressed: () => showPlaylistSheet(context, playlist: p),
                    ),
                  NxIconButton(
                    LucideIcons.refreshCw,
                    tooltip: 'Refresh from Spotify',
                    filled: true,
                    onPressed: _refreshing ? null : _refreshFromSpotify,
                  ),
                  NxIconButton(
                    LucideIcons.trash2,
                    tooltip: owner ? 'Delete playlist' : 'Unfollow',
                    filled: true,
                    onPressed: () => _delete(p),
                  ),
                ],
              ),
              const NxSectionHeader('Tracks'),
              if (tracks.isEmpty)
                const NxEmptyState(
                  compact: true,
                  icon: LucideIcons.listMusic,
                  title: 'No tracks yet',
                  body: 'Add tracks from search, the player or any track menu.',
                )
              else
                TrackList(
                  tracks: tracks,
                  numbered: true,
                  contextUri: p.str('uri'),
                  trailing: owner
                      ? (i, t) => NxIconButton(
                          LucideIcons.minus,
                          tooltip: 'Remove from playlist',
                          size: 34,
                          onPressed: t.str('uri') == null
                              ? null
                              : () => unawaited(_removeTrack(t.str('uri')!, items[i].integer('position'))),
                        )
                      : null,
                ),
            ],
          ),
        );
      },
    );
  }
}
