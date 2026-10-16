import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nexus_mobile/design/colors.dart';
import 'package:nexus_mobile/design/tokens.g.dart';
import 'package:nexus_mobile/design/typography.dart';
import 'package:nexus_mobile/design/widgets/nx_controls.dart';
import 'package:nexus_mobile/design/widgets/nx_glass.dart';

/// Bottom sheet in the Nexus style: a floating pane of thick glass inset
/// from the screen edges, with a grab handle and optional title row. Used
/// for account, search, pickers and editors.
Future<T?> showNxSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  String? title,
  bool expand = false,
  bool scrollable = true,
}) {
  unawaited(HapticFeedback.lightImpact());
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: Colors.black.withValues(alpha: .34),
    sheetAnimationStyle: const AnimationStyle(
      duration: Duration(milliseconds: 380),
      reverseDuration: Duration(milliseconds: 220),
    ),
    builder: (context) {
      final c = context.nx;
      final mq = MediaQuery.of(context);
      final keyboard = mq.viewInsets.bottom;
      final lift = keyboard > 0 ? keyboard + _gap : _gap;
      final content = Padding(
        padding: EdgeInsets.fromLTRB(18, 10, 18, keyboard > 0 ? 18 : math.max(mq.padding.bottom - _gap, 0) + 14),
        child: Column(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 5,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(color: c.ink4, borderRadius: BorderRadius.circular(3)),
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
      return Padding(
        padding: EdgeInsets.fromLTRB(_gap, 0, _gap, lift),
        child: NxGlass(
          radius: _radius,
          thick: true,
          child: expand ? SizedBox(height: math.max(mq.size.height * .88 - lift, 0), child: content) : content,
        ),
      );
    },
  );
}

/// Sheets float this far off the screen edges, with corners that follow
/// the device's.
const _gap = 8.0;
const _radius = 34.0;

/// Confirm a destructive action (web PrimeVue `confirm.require` popover):
/// resolves true only when the danger button is pressed.
Future<bool> showNxConfirm(
  BuildContext context, {
  required String message,
  String confirmLabel = 'Delete',
  String cancelLabel = 'Keep',
}) async {
  unawaited(HapticFeedback.mediumImpact());
  final ok = await showNxSheet<bool>(
    context,
    builder: (sheet) {
      final c = sheet.nx;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 18),
            child: Text(message, style: NxText.sans(size: 16, color: c.ink, height: 1.45)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              NxButton(cancelLabel, onPressed: () => Navigator.of(sheet).pop(false), variant: NxButtonVariant.ghost),
              const SizedBox(width: 8),
              NxButton(confirmLabel, onPressed: () => Navigator.of(sheet).pop(true), variant: NxButtonVariant.danger),
            ],
          ),
        ],
      );
    },
  );
  return ok ?? false;
}

/// Inline armed confirmation for destructive actions (web NexusAvatar
/// sign-out): first tap arms, the row swaps to a red confirm that disarms
/// itself after 6 s with a draining bar.
class NxArmedConfirm extends StatefulWidget {
  const new({
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
