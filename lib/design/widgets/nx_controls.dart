import 'dart:async';

import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nexus_mobile/design/colors.dart';
import 'package:nexus_mobile/design/tokens.g.dart';
import 'package:nexus_mobile/design/typography.dart';
import 'package:nexus_mobile/design/widgets/nx_glass.dart';
import 'package:nexus_mobile/design/widgets/nx_motion.dart';

/// Scale-down press feedback used by every tappable card (web `:hover`
/// scale(.985) translated to touch).
class NxPressable extends StatefulWidget {
  const new({
    required this.onTap,
    required this.child,
    this.onLongPress,
    this.scale = .975,
    this.semanticLabel,
    super.key,
  });

  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Widget child;
  final double scale;

  /// Overrides the label read by screen readers (defaults to the child's text).
  final String? semanticLabel;

  @override
  State<NxPressable> createState() => _NxPressableState();
}

class _NxPressableState extends State<NxPressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap();
      },
      onLongPress: widget.onLongPress,
      child: Semantics(
        button: true,
        label: widget.semanticLabel,
        excludeSemantics: widget.semanticLabel != null,
        child: AnimatedScale(
          scale: _down && !reduce ? widget.scale : 1,
          duration: reduce ? Duration.zero : (_down ? NxTiming.fast : NxSpring.duration),
          curve: _down ? Curves.easeOut : NxSpring.curve,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Pulsing accent dot (live / playing).
class NxLiveDot extends StatefulWidget {
  const new({this.color, this.size = 8, super.key});

  final Color? color;
  final double size;

  @override
  State<NxLiveDot> createState() => _NxLiveDotState();
}

/// Rests solid and gives a short breath every [period]; a continuous pulse
/// would keep the screen redrawing every frame for as long as it's visible.
class _NxLiveDotState extends State<NxLiveDot> with SingleTickerProviderStateMixin {
  static const period = Duration(milliseconds: 2800);
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  late final Animation<double> _opacity = TweenSequence<double>([
    TweenSequenceItem(tween: Tween<double>(begin: 1, end: .3).chain(CurveTween(curve: Curves.easeOut)), weight: 40),
    TweenSequenceItem(tween: Tween<double>(begin: .3, end: 1).chain(CurveTween(curve: Curves.easeInOut)), weight: 60),
  ]).animate(_c);
  Timer? _timer;
  var _still = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = (MediaQuery.maybeDisableAnimationsOf(context) ?? false) || !TickerMode.valuesOf(context).enabled;
    if (_still) {
      _timer?.cancel();
      _timer = null;
      _c.value = 0;
    } else {
      _timer ??= Timer.periodic(period, (_) => _c.forward(from: 0));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color ?? context.nx.acc),
    );
    if (_still) return dot;
    return RepaintBoundary(
      child: FadeTransition(opacity: _opacity, child: dot),
    );
  }
}

class NxProgressRail extends StatelessWidget {
  const new({required this.value, this.color, this.track, this.height = 3, super.key});

  final double value;
  final Color? color;
  final Color? track;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    return Semantics(
      value: '${(value.clamp(0, 1) * 100).round()}%',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: track ?? c.line),
              FractionallySizedBox(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: value.clamp(0, 1).toDouble(),
                child: ColoredBox(color: color ?? c.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small filled/empty pip row (web NxPips), e.g. sweetness 3/5.
class NxPips extends StatelessWidget {
  const new({required this.value, this.max = 5, this.color, super.key});

  final int value;
  final int max;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final on = color ?? context.nx.acc;
    return Semantics(
      label: '$value of $max',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < max; i++)
            Container(
              width: 18,
              height: 6,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: i < value ? on : on.withValues(alpha: .2),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
        ],
      ),
    );
  }
}

enum NxButtonVariant { primary, secondary, ghost, danger, accent }

/// Pill button (web `.btn` / PrimeVue pill actions).
class NxButton extends StatelessWidget {
  const new(
    this.label, {
    required this.onPressed,
    this.icon,
    this.variant = NxButtonVariant.primary,
    this.wide = false,
    this.loading = false,
    this.compact = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final NxButtonVariant variant;
  final bool wide;
  final bool loading;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    final (Color bg, Color fg) = switch (variant) {
      NxButtonVariant.primary => (c.ink, c.amb),
      NxButtonVariant.secondary => (c.tint2, c.ink),
      NxButtonVariant.ghost => (Colors.transparent, c.ink2),
      NxButtonVariant.danger => (NexusColors.bad, Color.lerp(NexusColors.bad, Colors.black, .85)!),
      NxButtonVariant.accent => (c.acc, c.amb),
    };
    final disabled = onPressed == null || loading;
    final height = wide ? 50.0 : (compact ? 36.0 : 42.0);
    final leading = loading
        ? SizedBox(
            key: const ValueKey('loading'),
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        : icon == null
        ? null
        : Icon(icon, key: ValueKey(icon), size: 17, color: fg);
    final child = AnimatedOpacity(
      opacity: disabled && !loading ? .45 : 1,
      duration: NxMotion.hover,
      child: Container(
        height: height,
        width: wide ? double.infinity : null,
        padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 18),
        decoration: variant == NxButtonVariant.ghost
            ? null
            : ShapeDecoration(
                color: bg,
                shape: NxGlassBorder.raised(c, radius: NxRadius.pill),
              ),
        child: Row(
          mainAxisSize: wide ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSize(
              duration: NxTiming.base,
              curve: NxMotion.ease,
              child: AnimatedSwitcher(
                duration: NxTiming.base,
                switchInCurve: NxMotion.ease,
                transitionBuilder: (child, a) => FadeTransition(
                  opacity: a,
                  child: ScaleTransition(scale: a, child: child),
                ),
                child: leading == null
                    ? const SizedBox.shrink(key: ValueKey('none'))
                    : Padding(key: leading.key, padding: const EdgeInsets.only(right: 8), child: leading),
              ),
            ),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: NxText.sans(size: wide ? 15 : 14, weight: FontWeight.w600, color: fg),
              ),
            ),
          ],
        ),
      ),
    );
    return Semantics(
      button: true,
      enabled: !disabled,
      label: label,
      excludeSemantics: true,
      child: disabled ? child : NxPressable(onTap: onPressed!, scale: .96, child: child),
    );
  }
}

/// Glass icon control — the mobile standard for round icon buttons.
///
/// Pass [active] for toggles (like, shuffle, repeat): turning on plays the
/// shared press→bloom→settle clip and keeps an accent glass fill while on.
/// Omit [active] for momentary actions (skip, queue, search): each tap plays
/// a shorter press→kick→settle clip with no fill.
class NxIconButton extends StatefulWidget {
  const new(
    this.icon, {
    required this.onPressed,
    required this.tooltip,
    this.active,
    this.mode,
    this.size = 40,
    this.color,
    this.badge = false,
    this.filled = false,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;

  /// Non-null means this is a toggle. Accent glass while true; bloom clip
  /// when it becomes true.
  final bool? active;

  /// When set, a change while [active] stays true re-plays the activate bloom
  /// (e.g. Spotify repeat cycling `context` → `track`).
  final Object? mode;

  final double size;

  /// Accent used when [active] is true (defaults to the ambient accent).
  final Color? color;

  final bool badge;

  /// Legacy: force a filled glass look when not using [active]. Prefer [active].
  final bool filled;

  @override
  State<NxIconButton> createState() => _NxIconButtonState();
}

class _NxIconButtonState extends State<NxIconButton> with SingleTickerProviderStateMixin {
  late final _tap = AnimationController(vsync: this)..addStatusListener(_onTapStatus);

  /// True while an activate bloom we started is still running.
  bool _blooming = false;

  bool get _toggle => widget.active != null;
  bool get _on => widget.active ?? false;

  void _onTapStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _blooming && mounted) {
      setState(() => _blooming = false);
    }
  }

  void _playBloom() {
    if (reduceMotion(context)) return;
    _blooming = true;
    _tap.duration = NxTapMotion.activate;
    _tap.forward(from: 0);
  }

  @override
  void dispose() {
    _tap
      ..removeStatusListener(_onTapStatus)
      ..dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(NxIconButton old) {
    super.didUpdateWidget(old);
    if (!_toggle) return;
    // Parent flipped us off while a bloom was mid-flight.
    if (old.active == true && widget.active == false) {
      _blooming = false;
      _tap.value = 0;
      return;
    }
    // Still on, but mode changed (repeat context → track).
    if (old.active == true && widget.active == true && widget.mode != null && widget.mode != old.mode && !_blooming) {
      unawaited(HapticFeedback.lightImpact());
      _playBloom();
    }
  }

  Future<void> _handleTap() async {
    final action = widget.onPressed;
    if (action == null || _tap.isAnimating) return;

    final turningOn = _toggle && widget.active == false;
    final reduce = reduceMotion(context);

    if (!reduce) {
      if (turningOn) {
        await HapticFeedback.lightImpact();
        _playBloom();
      } else if (!_toggle) {
        _tap.duration = NxTapMotion.action;
        await HapticFeedback.selectionClick();
        _tap.forward(from: 0);
      } else {
        // Already on — may turn off (shuffle) or cycle mode (repeat). Soft
        // click now; [mode] change while still active re-blooms above.
        await HapticFeedback.selectionClick();
      }
    }

    action();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    final tone = widget.color ?? c.acc;
    final enabled = widget.onPressed != null;

    return Semantics(
      button: true,
      enabled: enabled,
      selected: widget.active,
      label: widget.tooltip,
      excludeSemantics: true,
      child: Tooltip(
        message: widget.tooltip,
        triggerMode: TooltipTriggerMode.longPress,
        child: Opacity(
          opacity: enabled ? 1 : .4,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? _handleTap : null,
            child: AnimatedBuilder(
              animation: _tap,
              builder: (context, _) {
                final t = _tap.value;
                final playing = _tap.isAnimating || (t > 0 && t < 1);

                late final double fill;
                late final double scale;
                if (_toggle) {
                  if (_blooming) {
                    fill = NxTapMotion.activateFill(t);
                    scale = NxTapMotion.activateScale(t);
                  } else {
                    fill = _on || widget.filled ? 1.0 : 0.0;
                    scale = 1.0;
                  }
                } else {
                  fill = widget.filled ? 1.0 : 0.0;
                  scale = playing ? NxTapMotion.actionScale(t) : 1.0;
                }

                // Toggles (and colored fills) use the accent glass; bare
                // `filled: true` keeps the neutral glass capsule.
                final accented = _toggle || widget.color != null;
                final iconColor = accented
                    ? (Color.lerp(c.ink2, tone, fill) ?? tone)
                    : (widget.filled ? c.ink : c.ink2);
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    alignment: Alignment.center,
                    decoration: fill <= 0
                        ? null
                        : ShapeDecoration(
                            color: accented ? tone.withValues(alpha: .22 * fill) : c.tint2,
                            shape: accented
                                ? NxGlassBorder.solid(
                                    tone.withValues(alpha: .55 * fill),
                                    radius: NxRadius.pill,
                                    width: 1,
                                  )
                                : NxGlassBorder.raised(c, radius: NxRadius.pill),
                          ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        Icon(widget.icon, size: widget.size * .48, color: iconColor),
                        if (widget.badge)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(color: c.acc, shape: BoxShape.circle),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Toggle chip (web `.chip`, NxChips).
class NxChip extends StatelessWidget {
  const new(this.label, {this.selected = false, this.onTap, this.icon, this.color, super.key});

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    final on = color ?? c.acc;
    final chip = AnimatedContainer(
      duration: NxMotion.hover,
      curve: NxMotion.ease,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: ShapeDecoration(
        color: selected ? on : c.tint,
        shape: selected
            ? NxGlassBorder.solid(on, radius: NxRadius.pill, width: 1)
            : NxGlassBorder.raised(c, radius: NxRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: selected ? c.amb : c.ink2), const SizedBox(width: 6)],
          Text(
            label,
            style: NxText.sans(
              size: 13,
              weight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? c.amb : c.ink2,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
    return Semantics(
      button: onTap != null,
      selected: selected,
      child: onTap == null ? chip : NxPressable(onTap: onTap!, scale: .94, child: chip),
    );
  }
}

/// Horizontally scrolling chip row that bleeds to the screen edge.
class NxChipRow extends StatelessWidget {
  const new({required this.children, this.bleed = 20, super.key});

  final List<Widget> children;
  final double bleed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: OverflowBox(
        maxWidth: MediaQuery.sizeOf(context).width,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: bleed),
          itemCount: children.length,
          separatorBuilder: (_, _) => const SizedBox(width: 6),
          itemBuilder: (_, i) => Center(child: children[i]),
        ),
      ),
    );
  }
}

/// An unselected pill: [nxLens] faded out, so the selection animates.
const _clearLens = ShapeDecoration(
  shape: NxGlassBorder(
    colors: [Colors.transparent, Colors.transparent, Colors.transparent, Colors.transparent],
    radius: NxRadius.pill,
  ),
);

/// Segmented pill nav (web NxPillNav / NxPillGroup).
class NxPillNav<T> extends StatelessWidget {
  const new({required this.items, required this.value, required this.onChanged, this.expand = false, super.key});

  final List<(T, String)> items;
  final T value;
  final ValueChanged<T> onChanged;

  /// Equal segments across the full width with a sliding selection, for a
  /// handful of short labels; otherwise the pills scroll horizontally.
  final bool expand;

  void _select(T v) {
    HapticFeedback.selectionClick();
    onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    if (expand) return _segmented(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: nxWell(c, radius: NxRadius.pill),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (v, label) in items)
              Semantics(
                selected: v == value,
                button: true,
                child: GestureDetector(
                  onTap: () => _select(v),
                  child: AnimatedContainer(
                    duration: NxMotion.hover,
                    curve: NxMotion.ease,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: v == value ? nxLens(c) : _clearLens,
                    child: Text(
                      label,
                      style: NxText.sans(size: 13, weight: FontWeight.w600, color: v == value ? c.ink : c.ink3),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _segmented(BuildContext context) {
    final c = context.nx;
    final selected = items.indexWhere((e) => e.$1 == value);
    return Container(
      height: 42,
      padding: const EdgeInsets.all(4),
      decoration: nxWell(c, radius: NxRadius.pill),
      child: LayoutBuilder(
        builder: (context, box) {
          final width = box.maxWidth / items.length;
          return Stack(
            children: [
              if (selected >= 0)
                AnimatedPositioned(
                  duration: NxTiming.base,
                  curve: NxMotion.ease,
                  left: selected * width,
                  top: 0,
                  bottom: 0,
                  width: width,
                  child: const NxGlassLens(),
                ),
              Row(
                children: [
                  for (final (i, (v, label)) in items.indexed)
                    Expanded(
                      child: Semantics(
                        selected: i == selected,
                        button: true,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _select(v),
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: NxTiming.base,
                              style: NxText.sans(
                                size: 13,
                                weight: FontWeight.w600,
                                color: i == selected ? c.ink : c.ink3,
                              ),
                              child: Text(label, maxLines: 1, overflow: TextOverflow.fade, softWrap: false),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class NxSearchField extends StatelessWidget {
  const new({
    this.controller,
    this.hint = 'Search',
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.focusNode,
    this.trailing,
    super.key,
  });

  final TextEditingController? controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final FocusNode? focusNode;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: nxWell(c, radius: 16),
      child: Row(
        children: [
          Icon(LucideIcons.search, size: 18, color: c.ink3),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: autofocus,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              textInputAction: TextInputAction.search,
              style: NxText.sans(size: 16, color: c.ink),
              decoration: InputDecoration(
                hintText: hint,
                filled: false,
                isCollapsed: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Labelled form input (web `.nx-form .f`).
class NxTextField extends StatelessWidget {
  const new({
    required this.label,
    this.controller,
    this.hint,
    this.error,
    this.keyboardType,
    this.obscure = false,
    this.maxLines = 1,
    this.autofillHints,
    this.textInputAction,
    this.onSubmitted,
    this.autofocus = false,
    this.onChanged,
    super.key,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? error;
  final TextInputType? keyboardType;
  final bool obscure;
  final int maxLines;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: NxText.label(context)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscure,
          maxLines: obscure ? 1 : maxLines,
          autofillHints: autofillHints,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          onChanged: onChanged,
          autofocus: autofocus,
          style: NxText.sans(size: 15.5, color: c.ink),
          decoration: InputDecoration(hintText: hint, errorText: error),
        ),
      ],
    );
  }
}

/// Read-only star rating with numeric value (web NxRating).
class NxRating extends StatelessWidget {
  const new(this.value, {this.size = 13, super.key});

  final double? value;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (value == null) return const SizedBox.shrink();
    final c = context.nx;
    return Semantics(
      label: 'Rated ${value!.toStringAsFixed(1)} out of 5',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: size + 2, color: c.acc),
          const SizedBox(width: 3),
          Text(
            value! % 1 == 0 ? value!.toStringAsFixed(0) : value!.toStringAsFixed(1),
            style: NxText.sans(size: size, weight: FontWeight.w600, color: c.ink2),
          ),
        ],
      ),
    );
  }
}

/// Tap / half-tap star input (0.5 steps), used in capture review and detail.
class NxRatingInput extends StatelessWidget {
  const new({required this.value, required this.onChanged, this.size = 30, super.key});

  final double? value;
  final ValueChanged<double?> onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    final v = value ?? 0;
    return Semantics(
      label: 'Rating',
      value: value == null ? 'none' : '${v.toStringAsFixed(1)} of 5',
      increasedValue: '${(v + .5).clamp(.5, 5)}',
      decreasedValue: '${(v - .5).clamp(0, 5)}',
      onIncrease: () => onChanged((v + .5).clamp(.5, 5).toDouble()),
      onDecrease: () => onChanged(v - .5 <= 0 ? null : v - .5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++)
            GestureDetector(
              onTapUp: (d) {
                HapticFeedback.selectionClick();
                final half = d.localPosition.dx < size / 2;
                final next = half ? i - .5 : i.toDouble();
                onChanged(next == value ? null : next);
              },
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(
                  v >= i ? Icons.star_rounded : (v >= i - .5 ? Icons.star_half_rounded : Icons.star_outline_rounded),
                  size: size,
                  color: v >= i - .5 ? c.acc : c.tint2,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Settings-style row (account sheet, profile).
class NxListRow extends StatelessWidget {
  const new({
    required this.label,
    this.icon,
    this.onTap,
    this.trailing,
    this.detail,
    this.destructive = false,
    super.key,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final Widget? trailing;
  final String? detail;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    final color = destructive ? NexusColors.bad : c.ink2;
    return Semantics(
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(NxRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Row(
            children: [
              if (icon != null) ...[Icon(icon, size: 19, color: color), const SizedBox(width: 12)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: NxText.sans(size: 15, color: destructive ? NexusColors.bad : c.ink)),
                    if (detail != null) Text(detail!, style: NxText.sans(size: 12.5, color: c.ink3)),
                  ],
                ),
              ),
              trailing ?? (onTap != null ? Icon(LucideIcons.chevronRight, size: 18, color: c.ink3) : const SizedBox()),
            ],
          ),
        ),
      ),
    );
  }
}
