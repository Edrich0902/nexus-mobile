import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nexus_mobile/design/colors.dart';
import 'package:nexus_mobile/design/tokens.g.dart';
import 'package:nexus_mobile/design/typography.dart';

/// Scale-down press feedback used by every tappable card (web `:hover`
/// scale(.985) translated to touch).
class NxPressable extends StatefulWidget {
  const NxPressable({
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
          duration: reduce ? Duration.zero : const Duration(milliseconds: 160),
          curve: NxMotion.ease,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Pulsing accent dot (live / playing).
class NxLiveDot extends StatefulWidget {
  const NxLiveDot({this.color, this.size = 8, super.key});

  final Color? color;
  final double size;

  @override
  State<NxLiveDot> createState() => _NxLiveDotState();
}

class _NxLiveDotState extends State<NxLiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
    ..repeat(reverse: true);

  @override
  void dispose() {
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
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return dot;
    return FadeTransition(opacity: Tween<double>(begin: 1, end: .35).animate(_c), child: dot);
  }
}

class NxProgressRail extends StatelessWidget {
  const NxProgressRail({required this.value, this.color, this.track, this.height = 3, super.key});

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
            children: [
              Positioned.fill(child: ColoredBox(color: track ?? c.line)),
              FractionallySizedBox(
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
  const NxPips({required this.value, this.max = 5, this.color, super.key});

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
  const NxButton(
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
    final child = AnimatedOpacity(
      opacity: disabled && !loading ? .45 : 1,
      duration: NxMotion.hover,
      child: Container(
        height: height,
        width: wide ? double.infinity : null,
        padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 18),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(NxRadius.pill)),
        child: Row(
          mainAxisSize: wide ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
            else if (icon != null)
              Icon(icon, size: 17, color: fg),
            if (loading || icon != null) const SizedBox(width: 8),
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

class NxIconButton extends StatelessWidget {
  const NxIconButton(
    this.icon, {
    required this.onPressed,
    required this.tooltip,
    this.filled = false,
    this.size = 40,
    this.color,
    this.badge = false,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final bool filled;
  final double size;
  final Color? color;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    final btn = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: filled ? c.tint2 : Colors.transparent),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, size: size * .48, color: color ?? (filled ? c.ink : c.ink2)),
          if (badge)
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
    );
    return Semantics(
      button: true,
      label: tooltip,
      excludeSemantics: true,
      child: Tooltip(
        message: tooltip,
        triggerMode: TooltipTriggerMode.longPress,
        child: onPressed == null
            ? Opacity(opacity: .4, child: btn)
            : NxPressable(onTap: onPressed!, scale: .9, child: btn),
      ),
    );
  }
}

/// Toggle chip (web `.chip`, NxChips).
class NxChip extends StatelessWidget {
  const NxChip(this.label, {this.selected = false, this.onTap, this.icon, this.color, super.key});

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
      decoration: BoxDecoration(
        color: selected ? on : c.tint,
        borderRadius: BorderRadius.circular(NxRadius.pill),
        border: Border.all(color: selected ? on : c.line),
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
      child: onTap == null ? chip : GestureDetector(onTap: onTap, child: chip),
    );
  }
}

/// Horizontally scrolling chip row that bleeds to the screen edge.
class NxChipRow extends StatelessWidget {
  const NxChipRow({required this.children, this.bleed = 20, super.key});

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

/// Segmented pill nav (web NxPillNav / NxPillGroup).
class NxPillNav<T> extends StatelessWidget {
  const NxPillNav({required this.items, required this.value, required this.onChanged, super.key});

  final List<(T, String)> items;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: c.tint, borderRadius: BorderRadius.circular(NxRadius.pill)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (v, label) in items)
              Semantics(
                selected: v == value,
                button: true,
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onChanged(v);
                  },
                  child: AnimatedContainer(
                    duration: NxMotion.hover,
                    curve: NxMotion.ease,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: v == value ? c.ink : Colors.transparent,
                      borderRadius: BorderRadius.circular(NxRadius.pill),
                    ),
                    child: Text(
                      label,
                      style: NxText.sans(size: 13, weight: FontWeight.w600, color: v == value ? c.amb : c.ink2),
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

class NxSearchField extends StatelessWidget {
  const NxSearchField({
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
      decoration: BoxDecoration(
        color: c.tint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.lineStrong),
      ),
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
  const NxTextField({
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
  const NxRating(this.value, {this.size = 13, super.key});

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
  const NxRatingInput({required this.value, required this.onChanged, this.size = 30, super.key});

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
  const NxListRow({
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
