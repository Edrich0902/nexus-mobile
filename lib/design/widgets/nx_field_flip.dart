import 'package:material_ui/material_ui.dart';
import 'package:nexus_mobile/design/widgets/nx_motion.dart';

/// Sequential exit → entrance whenever [contentKey] changes.
///
/// Outgoing face sinks back and fades; the next rises in and settles.
/// Only one transition runs at a time so the board stays calm.
class NxFieldFlip extends StatefulWidget {
  const new({required this.contentKey, required this.child, super.key});

  final Object contentKey;
  final Widget child;

  @override
  State<NxFieldFlip> createState() => _NxFieldFlipState();
}

class _NxFieldFlipState extends State<NxFieldFlip> with SingleTickerProviderStateMixin {
  static const _out = Duration(milliseconds: 560);
  static const _in = Duration(milliseconds: 720);

  late final AnimationController _c = AnimationController(vsync: this, value: 1);
  late Object _shownKey = widget.contentKey;
  late Widget _shown = widget.child;
  Widget? _incoming;
  Object? _incomingKey;
  bool _exiting = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(NxFieldFlip old) {
    super.didUpdateWidget(old);
    if (widget.contentKey == _shownKey && widget.contentKey == old.contentKey) {
      _shown = widget.child;
      return;
    }
    if (widget.contentKey == _shownKey) return;
    if (reduceMotion(context)) {
      setState(() {
        _shownKey = widget.contentKey;
        _shown = widget.child;
        _incoming = null;
        _exiting = false;
        _c.value = 1;
      });
      return;
    }
    _incoming = widget.child;
    _incomingKey = widget.contentKey;
    if (_exiting) return;
    _startExit();
  }

  Future<void> _startExit() async {
    _exiting = true;
    _c.duration = _out;
    await _c.reverse(from: 1);
    if (!mounted) return;
    setState(() {
      _shown = _incoming ?? widget.child;
      _shownKey = _incomingKey ?? widget.contentKey;
      _incoming = null;
      _incomingKey = null;
    });
    _c.duration = _in;
    await _c.forward(from: 0);
    if (mounted) setState(() => _exiting = false);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: KeyedSubtree(key: ValueKey(_shownKey), child: _shown),
      builder: (context, child) {
        final t = _c.value;
        if (_exiting) {
          final p = Curves.easeInCubic.transform(1 - t);
          return Opacity(
            opacity: (1 - p).clamp(0.0, 1.0),
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0015)
                ..translateByDouble(0, -22.0 * p, 0, 1)
                ..scaleByDouble(1 - 0.16 * p, 1 - 0.16 * p, 1 - 0.16 * p, 1)
                ..rotateX(0.72 * p),
              child: child,
            ),
          );
        }
        final p = Curves.easeOutCubic.transform(1 - t);
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0015)
              ..translateByDouble(0, 36.0 * p, 0, 1)
              ..scaleByDouble(1 + 0.14 * p, 1 + 0.14 * p, 1 + 0.14 * p, 1)
              ..rotateX(-0.55 * p),
            child: child,
          ),
        );
      },
    );
  }
}
