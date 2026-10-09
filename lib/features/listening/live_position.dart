import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_mobile/features/listening/player.dart';

/// Rebuilds [builder] with the playback position extrapolated between player
/// polls, so rails keep moving while a track plays. Steps on a light timer
/// (half a second is under a pixel on a phone-width rail) instead of a vsync
/// ticker, and only this subtree repaints.
class LiveTrackPosition extends ConsumerStatefulWidget {
  const LiveTrackPosition({required this.builder, this.step = const Duration(milliseconds: 500), super.key});

  final Widget Function(BuildContext context, int positionMs, int durationMs) builder;
  final Duration step;

  @override
  ConsumerState<LiveTrackPosition> createState() => _LiveTrackPositionState();
}

class _LiveTrackPositionState extends ConsumerState<LiveTrackPosition> {
  Timer? _timer;

  void _run(bool playing) {
    if (playing && TickerMode.of(context)) {
      _timer ??= Timer.periodic(widget.step, (_) {
        if (mounted) setState(() {});
      });
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (_, duration, playing, _) = ref.watch(
      playerProvider.select((p) => (p.progressMs, p.durationMs, p.isPlaying, p.syncedAt)),
    );
    _run(playing);
    final position = ref.read(playerProvider).positionAt(DateTime.now());
    return RepaintBoundary(child: widget.builder(context, position, duration));
  }
}
