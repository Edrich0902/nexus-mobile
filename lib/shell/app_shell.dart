import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nexus_mobile/core/router/navigation.dart';
import 'package:nexus_mobile/design/ambient.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';
import 'package:nexus_mobile/features/listening/player.dart';
import 'package:nexus_mobile/shell/phone_bar.dart';
import 'package:nexus_mobile/shell/top_bar.dart';

/// Room the floating top capsules take below the status bar.
const topBarHeight = TopBar.gap + TopBar.capsuleHeight + 6;

/// The authed frame: the page scrolls edge to edge under floating glass
/// chrome. Scrolling down collapses the phone bar; scrolling up, reaching
/// the top or changing route brings it back.
class AppShell extends ConsumerStatefulWidget {
  const new({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  StreamSubscription<String>? _playerErrors;

  /// Lets every glass surface share one backdrop read per frame.
  final _backdrop = BackdropKey();
  final _collapsed = ValueNotifier(false);

  /// Inside [ShellInsets], so toasts raised here clear the phone bar.
  final _body = GlobalKey();

  @override
  void initState() {
    super.initState();
    _syncSection();
    _playerErrors = ref.read(playerProvider.notifier).errors.stream.listen((m) {
      if (mounted) showNxToast(_body.currentContext ?? context, m, error: true);
    });
  }

  @override
  void didUpdateWidget(AppShell old) {
    super.didUpdateWidget(old);
    if (old.location != widget.location) {
      _syncSection();
      _collapsed.value = false;
    }
  }

  bool _onScroll(ScrollUpdateNotification n) {
    final m = n.metrics;
    // depth ≤ 1 keeps pages inside a PageView/TabBarView in play.
    if (m.axis != Axis.vertical || n.depth > 1 || m.outOfRange) return false;
    final delta = n.scrollDelta ?? 0;
    if (m.pixels < 60 || delta < -2) {
      _collapsed.value = false;
    } else if (delta > 2) {
      _collapsed.value = true;
    }
    return false;
  }

  void _syncSection() {
    final section = Nav.sectionFor(widget.location);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(ambientProvider.notifier).setSection(section);
    });
  }

  @override
  void dispose() {
    unawaited(_playerErrors?.cancel());
    _collapsed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    final mq = MediaQuery.of(context);
    final hasTrack = ref.watch(playerProvider.select((p) => p.hasTrack));

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: ShellInsets(
        top: mq.padding.top + topBarHeight,
        bottom: PhoneBar.inset(mq, hasTrack: hasTrack),
        child: BackdropGroup(
          backdropKey: _backdrop,
          child: Stack(
            key: _body,
            children: [
              Positioned.fill(
                child: NotificationListener<ScrollUpdateNotification>(onNotification: _onScroll, child: widget.child),
              ),
              // Keep the status bar and home indicator legible over content.
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: mq.padding.top + 28,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [c.amb.withValues(alpha: .88), c.amb.withValues(alpha: 0)],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: PhoneBar.dockBottom(mq) + PhoneBar.dockHeight + 24,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [c.amb.withValues(alpha: 0), c.amb.withValues(alpha: .72)],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(left: 0, right: 0, top: 0, child: TopBar(location: widget.location)),
              Positioned.fill(
                child: PhoneBar(
                  location: widget.location,
                  collapsed: _collapsed,
                  onExpand: () => _collapsed.value = false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
