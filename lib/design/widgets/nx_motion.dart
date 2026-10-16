import 'dart:math' as math;

import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nexus_mobile/design/tokens.g.dart';

/// UI timings on top of the generated web [NxMotion] tokens: quick for
/// controls, a little longer for content arriving, staggered for lists.
abstract final class NxTiming {
  static const fast = Duration(milliseconds: 150);
  static const base = Duration(milliseconds: 240);
  static const page = Duration(milliseconds: 360);
  static const rise = Duration(milliseconds: 460);
  static const count = Duration(milliseconds: 900);
  static const stagger = Duration(milliseconds: 45);

  /// Items past this index arrive together instead of queueing up.
  static const maxStagger = 8;

  static const exit = Curves.easeInCubic;
  static const settle = Curves.easeOutCubic;
}

/// Shared spring used by the tab lens, presses and active-state pops so
/// every control feels like the same glass.
abstract final class NxSpring {
  static const curve = Cubic(.32, 1.25, .45, 1);
  static const duration = Duration(milliseconds: 550);
  static const pop = Duration(milliseconds: 420);
}

/// Mobile control tap timelines. Every icon button uses these so toggles and
/// momentary actions feel like the same glass family as the tab bar.
///
/// - [activate]: turning something on — press in → bloom → spring settle
/// - [action]: a one-shot (skip, queue, search) — press in → short kick settle
abstract final class NxTapMotion {
  static const activate = Duration(milliseconds: 560);
  static const action = Duration(milliseconds: 420);

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  /// Scale for an activate clip (like, shuffle on, repeat on).
  static double activateScale(double t) {
    if (t < .22) return _lerp(1, .86, Curves.easeOut.transform(t / .22));
    if (t < .5) return _lerp(.86, 1.38, Curves.easeOut.transform((t - .22) / .28));
    return _lerp(1.38, 1, Curves.elasticOut.transform((t - .5) / .5));
  }

  /// Accent fill / solid-icon progress during [activateScale].
  static double activateFill(double t) {
    if (t < .18) return 0;
    if (t < .48) return Curves.easeOut.transform((t - .18) / .3);
    return 1;
  }

  /// Scale for a momentary action clip (skip, open sheet, camera…).
  static double actionScale(double t) {
    if (t < .28) return _lerp(1, .88, Curves.easeOut.transform(t / .28));
    if (t < .55) return _lerp(.88, 1.16, Curves.easeOut.transform((t - .28) / .27));
    return _lerp(1.16, 1, NxSpring.curve.transform((t - .55) / .45));
  }
}

bool reduceMotion(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// A quick overshoot pop (1 → 1.28 → 1), the same beat as an active tab.
/// Plays when [active] becomes true, or when [trigger] changes to a new
/// non-null value.
class NxPop extends StatefulWidget {
  const new({required this.child, this.active, this.trigger, this.peak = 1.28, super.key});

  final Widget child;
  final bool? active;
  final Object? trigger;

  /// How far the pop overshoots before settling.
  final double peak;

  @override
  State<NxPop> createState() => _NxPopState();
}

class _NxPopState extends State<NxPop> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: NxSpring.pop);
  late final Animation<double> _scale = _buildScale(widget.peak);

  Animation<double> _buildScale(double peak) => TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(begin: 1, end: peak).chain(CurveTween(curve: Curves.easeOut)),
      weight: 35,
    ),
    TweenSequenceItem(
      tween: Tween<double>(begin: peak, end: 1).chain(CurveTween(curve: Curves.elasticOut)),
      weight: 65,
    ),
  ]).animate(_c);

  void _play() {
    if (!reduceMotion(context)) _c.forward(from: 0);
  }

  @override
  void didUpdateWidget(NxPop old) {
    super.didUpdateWidget(old);
    if (widget.active == true && old.active != true) {
      _play();
    } else if (widget.trigger != null && widget.trigger != old.trigger) {
      _play();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(scale: _scale, child: widget.child);
}

/// Rise-in entrance (web `.nx-rise`): fades up from [distance] px. Plays once
/// when mounted; pass [index] to stagger siblings. With [animate] false it
/// mounts already settled (the tree shape stays the same either way, so
/// flipping it never rebuilds [child]).
class NxRise extends StatelessWidget {
  const new({
    required this.child,
    this.delay = Duration.zero,
    this.index = 0,
    this.distance = 10,
    this.duration = NxTiming.rise,
    this.animate = true,
    super.key,
  });

  final Widget child;
  final Duration delay;
  final int index;
  final double distance;
  final Duration duration;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final still = !animate || reduceMotion(context);
    final wait = delay + NxTiming.stagger * math.min(index, NxTiming.maxStagger);
    final total = duration + wait;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: still ? 1 : 0, end: 1),
      duration: total,
      curve: Interval(wait.inMicroseconds / total.inMicroseconds, 1, curve: NxMotion.ease),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, distance * (1 - t)), child: child),
      ),
      child: child,
    );
  }
}

/// Swaps between states (loading → content, idle → error): the old child
/// fades out quickly, then the new one rises in — never both at once. Give
/// each state a distinct key; same-key rebuilds don't animate.
class NxSwitcher extends StatelessWidget {
  const new({required this.child, this.alignment = Alignment.topCenter, super.key});

  /// Share of the entrance spent waiting for the outgoing child (which takes
  /// [NxTiming.fast]) to clear.
  static final _handover = NxTiming.fast.inMicroseconds / (NxTiming.fast + NxTiming.rise).inMicroseconds;

  final Widget child;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return child;
    return AnimatedSwitcher(
      duration: NxTiming.fast + NxTiming.rise,
      reverseDuration: NxTiming.fast,
      switchInCurve: Interval(_handover, 1, curve: NxMotion.ease),
      switchOutCurve: NxTiming.exit,
      layoutBuilder: (current, previous) => Stack(alignment: alignment, children: [...previous, ?current]),
      transitionBuilder: (child, animation) => AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, child) => Opacity(
          opacity: animation.value,
          child: Transform.translate(offset: Offset(0, 8 * (1 - animation.value)), child: child),
        ),
      ),
      child: child,
    );
  }
}

/// Shakes [child] side to side whenever [trigger] changes to a new non-null
/// value: the "that didn't work" nudge for a rejected form.
class NxShake extends StatefulWidget {
  const new({required this.trigger, required this.child, super.key});

  final Object? trigger;
  final Widget child;

  @override
  State<NxShake> createState() => _NxShakeState();
}

class _NxShakeState extends State<NxShake> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 460));

  @override
  void didUpdateWidget(NxShake old) {
    super.didUpdateWidget(old);
    if (widget.trigger != null && widget.trigger != old.trigger && !reduceMotion(context)) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    child: widget.child,
    builder: (context, child) {
      final t = _c.value;
      return Transform.translate(offset: Offset(math.sin(t * math.pi * 6) * 9 * (1 - t), 0), child: child);
    },
  );
}

/// A grouped integer ("1,204") that counts up the first time it's shown and
/// glides to new values after. Anything non-numeric ("4d", "—") renders as is.
class NxCountUp extends StatelessWidget {
  const new(this.value, {required this.style, super.key});

  final String value;
  final TextStyle style;

  static final _grouped = RegExp(r'^\d{1,3}(,\d{3})*$|^\d+$');
  static final _format = NumberFormat.decimalPattern();

  @override
  Widget build(BuildContext context) {
    final target = _grouped.hasMatch(value) ? int.tryParse(value.replaceAll(',', '')) : null;
    if (target == null || target == 0 || reduceMotion(context)) return Text(value, style: style);
    return Semantics(
      label: value,
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: target.toDouble()),
        duration: NxTiming.count,
        curve: NxTiming.settle,
        builder: (context, v, _) => Text(_format.format(v.round()), style: style),
      ),
    );
  }
}
