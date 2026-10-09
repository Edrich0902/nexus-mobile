import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/core/api/polling.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';
import 'package:nexus_mobile/features/f1/f1.dart';
import 'package:nexus_mobile/features/f1/f1_track_replay.dart';
import 'package:nexus_mobile/features/f1/f1_widgets.dart';

enum _Tone { info, warn, bad }

/// Web F1ReplayView: the track replay, its sync state and the focused car's
/// telemetry. Polls while the replay is pending or still filling in.
class F1ReplayScreen extends ConsumerStatefulWidget {
  const F1ReplayScreen({required this.sessionKey, super.key});

  final int sessionKey;

  @override
  ConsumerState<F1ReplayScreen> createState() => _F1ReplayScreenState();
}

class _F1ReplayScreenState extends ConsumerState<F1ReplayScreen> {
  Json? _payload;
  ReplayModel? _model;
  Object? _error;
  bool _loading = true;
  int? _focus;
  Timer? _poll;
  int _telemetryLimit = 20;

  F1Api get _api => ref.read(f1ApiProvider);

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  String? get _status => _payload?.str('status');
  bool get _partial => _payload?.flag('partial') ?? false;

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final payload = await _api.replay(widget.sessionKey, driver: _focus);
      if (!mounted) return;
      setState(() {
        _payload = payload;
        _model = ReplayModel.from(payload);
        _error = null;
        _telemetryLimit = 20;
      });
    } on Object catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    _maybePoll();
  }

  void _maybePoll() {
    _poll?.cancel();
    _poll = null;
    if (!mounted || (_status != 'pending' && !_partial)) return;
    _poll = foregroundPoll(const Duration(seconds: 4), () async {
      final String? next;
      try {
        next = await _api.replayStatus(widget.sessionKey);
      } on Object {
        return;
      }
      if (!mounted || !const {'ready', 'failed', 'unavailable'}.contains(next)) return;
      _poll?.cancel();
      await _load();
    });
  }

  Future<void> _retry() async {
    setState(() => _loading = true);
    try {
      await _api.retryReplay(widget.sessionKey);
      if (!mounted) return;
      setState(() => _payload = {...?_payload, 'status': 'pending', 'message': null});
    } on Object catch (e) {
      if (mounted) showApiError(context, e, 'Could not retry replay.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    _maybePoll();
  }

  void _setFocus(int? driver) {
    setState(() => _focus = driver);
    if (_status == 'ready') unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    final health = ref.watch(f1StatusProvider).value?.obj('provider_health');
    final detail = ref.watch(f1SessionProvider(widget.sessionKey)).value?.detail;
    final lockout = health?.flag('live_lockout') ?? false;
    final message = _payload?.str('message');

    final notice = switch (_status) {
      'pending' when lockout => (
        _Tone.warn,
        'Waiting for OpenF1 to unlock after the live session. The job retries on its own while the queue worker runs.',
      ),
      'pending' => (
        _Tone.info,
        '${message == null ? '' : '$message '}Preparing the replay. This page refreshes on its own.',
      ),
      'failed' => (_Tone.bad, '${message ?? 'The replay sync failed.'} Retry once the queue worker is running.'),
      _ when _partial => (_Tone.info, 'More cars are still syncing and will appear shortly.'),
      _ => null,
    };

    final carData = _payload?.obj('car_data');
    final samples = carData?.list('samples').take(100).toList() ?? const <Json>[];
    final telemetryDriver =
        _model?.cars.where((d) => d.number == carData?.integer('driver_number')).firstOrNull?.code ??
        (carData?.integer('driver_number') == null ? '' : '#${carData!.integer('driver_number')}');

    return NxPage(
      onRefresh: _load,
      children: [
        NxStage(
          compact: true,
          eyebrow: [
            ?detail?.obj('meeting')?.str('meeting_name'),
            ?detail?.obj('session')?.str('session_name'),
          ].join(' · ').ifEmpty('Formula 1'),
          title: 'Track',
          accent: 'replay',
          lede:
              "A downsampled map of where every car was, built from OpenF1's historical location data. "
              'Pick a car to follow it and load its telemetry.',
          actions: [
            NxButton(
              'Retry sync',
              icon: LucideIcons.refreshCw,
              variant: NxButtonVariant.secondary,
              loading: _loading && _payload != null,
              onPressed: _retry,
            ),
          ],
        ),
        F1LockoutBanner(health: health),
        if (notice != null)
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: switch (notice.$1) {
                  _Tone.warn => NexusColors.warn.withValues(alpha: .12),
                  _Tone.bad => NexusColors.bad.withValues(alpha: .12),
                  _Tone.info => c.tint,
                },
                borderRadius: BorderRadius.circular(NxRadius.md),
              ),
              child: Semantics(
                liveRegion: true,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      notice.$1 == _Tone.bad ? LucideIcons.x : LucideIcons.clock,
                      size: 16,
                      color: switch (notice.$1) {
                        _Tone.warn => NexusColors.warn,
                        _Tone.bad => NexusColors.bad,
                        _Tone.info => c.ink2,
                      },
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(notice.$2, style: NxText.sans(color: c.ink2, height: 1.45)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 22),
        if (_error != null && _payload == null)
          NxErrorState(error: _error!, onRetry: _load)
        else if (_loading && _payload == null)
          const AspectRatio(
            aspectRatio: 1,
            child: NxSkeleton(height: double.infinity, radius: NxRadius.lg),
          )
        else if (_model case final model? when !model.isEmpty)
          F1TrackReplay(model: model, focus: _focus, onFocus: _setFocus)
        else
          NxEmptyState(
            compact: true,
            icon: LucideIcons.mapPin,
            title: 'No location data yet',
            body: _status == 'unavailable'
                ? 'OpenF1 has no location data for this session.'
                : 'The replay appears once the location sync finishes.',
          ),
        if (samples.isNotEmpty) ...[
          NxSectionHeader('Telemetry · $telemetryDriver'),
          F1Table(
            columns: const ['Time', 'km/h', 'RPM', 'Gear', 'Thr', 'Brk', 'DRS'],
            flex: const [4, 3, 3, 2, 2, 2, 2],
            rows: [
              for (final s in samples.take(_telemetryLimit))
                [
                  Text(timeOfDay(s.str('date')), style: NxText.mono(color: c.ink3)),
                  for (final key in const ['speed', 'rpm', 'n_gear', 'throttle', 'brake', 'drs'])
                    Text(s.str(key) ?? '—', style: NxText.mono(color: c.ink)),
                ],
            ],
          ),
          if (samples.length > _telemetryLimit)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: NxButton(
                'Show more',
                variant: NxButtonVariant.ghost,
                onPressed: () => setState(() => _telemetryLimit += 20),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'First 100 of ${carData?.integer('sample_count') ?? 0} samples. Replays sync a few cars at a time so the '
              'queue stays healthy.',
              style: NxText.muted(context, size: 12.5),
            ),
          ),
        ],
      ],
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
