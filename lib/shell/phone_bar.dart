import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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

typedef _TabItem = ({IconData icon, String label, bool active, bool navigates, VoidCallback onTap});

/// Tabs on a glass lens you can tap or drag. While held the lens lifts,
/// follows the finger and stretches with its speed; released, it springs
/// (with a little wobble) onto the nearest tab and opens it.
class _TabBar extends StatefulWidget {
  const new({required this.location, required this.collapsed, required this.fullWidth, required this.onExpand});

  final String location;
  final bool collapsed;
  final double fullWidth;
  final VoidCallback onExpand;

  @override
  State<_TabBar> createState() => _TabBarState();
}

class _TabBarState extends State<_TabBar> with TickerProviderStateMixin {
  static const _pad = 4.0;
  static final _count = Nav.phoneTabs.length + 1;

  /// Tight, near-critical chase while the finger leads.
  static const _follow = SpringDescription(mass: 1, stiffness: 900, damping: 51);

  /// Looser and underdamped for the landing, so the glass wobbles once.
  static const _settle = SpringDescription(mass: 1, stiffness: 520, damping: 28);

  /// Lens left edge, in tab-bar coordinates, and its speed (px/s).
  late final _x = ValueNotifier(_leftFor(_activeIndex(_items())));
  double _velocity = 0;
  late double _target = _x.value;
  SpringDescription _spring = _settle;

  /// One long-running ticker integrates the spring, so a drag can retarget
  /// it every pointer event without restarting (and stalling) the motion.
  late final _ticker = createTicker(_tick);
  Duration _lastTick = Duration.zero;
  late final _lift = AnimationController(vsync: this, duration: NxTiming.fast, reverseDuration: NxTiming.base);

  /// The tab under the lens while it is being dragged.
  int? _hover;
  double _grab = 0;

  double get _tabWidth => (widget.fullWidth - _pad * 2) / _count;
  double _leftFor(int i) => _pad + i * _tabWidth;
  int _indexAt(double left) => ((left - _pad + _tabWidth / 2) / _tabWidth).floor().clamp(0, _count - 1);
  int _activeIndex(List<_TabItem> items) => items.indexWhere((t) => t.active);

  List<_TabItem> _items() {
    final tabs = [
      for (final d in Nav.phoneTabs)
        (
          icon: d.icon,
          label: d.label,
          active: Nav.isActive(d, widget.location),
          navigates: true,
          onTap: () => context.go(d.to),
        ),
    ];
    return [
      ...tabs,
      (
        icon: LucideIcons.sparkles,
        label: 'More',
        active: !tabs.any((t) => t.active),
        navigates: false,
        onTap: () => showMoreSheet(context, widget.location),
      ),
    ];
  }

  @override
  void didUpdateWidget(_TabBar old) {
    super.didUpdateWidget(old);
    if (_hover != null) return;
    final target = _leftFor(_activeIndex(_items()));
    if (old.fullWidth != widget.fullWidth) {
      _jumpTo(target);
    } else if (old.location != widget.location) {
      _springTo(target, _settle);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _x.dispose();
    _lift.dispose();
    super.dispose();
  }

  void _jumpTo(double target) {
    _ticker.stop();
    _target = target;
    _velocity = 0;
    _x.value = target;
  }

  void _springTo(double target, SpringDescription spring) {
    if (reduceMotion(context)) return _jumpTo(target);
    _target = target;
    _spring = spring;
    if (!_ticker.isActive) {
      _lastTick = Duration.zero;
      _ticker.start();
    }
  }

  void _tick(Duration elapsed) {
    final dt = math.min((elapsed - _lastTick).inMicroseconds / 1e6, 1 / 30);
    _lastTick = elapsed;
    if (dt <= 0) return;
    var x = _x.value;
    const steps = 4;
    final h = dt / steps;
    for (var i = 0; i < steps; i++) {
      final accel = (_spring.stiffness * (_target - x) - _spring.damping * _velocity) / _spring.mass;
      _velocity += accel * h;
      x += _velocity * h;
    }
    if ((x - _target).abs() < .05 && _velocity.abs() < 2) {
      _ticker.stop();
      x = _target;
      _velocity = 0;
    }
    _x.value = x;
  }

  void _dragStart(DragStartDetails d) {
    final x = d.localPosition.dx;
    final onLens = x >= _x.value && x <= _x.value + _tabWidth;
    _grab = onLens ? x - _x.value : _tabWidth / 2;
    _lift.forward();
    setState(() => _hover = _indexAt(x - _grab));
    _dragTo(x);
  }

  void _dragTo(double x) {
    final min = _leftFor(0);
    final max = _leftFor(_count - 1);
    var left = x - _grab;
    // Rubber-band past the ends instead of stopping dead.
    if (left < min) left = min - math.min((min - left) * .3, 14);
    if (left > max) left = max + math.min((left - max) * .3, 14);
    _springTo(left, _follow);
    final i = _indexAt(left);
    if (i != _hover) {
      unawaited(HapticFeedback.selectionClick());
      setState(() => _hover = i);
    }
  }

  void _dragEnd(double velocity) {
    final items = _items();
    final projected = (_target + velocity * .08).clamp(_leftFor(0), _leftFor(_count - 1));
    final item = items[_indexAt(projected)];
    _lift.reverse();
    setState(() => _hover = null);
    _springTo(_leftFor(item.navigates || item.active ? items.indexOf(item) : _activeIndex(items)), _settle);
    if (!item.active) {
      unawaited(HapticFeedback.lightImpact());
      item.onTap();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    final items = _items();
    final active = _activeIndex(items);
    final reduce = reduceMotion(context);
    final collapsed = widget.collapsed;
    final fade = reduce ? Duration.zero : NxTiming.fast;

    return NxGlass(
      child: GestureDetector(
        onHorizontalDragStart: collapsed ? null : _dragStart,
        onHorizontalDragUpdate: collapsed ? null : (d) => _dragTo(d.localPosition.dx),
        onHorizontalDragEnd: collapsed ? null : (d) => _dragEnd(d.velocity.pixelsPerSecond.dx),
        onHorizontalDragCancel: collapsed ? null : () => _dragEnd(0),
        child: Stack(
          fit: StackFit.expand,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(end: collapsed ? 1 : 0),
              duration: reduce ? Duration.zero : PhoneBar.springDuration,
              curve: PhoneBar.spring,
              builder: (context, t, _) => AnimatedBuilder(
                animation: Listenable.merge([_x, _lift]),
                builder: (context, _) {
                  final speed = reduce ? 0.0 : _velocity.abs();
                  final lift = _lift.value;
                  const collapsedWidth = PhoneBar.dockHeight - _pad * 2;
                  return Positioned(
                    top: _pad,
                    bottom: _pad,
                    left: _x.value + (_pad - _x.value) * t,
                    width: _tabWidth + (collapsedWidth - _tabWidth) * t,
                    child: Transform(
                      alignment: Alignment.center,
                      // Squash and stretch: wider and flatter the faster it moves.
                      transform: Matrix4.diagonal3Values(
                        1 + math.min(speed / 2400, .4) + lift * .1,
                        1 - math.min(speed / 5000, .14) + lift * .12,
                        1,
                      ),
                      child: NxGlassLens(lift: lift),
                    ),
                  );
                },
              ),
            ),
            IgnorePointer(
              ignoring: collapsed,
              child: AnimatedOpacity(
                opacity: collapsed ? 0 : 1,
                duration: fade,
                child: OverflowBox(
                  alignment: Alignment.centerLeft,
                  minWidth: widget.fullWidth,
                  maxWidth: widget.fullWidth,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: _pad),
                    child: Row(
                      children: [
                        for (final (i, t) in items.indexed)
                          _Tab(
                            icon: t.icon,
                            label: t.label,
                            active: _hover == null ? t.active : i == _hover,
                            onTap: t.onTap,
                          ),
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
                    onTap: widget.onExpand,
                    scale: .9,
                    child: Center(child: Icon(items[active].icon, size: 22, color: c.acc)),
                  ),
                ),
              ),
            ),
          ],
        ),
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
              FittedBox(
                fit: BoxFit.scaleDown,
                child: AnimatedDefaultTextStyle(
                  duration: NxTiming.base,
                  style: NxText.sans(size: 10.5, weight: FontWeight.w600, color: color),
                  child: Text(widget.label, maxLines: 1),
                ),
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
