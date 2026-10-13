import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/core/router/navigation.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';
import 'package:nexus_mobile/features/listening/live_position.dart';
import 'package:nexus_mobile/features/listening/player.dart';
import 'package:nexus_mobile/features/listening/player_sheet.dart';
import 'package:nexus_mobile/shell/more_sheet.dart';
import 'package:nexus_mobile/shell/search_sheet.dart';

/// Floating glass dock (iOS 26 style, same on Android): a tab bar with a
/// sliding lens beside a search orb, and the now-playing capsule above.
/// When [collapsed] the tab bar shrinks to the active tab and the player
/// slides down into the dock row between it and search.
class PhoneBar extends ConsumerWidget {
  const new({required this.location, required this.collapsed, required this.onExpand, super.key});

  final String location;
  final ValueListenable<bool> collapsed;
  final VoidCallback onExpand;

  static const dockHeight = 62.0;
  static const miniHeight = 54.0;
  static const side = 14.0;
  static const gap = 10.0;

  /// Overshoots a touch before settling, like the system glass.
  static const spring = Cubic(.32, 1.25, .45, 1);
  static const springDuration = Duration(milliseconds: 550);

  /// Sits in the home-indicator zone rather than above it; never flush
  /// with the screen edge on devices without one.
  static double dockBottom(MediaQueryData mq) => math.max(mq.padding.bottom - 10, 12);

  /// Space pages leave free at the bottom so content can scroll clear.
  static double inset(MediaQueryData mq, {required bool hasTrack}) =>
      dockBottom(mq) + dockHeight + (hasTrack ? gap + miniHeight : 0) + 8;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mq = MediaQuery.of(context);
    final hasTrack = ref.watch(playerProvider.select((p) => p.hasTrack));
    final duration = reduceMotion(context) ? Duration.zero : springDuration;
    final bottom = dockBottom(mq);

    return LayoutBuilder(
      builder: (context, box) {
        final barWidth = box.maxWidth - side * 2 - dockHeight - gap;
        return ValueListenableBuilder<bool>(
          valueListenable: collapsed,
          builder: (context, min, _) {
            final miniSide = min ? side + dockHeight + gap : side;
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: duration,
                  curve: spring,
                  left: miniSide,
                  right: miniSide,
                  bottom: min ? bottom + (dockHeight - miniHeight) / 2 : bottom + dockHeight + gap,
                  height: miniHeight,
                  child: NxSwitcher(
                    child: hasTrack
                        ? _MiniPlayer(key: const ValueKey('mini'), compact: min)
                        : const SizedBox.shrink(key: ValueKey('none')),
                  ),
                ),
                AnimatedPositioned(
                  duration: duration,
                  curve: spring,
                  left: side,
                  bottom: bottom,
                  height: dockHeight,
                  width: min ? dockHeight : barWidth,
                  child: _TabBar(location: location, collapsed: min, fullWidth: barWidth, onExpand: onExpand),
                ),
                Positioned(
                  right: side,
                  bottom: bottom,
                  width: dockHeight,
                  height: dockHeight,
                  child: Semantics(
                    button: true,
                    label: 'Search',
                    excludeSemantics: true,
                    child: NxPressable(
                      onTap: () => showSearchSheet(context),
                      scale: .92,
                      child: NxGlass(
                        child: Center(child: Icon(LucideIcons.search, size: 22, color: context.nx.ink)),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _TabBar extends StatelessWidget {
  const new({required this.location, required this.collapsed, required this.fullWidth, required this.onExpand});

  final String location;
  final bool collapsed;
  final double fullWidth;
  final VoidCallback onExpand;

  static const _pad = 4.0;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    final tabs = [for (final d in Nav.phoneTabs) (d.icon, d.label, Nav.isActive(d, location), () => context.go(d.to))];
    final inTabs = tabs.any((t) => t.$3);
    tabs.add((LucideIcons.sparkles, 'More', !inTabs, () => showMoreSheet(context, location)));
    final active = tabs.indexWhere((t) => t.$3);
    final tabWidth = (fullWidth - _pad * 2) / tabs.length;
    final duration = reduceMotion(context) ? Duration.zero : PhoneBar.springDuration;
    final fade = reduceMotion(context) ? Duration.zero : NxTiming.fast;

    return NxGlass(
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedPositioned(
            duration: duration,
            curve: PhoneBar.spring,
            top: _pad,
            bottom: _pad,
            left: collapsed ? _pad : _pad + active * tabWidth,
            width: collapsed ? PhoneBar.dockHeight - _pad * 2 : tabWidth,
            child: const NxGlassLens(),
          ),
          IgnorePointer(
            ignoring: collapsed,
            child: AnimatedOpacity(
              opacity: collapsed ? 0 : 1,
              duration: fade,
              child: OverflowBox(
                alignment: Alignment.centerLeft,
                minWidth: fullWidth,
                maxWidth: fullWidth,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: _pad),
                  child: Row(
                    children: [
                      for (final (icon, label, on, onTap) in tabs)
                        _Tab(icon: icon, label: label, active: on, onTap: onTap),
                    ],
                  ),
                ),
              ),
            ),
          ),
          IgnorePointer(
            ignoring: !collapsed,
            child: AnimatedOpacity(
              opacity: collapsed ? 1 : 0,
              duration: fade,
              child: Semantics(
                button: true,
                label: 'Show tabs',
                excludeSemantics: true,
                child: NxPressable(
                  onTap: onExpand,
                  scale: .9,
                  child: Center(child: Icon(tabs[active].$1, size: 22, color: c.acc)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A tab: icon over label, accent when active, with a small spring on the
/// icon as it becomes active. The lens behind it is drawn by [_TabBar].
class _Tab extends StatefulWidget {
  const new({required this.icon, required this.label, required this.active, required this.onTap});

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
    final color = active ? c.acc : c.ink2;
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
              ScaleTransition(
                scale: _scale,
                child: TweenAnimationBuilder<Color?>(
                  tween: ColorTween(end: color),
                  duration: NxTiming.base,
                  builder: (_, value, _) => Icon(widget.icon, size: 21, color: value),
                ),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: NxTiming.base,
                style: NxText.sans(size: 10.5, weight: FontWeight.w600, color: color),
                child: Text(widget.label, maxLines: 1, overflow: TextOverflow.clip),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Now-playing capsule. [compact] is the docked form between the collapsed
/// tab bar and search: no equaliser or skip, so the title keeps its room.
class _MiniPlayer extends ConsumerWidget {
  const new({required this.compact, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.nx;
    final p = ref.watch(playerProvider);
    final device = p.device?.str('name');
    final player = ref.read(playerProvider.notifier);
    return Semantics(
      button: true,
      label: 'Now playing: ${p.title} by ${p.artists}. Open player',
      child: NxPressable(
        onTap: () => showPlayerSheet(context),
        scale: .98,
        child: NxGlass(
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.only(left: 8, right: compact ? 4 : 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 38,
                      height: 38,
                      child: AnimatedSwitcher(
                        duration: NxTiming.page,
                        child: NxImage(key: ValueKey(p.art), url: p.art, radius: 19, fallbackIcon: LucideIcons.music),
                      ),
                    ),
                    SizedBox(width: compact ? 8 : 10),
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
                              style: NxText.sans(size: compact ? 11 : 12, color: c.ink3),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (p.isPlaying && !compact)
                      const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: NxEqualiser()),
                    NxIconButton(
                      p.isPlaying ? LucideIcons.pause : LucideIcons.play,
                      tooltip: p.isPlaying ? 'Pause' : 'Play',
                      size: 36,
                      color: c.ink,
                      onPressed: p.busy ? null : player.toggle,
                    ),
                    if (!compact)
                      NxIconButton(
                        LucideIcons.skipForward,
                        tooltip: 'Next track',
                        size: 36,
                        color: c.ink,
                        onPressed: p.busy ? null : player.next,
                      ),
                  ],
                ),
              ),
              Positioned(
                left: 24,
                right: 24,
                bottom: 0,
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
  const new({super.key});

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
    final still = (MediaQuery.maybeDisableAnimationsOf(context) ?? false) || !TickerMode.valuesOf(context).enabled;
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
