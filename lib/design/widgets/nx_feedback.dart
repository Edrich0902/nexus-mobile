import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nexus_mobile/core/api/api_error.dart';
import 'package:nexus_mobile/design/colors.dart';
import 'package:nexus_mobile/design/tokens.g.dart';
import 'package:nexus_mobile/design/typography.dart';
import 'package:nexus_mobile/design/widgets/nx_controls.dart';

/// Empty state (web NxEmptyState): icon tile, serif title, body, action.
class NxEmptyState extends StatelessWidget {
  const NxEmptyState({
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
  const NxErrorState({required this.error, this.onRetry, this.compact = false, super.key});

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
      actionLabel: onRetry == null ? null : 'Try again',
      onAction: onRetry,
      compact: compact,
    );
  }
}

/// Soft pulsing placeholder block.
class NxSkeleton extends StatefulWidget {
  const NxSkeleton({this.width, this.height = 16, this.radius = NxRadius.sm, super.key});

  final double? width;
  final double height;
  final double radius;

  @override
  State<NxSkeleton> createState() => _NxSkeletonState();
}

class _NxSkeletonState extends State<NxSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(c.tint, c.tint2, _c.value),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        ),
      ),
    );
  }
}

/// Generic page skeleton: stage + bento + rows.
class NxPageSkeleton extends StatelessWidget {
  const NxPageSkeleton({this.art = true, this.rows = 4, super.key});

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

/// Renders an [AsyncValue] with Nexus loading/error states. Keeps showing
/// previous data while refreshing.
class NxAsync<T> extends StatelessWidget {
  const NxAsync({required this.value, required this.data, this.loading, this.onRetry, super.key});

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final Widget? loading;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      data: data,
      loading: () => loading ?? const NxPageSkeleton(),
      error: (e, _) => NxErrorState(error: e, onRetry: onRetry),
    );
  }
}

void showNxToast(
  BuildContext context,
  String message, {
  bool error = false,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final c = context.nx;
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(error ? LucideIcons.circleAlert : LucideIcons.check, size: 18, color: error ? NexusColors.bad : c.acc),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        action: actionLabel == null
            ? null
            : SnackBarAction(label: actionLabel, textColor: c.acc, onPressed: onAction ?? () {}),
      ),
    );
}

void showApiError(BuildContext context, Object error, [String fallback = 'Something went wrong.']) =>
    showNxToast(context, ApiError.from(error, fallback).message, error: true);
