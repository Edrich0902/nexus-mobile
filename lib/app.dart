import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_mobile/core/auth/app_lock.dart';
import 'package:nexus_mobile/core/router/app_router.dart';
import 'package:nexus_mobile/design/ambient.dart';
import 'package:nexus_mobile/design/theme.dart';
import 'package:nexus_mobile/design/tokens.g.dart';
import 'package:nexus_mobile/shell/native_bootstrap.dart';
import 'package:nexus_mobile/shell/update_gate.dart';

class NexusApp extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    ref.watch(nativeBootstrapProvider);
    return MaterialApp.router(
      title: 'Nexus',
      debugShowCheckedModeBanner: false,
      theme: buildNexusTheme(SectionKey.home.ambient),
      routerConfig: router,
      builder: (context, child) {
        // Honour large system text, capped where fixed-height fields would clip.
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: mq.textScaler.clamp(minScaleFactor: .85, maxScaleFactor: 1.3)),
          child: AmbientTheme(
            child: UpdateGate(child: AppLockGate(child: child ?? const SizedBox())),
          ),
        );
      },
    );
  }
}
