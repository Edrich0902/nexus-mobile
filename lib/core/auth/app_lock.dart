import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nexus_mobile/core/auth/auth.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLockState {
  const new({this.enabled = false, this.locked = false, this.supported = false});

  final bool enabled;
  final bool locked;
  final bool supported;

  AppLockState copyWith({bool? enabled, bool? locked, bool? supported}) => AppLockState(
    enabled: enabled ?? this.enabled,
    locked: locked ?? this.locked,
    supported: supported ?? this.supported,
  );
}

final appLockProvider = NotifierProvider<AppLockController, AppLockState>(AppLockController.new);

/// Optional Face ID / fingerprint lock. Locks on cold start and after the
/// app has been in the background for more than a minute.
class AppLockController extends Notifier<AppLockState> {
  static const _key = 'nexus.app_lock';
  static const _grace = Duration(minutes: 1);

  final _auth = LocalAuthentication();
  DateTime? _backgroundedAt;
  bool _prompting = false;

  @override
  AppLockState build() {
    final listener = AppLifecycleListener(onStateChange: _onLifecycle);
    ref.onDispose(listener.dispose);
    unawaited(_load());
    return const AppLockState();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    var supported = false;
    try {
      supported = await _auth.isDeviceSupported();
    } on Object {
      supported = false;
    }
    final enabled = supported && (prefs.getBool(_key) ?? false);
    state = AppLockState(enabled: enabled, locked: enabled, supported: supported);
    if (enabled) unawaited(unlock());
  }

  void _onLifecycle(AppLifecycleState lifecycle) {
    if (!state.enabled || _prompting) return;
    if (lifecycle == AppLifecycleState.paused || lifecycle == AppLifecycleState.hidden) {
      _backgroundedAt ??= DateTime.now();
    } else if (lifecycle == AppLifecycleState.resumed) {
      final away = _backgroundedAt;
      _backgroundedAt = null;
      if (away != null && DateTime.now().difference(away) > _grace) {
        state = state.copyWith(locked: true);
        unawaited(unlock());
      }
    }
  }

  Future<bool> _prompt(String reason) async {
    _prompting = true;
    try {
      return await _auth.authenticate(localizedReason: reason, persistAcrossBackgrounding: true);
    } on Object {
      return false;
    } finally {
      _prompting = false;
    }
  }

  Future<void> unlock() async {
    if (!state.locked || _prompting) return;
    if (await _prompt('Unlock Nexus')) state = state.copyWith(locked: false);
  }

  Future<bool> setEnabled(bool on) async {
    if (on && !await _prompt('Turn on app lock')) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, on);
    state = state.copyWith(enabled: on, locked: false);
    return true;
  }
}

/// Covers the app while locked (and only while signed in).
class AppLockGate extends ConsumerWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lock = ref.watch(appLockProvider);
    final signedIn = ref.watch(authProvider) is SignedIn;
    final c = context.nx;
    return Stack(
      children: [
        child,
        if (lock.locked && signedIn)
          Positioned.fill(
            child: Material(
              color: c.amb,
              child: SafeArea(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.scanFace, size: 44, color: c.acc),
                      const SizedBox(height: 18),
                      Text('Nexus is locked', style: NxText.serif(size: 34, color: c.ink)),
                      const SizedBox(height: 24),
                      NxButton(
                        'Unlock',
                        icon: LucideIcons.lockOpen,
                        onPressed: () => ref.read(appLockProvider.notifier).unlock(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
