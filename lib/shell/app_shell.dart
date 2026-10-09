import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_mobile/core/router/navigation.dart';
import 'package:nexus_mobile/design/ambient.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';
import 'package:nexus_mobile/features/listening/player.dart';
import 'package:nexus_mobile/shell/phone_bar.dart';
import 'package:nexus_mobile/shell/top_bar.dart';

const topBarHeight = 54.0;

/// The authed frame (web AppLayout at ≤640px): blurred top bar, scrolling
/// page underneath, and the phone bar with the Spotify strip.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  StreamSubscription<String>? _playerErrors;

  @override
  void initState() {
    super.initState();
    _syncSection();
    _playerErrors = ref.read(playerProvider.notifier).errors.stream.listen((m) {
      if (mounted) showNxToast(context, m, error: true);
    });
  }

  @override
  void didUpdateWidget(AppShell old) {
    super.didUpdateWidget(old);
    if (old.location != widget.location) _syncSection();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final hasTrack = ref.watch(playerProvider.select((p) => p.hasTrack));
    final top = mq.padding.top + topBarHeight;
    final bottom = mq.padding.bottom + PhoneBar.tabsHeight + (hasTrack ? PhoneBar.stripHeight : 0);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: ShellInsets(
        top: top,
        bottom: bottom,
        child: Stack(
          children: [
            Positioned.fill(child: widget.child),
            Positioned(left: 0, right: 0, top: 0, child: TopBar(location: widget.location)),
            Positioned(left: 0, right: 0, bottom: 0, child: PhoneBar(location: widget.location)),
          ],
        ),
      ),
    );
  }
}
