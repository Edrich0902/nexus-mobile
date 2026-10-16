import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nexus_mobile/core/api/api_error.dart';
import 'package:nexus_mobile/design/colors.dart';
import 'package:nexus_mobile/design/tokens.g.dart';
import 'package:nexus_mobile/design/typography.dart';
import 'package:nexus_mobile/design/widgets/nx_controls.dart';
import 'package:nexus_mobile/design/widgets/nx_glass.dart';
import 'package:nexus_mobile/design/widgets/nx_layout.dart';
import 'package:nexus_mobile/design/widgets/nx_motion.dart';

/// Empty state (web NxEmptyState): icon tile, serif title, body, action.
class NxEmptyState extends StatelessWidget {
  const new({
    required this.title,
    this.body,
    this.icon = LucideIcons.sparkles,
    this.actionLabel,
    this.onAction,
    this.compact = false,
    super.key,
  });

  final String title;
  final String? body;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 20 : 40),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: c.tint2, borderRadius: BorderRadius.circular(NxRadius.md)),
            child: Icon(icon, color: c.acc, size: 22),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: NxText.serif(size: 26, color: c.ink, height: 1.1).copyWith(letterSpacing: -.2),
          ),
          if (body != null) ...[
            const SizedBox(height: 8),
            Text(
              body!,
              textAlign: TextAlign.center,
              style: NxText.sans(color: c.ink3, height: 1.45),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 18),
            NxButton(actionLabel!, onPressed: onAction, variant: NxButtonVariant.secondary),
          ],
        ],
      ),
    );
  }
}

class NxErrorState extends StatelessWidget {
  const new({required this.error, this.onRetry, this.compact = false, super.key});

  final Object error;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final e = ApiError.from(error);
    return NxEmptyState(
      icon: e.isOffline ? LucideIcons.wifiOff : LucideIcons.circleAlert,
      title: e.isOffline ? "You're offline" : (e.isNotFound ? 'Not found' : 'Something went wrong'),
      body: e.message,
      actionLabel: onRetry == null ? null : (e.suggestsSync ? 'Sync and try again' : 'Try again'),
      onAction: onRetry,
      compact: compact,
    );
  }
}

/// Placeholder block with a soft highlight sweeping across. Every skeleton
/// shares one wall-clock phase, so a page of them shimmers in step.
class NxSkeleton extends StatefulWidget {
  const new({this.width, this.height = 16, this.radius = NxRadius.sm, super.key});

  final double? width;
  final double height;
  final double radius;

  @override
  State<NxSkeleton> createState() => _NxSkeletonState();
}

class _NxSkeletonState extends State<NxSkeleton> with SingleTickerProviderStateMixin {
  static const _period = Duration(milliseconds: 1500);
  late final AnimationController _c = AnimationController(vsync: this, duration: _period);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c
        ..value = (DateTime.now().millisecondsSinceEpoch % _period.inMilliseconds) / _period.inMilliseconds
        ..repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    final radius = BorderRadius.circular(widget.radius);
    if (reduceMotion(context)) {
      return ExcludeSemantics(
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(color: c.tint, borderRadius: radius),
        ),
      );
    }
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              colors: [c.tint, Color.lerp(c.tint2, c.ink, .06)!, c.tint],
              stops: const [.35, .5, .65],
              transform: _Sweep(_c.value),
            ),
          ),
        ),
      ),
    );
  }
}

class _Sweep extends GradientTransform {
  const new(this.t);

  final double t;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * (t * 2.4 - 1.2), 0, 0);
}

/// Generic page skeleton: stage + bento + rows.
class NxPageSkeleton extends StatelessWidget {
  const new({this.art = true, this.rows = 4, super.key});

  final bool art;
  final int rows;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          if (art) ...[const NxSkeleton(width: 132, height: 132, radius: NxRadius.lg), const SizedBox(height: 20)],
          const NxSkeleton(width: 120, height: 13),
          const SizedBox(height: 16),
          const NxSkeleton(width: 260, height: 36),
          const SizedBox(height: 10),
          const NxSkeleton(width: 200, height: 36),
          const SizedBox(height: 26),
          const Row(
            children: [
              Expanded(child: NxSkeleton(height: 120, radius: NxRadius.xl)),
              SizedBox(width: 10),
              Expanded(child: NxSkeleton(height: 120, radius: NxRadius.xl)),
            ],
          ),
          for (var i = 0; i < rows; i++) ...[
            const SizedBox(height: 12),
            const NxSkeleton(height: 64, radius: NxRadius.md),
          ],
        ],
      ),
    );
  }
}

/// Renders an [AsyncValue] with Nexus loading/error states, cross-fading
/// between them. Keeps showing previous data while refreshing.
class NxAsync<T> extends StatelessWidget {
  const new({required this.value, required this.data, this.loading, this.onRetry, super.key});

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final Widget? loading;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return NxSwitcher(
      child: value.when(
        skipLoadingOnRefresh: true,
        skipLoadingOnReload: true,
        data: (d) => KeyedSubtree(key: const ValueKey('data'), child: data(d)),
        loading: () => KeyedSubtree(key: const ValueKey('loading'), child: loading ?? const NxPageSkeleton()),
        error: (e, _) => KeyedSubtree(
          key: const ValueKey('error'),
          child: NxErrorState(error: e, onRetry: onRetry),
        ),
      ),
    );
  }
}

/// The toast on screen, if any; showing another replaces it.
NxToast? _activeToast;

/// Handle to a shown toast; [close] dismisses it early (e.g. an upload
/// finished).
class NxToast {
  new _();

  OverlayEntry? _entry;
  final _closing = ValueNotifier(false);
  bool _removed = false;

  void close() {
    if (!_removed) _closing.value = true;
  }

  void _remove() {
    if (_removed) return;
    _removed = true;
    _entry?.remove();
    _closing.dispose();
    if (identical(_activeToast, this)) _activeToast = null;
  }
}

/// A floating toast above the tab bar (and keyboard). It springs in, can
/// be swiped away, and leaves on its own; pass [progress] (0–1, or 0 for
/// indeterminate) to show a long-running task.
NxToast showNxToast(
  BuildContext context,
  String message, {
  bool error = false,
  String? actionLabel,
  VoidCallback? onAction,
  ValueListenable<double>? progress,
  Duration? duration,
}) {
  final toast = NxToast._();
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return toast;
  _activeToast?.close();
  _activeToast = toast;

  final mq = MediaQuery.of(context);
  final bottom = math.max(ShellInsets.maybeOf(context)?.bottom ?? mq.padding.bottom, mq.viewInsets.bottom) + 12;
  final view = _ToastView(
    toast: toast,
    colors: context.nx,
    message: message,
    error: error,
    actionLabel: actionLabel,
    onAction: onAction,
    progress: progress,
    bottom: bottom,
    duration:
        duration ?? (actionLabel != null || error ? const Duration(seconds: 5) : const Duration(milliseconds: 3200)),
  );
  toast._entry = OverlayEntry(builder: (_) => view);
  overlay.insert(toast._entry!);
  if (progress == null) unawaited(error ? HapticFeedback.mediumImpact() : HapticFeedback.lightImpact());
  return toast;
}

NxToast showApiError(BuildContext context, Object error, [String fallback = 'Something went wrong.']) =>
    showNxToast(context, ApiError.from(error, fallback).message, error: true);

class _ToastView extends StatefulWidget {
  const new({
    required this.toast,
    required this.colors,
    required this.message,
    required this.error,
    required this.bottom,
    required this.duration,
    this.actionLabel,
    this.onAction,
    this.progress,
  });

  final NxToast toast;
  final NexusColors colors;
  final String message;
  final bool error;
  final double bottom;
  final Duration duration;
  final String? actionLabel;
  final VoidCallback? onAction;
  final ValueListenable<double>? progress;

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    reverseDuration: const Duration(milliseconds: 200),
  );
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    widget.toast._closing.addListener(_leave);
    _c.forward();
    _timer = Timer(widget.duration, _leave);
  }

  void _leave() {
    _timer?.cancel();
    if (!mounted || _c.status == AnimationStatus.reverse) return;
    _c.reverse().whenComplete(widget.toast._remove);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final reduce = reduceMotion(context);
    final tone = widget.error ? NexusColors.bad : c.acc;
    final enter = CurvedAnimation(parent: _c, curve: Curves.easeOutBack, reverseCurve: NxTiming.exit);
    final fade = CurvedAnimation(parent: _c, curve: Curves.easeOut, reverseCurve: NxTiming.exit);

    final body = Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, color: tone.withValues(alpha: .16)),
                child: widget.progress != null
                    ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: tone))
                    : Icon(widget.error ? LucideIcons.circleAlert : LucideIcons.check, size: 16, color: tone),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(widget.message, style: NxText.sans(color: c.ink, height: 1.35)),
              ),
              if (widget.actionLabel != null)
                TextButton(
                  onPressed: () {
                    widget.onAction?.call();
                    _leave();
                  },
                  style: TextButton.styleFrom(foregroundColor: c.acc, visualDensity: VisualDensity.compact),
                  child: Text(
                    widget.actionLabel!,
                    style: NxText.sans(weight: FontWeight.w600, color: c.acc),
                  ),
                )
              else
                const SizedBox(width: 6),
            ],
          ),
          if (widget.progress case final progress?)
            Padding(
              padding: const EdgeInsets.fromLTRB(40, 10, 6, 2),
              child: ValueListenableBuilder(
                valueListenable: progress,
                builder: (_, v, _) => ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: v == 0 ? null : v,
                    minHeight: 3,
                    color: tone,
                    backgroundColor: c.line,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    final card = Theme(
      data: Theme.of(context).copyWith(extensions: [c]),
      child: NxGlass(radius: NxRadius.lg + 4, thick: true, child: body),
    );

    return Positioned(
      left: 16,
      right: 16,
      bottom: widget.bottom,
      child: Semantics(
        liveRegion: true,
        child: Material(
          type: MaterialType.transparency,
          child: Dismissible(
            key: ObjectKey(widget.toast),
            direction: DismissDirection.down,
            onDismissed: (_) => widget.toast._remove(),
            child: reduce
                ? FadeTransition(opacity: fade, child: card)
                : AnimatedBuilder(
                    animation: _c,
                    child: card,
                    builder: (context, child) => Opacity(
                      opacity: fade.value.clamp(0, 1),
                      child: Transform.translate(
                        offset: Offset(0, 28 * (1 - enter.value)),
                        child: Transform.scale(scale: .94 + .06 * enter.value, child: child),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
