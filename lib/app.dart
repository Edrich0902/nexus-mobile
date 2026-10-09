import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_mobile/core/auth/app_lock.dart';
import 'package:nexus_mobile/core/router/app_router.dart';
import 'package:nexus_mobile/design/ambient.dart';
import 'package:nexus_mobile/design/theme.dart';
import 'package:nexus_mobile/design/tokens.g.dart';
import 'package:nexus_mobile/shell/native_bootstrap.dart';

class NexusApp extends ConsumerWidget {
  const NexusApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    ref.watch(nativeBootstrapProvider);
    return MaterialApp.router(
      title: 'Nexus',
      debugShowCheckedModeBanner: false,
      theme: buildNexusTheme(SectionKey.home.ambient),
      routerConfig: router,
      builder: (context, child) => AmbientTheme(child: AppLockGate(child: child ?? const SizedBox())),
    );
  }
}
