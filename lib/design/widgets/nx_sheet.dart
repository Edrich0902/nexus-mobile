import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexus_mobile/design/colors.dart';
import 'package:nexus_mobile/design/tokens.g.dart';
import 'package:nexus_mobile/design/typography.dart';
import 'package:nexus_mobile/design/widgets/nx_controls.dart';

/// Bottom sheet in the Nexus style: overlay surface, grab handle, optional
/// title row. Used for the More drawer, account, search and editors.
Future<T?> showNxSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  String? title,
  bool expand = false,
  bool scrollable = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    barrierColor: Colors.black.withValues(alpha: .5),
    builder: (context) {
      final c = context.nx;
      final mq = MediaQuery.of(context);
      final content = Padding(
        padding: EdgeInsets.fromLTRB(18, 10, 18, 18 + mq.viewInsets.bottom + mq.padding.bottom),
        child: Column(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 5,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(color: c.tint2, borderRadius: BorderRadius.circular(3)),
              ),
            ),
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                child: Text(
                  title,
                  style: NxText.serif(size: 26, color: c.ink, height: 1.1).copyWith(letterSpacing: -.2),
                ),
              ),
            if (expand) Expanded(child: builder(context)) else Flexible(child: builder(context)),
          ],
        ),
      );
      return DecoratedBox(
        decoration: BoxDecoration(
          color: c.overlay,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(NxRadius.xxl)),
          border: Border(top: BorderSide(color: c.line)),
        ),
        child: expand ? SizedBox(height: mq.size.height * .88, child: content) : content,
      );
    },
  );
}

/// Inline armed confirmation for destructive actions (web NexusAvatar
/// sign-out): first tap arms, the row swaps to a red confirm that disarms
/// itself after 6 s with a draining bar.
class NxArmedConfirm extends StatefulWidget {
  const NxArmedConfirm({
    required this.label,
    required this.question,
    required this.confirmLabel,
    required this.onConfirm,
    this.icon,
    super.key,
  });

  final String label;
  final String question;
  final String confirmLabel;
  final Future<void> Function() onConfirm;
  final IconData? icon;

  @override
  State<NxArmedConfirm> createState() => _NxArmedConfirmState();
}

class _NxArmedConfirmState extends State<NxArmedConfirm> with SingleTickerProviderStateMixin {
  static const _window = Duration(seconds: 6);
  late final AnimationController _drain = AnimationController(vsync: this, duration: _window);
  Timer? _timer;
  bool _armed = false;
  bool _busy = false;

  void _arm() {
    HapticFeedback.mediumImpact();
    setState(() => _armed = true);
    _drain.forward(from: 0);
    _timer?.cancel();
    _timer = Timer(_window, () {
      if (mounted) setState(() => _armed = false);
    });
  }

  void _disarm() {
    _timer?.cancel();
    setState(() => _armed = false);
  }

  Future<void> _confirm() async {
    _timer?.cancel();
    setState(() => _busy = true);
    try {
      await widget.onConfirm();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _drain.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      switchInCurve: NxMotion.ease,
      transitionBuilder: (child, a) => FadeTransition(
        opacity: a,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, .05), end: Offset.zero).animate(a),
          child: child,
        ),
      ),
      child: !_armed
          ? NxListRow(
              key: const ValueKey('idle'),
              label: widget.label,
              icon: widget.icon,
              onTap: _arm,
              trailing: const SizedBox(),
            )
          : Container(
              key: const ValueKey('armed'),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: NexusColors.bad.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(NxRadius.md),
              ),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(widget.question, style: NxText.sans(size: 15, color: c.ink)),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            NxButton('Cancel', onPressed: _disarm, variant: NxButtonVariant.ghost, compact: true),
                            const SizedBox(width: 8),
                            NxButton(
                              widget.confirmLabel,
                              onPressed: _confirm,
                              loading: _busy,
                              variant: NxButtonVariant.danger,
                              compact: true,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: AnimatedBuilder(
                      animation: _drain,
                      builder: (_, _) => Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: 1 - _drain.value,
                          child: Container(height: 2, color: NexusColors.bad),
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
