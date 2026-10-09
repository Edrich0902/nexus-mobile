import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

bool reduceMotion(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Rise-in entrance (web `.nx-rise`): fades up from [distance] px. Plays once
/// when mounted; pass [index] to stagger siblings. With [animate] false it
/// mounts already settled (the tree shape stays the same either way, so
/// flipping it never rebuilds [child]).
class NxRise extends StatelessWidget {
  const NxRise({
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
  const NxSwitcher({required this.child, this.alignment = Alignment.topCenter, super.key});

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
  const NxShake({required this.trigger, required this.child, super.key});

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
  const NxCountUp(this.value, {required this.style, super.key});

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
