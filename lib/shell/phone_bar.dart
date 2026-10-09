import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/core/router/navigation.dart';
import 'package:nexus_mobile/design/ambient_palette.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';
import 'package:nexus_mobile/features/listening/live_position.dart';
import 'package:nexus_mobile/features/listening/player.dart';
import 'package:nexus_mobile/features/listening/player_sheet.dart';
import 'package:nexus_mobile/shell/more_sheet.dart';

/// Web NxDock at ≤640px: Spotify strip above a five-tab bar.
class PhoneBar extends ConsumerWidget {
  const PhoneBar({required this.location, super.key});

  final String location;

  static const tabsHeight = 58.0;
  static const stripHeight = 54.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.nx;
    final mq = MediaQuery.of(context);
    final hasTrack = ref.watch(playerProvider.select((p) => p.hasTrack));
    final inTabs = Nav.phoneTabs.any((d) => Nav.isActive(d, location));

    return ClipRect(
      child: BackdropFilter.grouped(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: EdgeInsets.only(bottom: mq.padding.bottom),
          decoration: BoxDecoration(
            color: mix(c.amb, .88, Colors.black).withValues(alpha: .94),
            border: Border(top: BorderSide(color: c.line)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSize(
                duration: const Duration(milliseconds: 260),
                curve: NxMotion.ease,
                child: NxSwitcher(
                  child: hasTrack
                      ? const _Strip(key: ValueKey('strip'))
                      : const SizedBox(key: ValueKey('none'), width: double.infinity),
                ),
              ),
              SizedBox(
                height: tabsHeight,
                child: Row(
                  children: [
                    for (final d in Nav.phoneTabs)
                      _Tab(
                        icon: d.icon,
                        label: d.label,
                        active: Nav.isActive(d, location),
                        onTap: () => context.go(d.to),
                      ),
                    _Tab(
                      icon: LucideIcons.sparkles,
                      label: 'More',
                      active: !inTabs,
                      onTap: () => showMoreSheet(context, location),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A tab: the active one sits on a tinted pill that grows in, and its icon
/// gives a small spring when it becomes active.
class _Tab extends StatefulWidget {
  const _Tab({required this.icon, required this.label, required this.active, required this.onTap});

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_Tab> createState() => _TabState();
}

class _TabState extends State<_Tab> with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween<double>(begin: 1, end: 1.18).chain(CurveTween(curve: Curves.easeOut)), weight: 35),
    TweenSequenceItem(
      tween: Tween<double>(begin: 1.18, end: 1).chain(CurveTween(curve: Curves.elasticOut)),
      weight: 65,
    ),
  ]).animate(_pop);

  @override
  void didUpdateWidget(_Tab old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active && !reduceMotion(context)) _pop.forward(from: 0);
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    final active = widget.active;
    final color = active ? c.acc : c.ink3;
    return Expanded(
      child: Semantics(
        button: true,
        selected: active,
        label: widget.label,
        excludeSemantics: true,
        child: NxPressable(
          onTap: widget.onTap,
          scale: .9,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: NxTiming.base,
                curve: NxMotion.ease,
                width: active ? 52 : 34,
                height: 28,
                decoration: BoxDecoration(
                  color: active ? c.acc.withValues(alpha: .16) : c.acc.withValues(alpha: 0),
                  borderRadius: BorderRadius.circular(NxRadius.pill),
                ),
                alignment: Alignment.center,
                child: ScaleTransition(
                  scale: _scale,
                  child: TweenAnimationBuilder<Color?>(
                    tween: ColorTween(end: color),
                    duration: NxTiming.base,
                    builder: (_, value, _) => Icon(widget.icon, size: 20, color: value),
                  ),
                ),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: NxTiming.base,
                style: NxText.sans(size: 11, weight: active ? FontWeight.w600 : FontWeight.w500, color: color),
                child: Text(widget.label, maxLines: 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Strip extends ConsumerWidget {
  const _Strip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.nx;
    final p = ref.watch(playerProvider);
    final device = p.device?.str('name');
    return Semantics(
      button: true,
      label: 'Now playing: ${p.title} by ${p.artists}. Open player',
      child: InkWell(
        onTap: () => showPlayerSheet(context),
        child: Container(
          height: PhoneBar.stripHeight,
          padding: const EdgeInsets.fromLTRB(12, 8, 6, 6),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: c.line)),
          ),
          child: Stack(
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: AnimatedSwitcher(
                      duration: NxTiming.page,
                      child: NxImage(key: ValueKey(p.art), url: p.art, radius: 8, fallbackIcon: LucideIcons.music),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: NxSwitcher(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        key: ValueKey(p.uri),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            p.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: NxText.sans(size: 13.5, weight: FontWeight.w600, color: c.ink),
                          ),
                          Text(
                            [p.artists, ?device].where((s) => s.isNotEmpty).join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: NxText.sans(size: 12, color: c.ink3),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (p.isPlaying) const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: NxEqualiser()),
                  NxIconButton(
                    p.isPlaying ? LucideIcons.pause : LucideIcons.play,
                    tooltip: p.isPlaying ? 'Pause' : 'Play',
                    size: 34,
                    onPressed: p.busy ? null : () => ref.read(playerProvider.notifier).toggle(),
                  ),
                ],
              ),
              Positioned(
                left: -12,
                right: -6,
                bottom: -6,
                child: LiveTrackPosition(
                  builder: (_, position, duration) => NxProgressRail(
                    value: duration == 0 ? 0 : position / duration,
                    height: 2,
                    color: const Color(0xFF1ED760),
                    track: Colors.transparent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Spotify-green three-bar equaliser. Steps like a hardware meter on a
/// timer (about 7 frames a second) instead of a vsync ticker, so a playing
/// track doesn't keep the whole screen, blurs included, redrawing at 60fps.
class NxEqualiser extends StatefulWidget {
  const NxEqualiser({super.key});

  static const step = Duration(milliseconds: 140);

  @override
  State<NxEqualiser> createState() => _NxEqualiserState();
}

class _NxEqualiserState extends State<NxEqualiser> {
  static const _levels = <double>[5, 9, 14, 11, 7, 12, 4, 10, 13, 6];
  static const _offsets = [0, 4, 7];
  Timer? _timer;
  var _frame = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = (MediaQuery.maybeDisableAnimationsOf(context) ?? false) || !TickerMode.of(context);
    if (still) {
      _timer?.cancel();
      _timer = null;
    } else {
      _timer ??= Timer.periodic(NxEqualiser.step, (_) => setState(() => _frame++));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RepaintBoundary(
      child: SizedBox(
        height: 14,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final offset in _offsets)
              Container(
                width: 3,
                height: _levels[(_frame + offset) % _levels.length],
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(color: const Color(0xFF1ED760), borderRadius: BorderRadius.circular(2)),
              ),
          ],
        ),
      ),
    ),
  );
}
