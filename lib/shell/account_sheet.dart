import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nexus_mobile/core/auth/app_lock.dart';
import 'package:nexus_mobile/core/auth/auth.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';

/// Account panel (web NexusAvatar menu): who, links, app lock and an armed
/// sign-out that disarms itself.
Future<void> showAccountSheet(BuildContext context) => showNxSheet<void>(context, builder: (_) => const _AccountBody());

class _AccountBody extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.nx;
    final user = ref.watch(currentUserProvider);
    final lock = ref.watch(appLockProvider);
    final router = GoRouter.of(context);

    void go(String path) {
      Navigator.of(context).pop();
      router.go(path);
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              NxAvatar(user: user, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.name ?? '',
                      style: NxText.sans(size: 16, weight: FontWeight.w600, color: c.ink),
                    ),
                    Text(user?.email ?? '', style: NxText.sans(size: 13, color: c.ink3)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          NxListRow(label: 'Profile', icon: LucideIcons.circleUser, onTap: () => go('/profile')),
          NxListRow(label: 'Signed-in devices', icon: LucideIcons.smartphone, onTap: () => go('/profile/sessions')),
          NxListRow(label: 'Admin', icon: LucideIcons.gauge, onTap: () => go('/admin')),
          if (lock.supported)
            NxListRow(
              label: 'Unlock with Face ID',
              icon: LucideIcons.scanFace,
              trailing: Switch(value: lock.enabled, onChanged: (v) => ref.read(appLockProvider.notifier).setEnabled(v)),
            ),
          const SizedBox(height: 8),
          Divider(color: c.line, height: 1),
          const SizedBox(height: 8),
          NxArmedConfirm(
            label: 'Sign out',
            icon: LucideIcons.logOut,
            question: 'Sign out of Nexus on this phone?',
            confirmLabel: 'Sign out',
            onConfirm: () async {
              final nav = Navigator.of(context);
              await ref.read(authProvider.notifier).logout();
              if (nav.mounted && nav.canPop()) nav.pop();
            },
          ),
        ],
      ),
    );
  }
}
