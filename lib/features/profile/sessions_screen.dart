import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nexus_mobile/core/api/api_client.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/core/auth/auth.dart';
import 'package:nexus_mobile/core/format.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';
import 'package:nexus_mobile/features/profile/profile_screen.dart';

final sessionsProvider = FutureProvider.autoDispose<List<Json>>((ref) async {
  final list = asJsonList(await ref.watch(apiClientProvider).get('/auth/sessions'))
    ..sort((a, b) => (b.flag('is_current') ? 1 : 0) - (a.flag('is_current') ? 1 : 0));
  return list;
});

/// "Chrome on macOS" from a user agent (web profile/sessions.ts).
String? describeAgent(String? ua) {
  if (ua == null || ua.isEmpty) return null;
  bool has(String p) => RegExp(p, caseSensitive: false).hasMatch(ua);
  final browser = has('Edg/')
      ? 'Edge'
      : has('OPR/|Opera')
      ? 'Opera'
      : has('Firefox/')
      ? 'Firefox'
      : has('Chrome/')
      ? 'Chrome'
      : has('Safari/')
      ? 'Safari'
      : has('okhttp|Dart|CFNetwork|Expo')
      ? 'Nexus app'
      : has('curl|PostmanRuntime|insomnia')
      ? 'API client'
      : null;
  final os = has('iPhone|iPad|iPod')
      ? 'iOS'
      : has('Android')
      ? 'Android'
      : has('Mac OS X|Macintosh')
      ? 'macOS'
      : has('Windows')
      ? 'Windows'
      : has('Linux')
      ? 'Linux'
      : null;
  if (browser != null && os != null) return '$browser on $os';
  return browser ?? os;
}

class SessionsScreen extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(sessionsProvider);
    final others = sessions.value?.where((s) => !s.flag('is_current')).length ?? 0;

    return ProfileFrame(
      tab: 'sessions',
      onRefresh: () => ref.refresh(sessionsProvider.future),
      children: [
        NxSectionHeader('Signed-in devices · ${sessions.value?.length ?? 0}', top: 0),
        NxAsync(
          value: sessions,
          onRetry: () => ref.invalidate(sessionsProvider),
          loading: const NxPageSkeleton(art: false, rows: 3),
          data: (list) => list.isEmpty
              ? const NxEmptyState(
                  icon: LucideIcons.smartphone,
                  title: 'No active sessions',
                  body: 'Sign in on a device to see it here.',
                )
              : Column(children: [for (final s in list) _SessionRow(session: s)]),
        ),
        const SizedBox(height: 16),
        if (others > 0)
          NxArmedConfirm(
            label: 'Sign out everywhere else',
            icon: LucideIcons.logOut,
            question: 'Sign out of ${plural(others, 'other session')}? This phone stays signed in.',
            confirmLabel: 'Sign out others',
            onConfirm: () async {
              final api = ref.read(apiClientProvider);
              for (final s in sessions.value!.where((s) => !s.flag('is_current'))) {
                await api.delete('/auth/sessions/${s.integer('id')}');
              }
              ref.invalidate(sessionsProvider);
            },
          ),
      ],
    );
  }
}

class _SessionRow extends ConsumerWidget {
  const new({required this.session});

  final Json session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.nx;
    final current = session.flag('is_current');
    final device = session.obj('device') ?? const {};
    final title = describeAgent(device.str('user_agent')) ?? device.str('name') ?? session.text('name');
    final ip = device.str('ip_address');
    final active = relativeTime(session.date('last_used_at') ?? session.date('created_at'));
    final expires = session.date('expires_at');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: current ? c.acc.withValues(alpha: .1) : c.tint,
        borderRadius: BorderRadius.circular(NxRadius.lg),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: current ? c.acc : c.ink4, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      title,
                      style: NxText.sans(size: 14.5, weight: FontWeight.w600, color: c.ink),
                    ),
                    if (current) const NxChip('This device', selected: true),
                    if (session.flag('remember')) const NxChip('Remembered'),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  [?ip, 'Active $active', if (expires != null) 'Expires ${formatDateTime(expires)}'].join(' · '),
                  style: NxText.sans(size: 12.5, color: c.ink3),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _revoke(context, ref, current),
            style: TextButton.styleFrom(foregroundColor: NexusColors.bad),
            child: Text(current ? 'Sign out' : 'Revoke'),
          ),
        ],
      ),
    );
  }

  Future<void> _revoke(BuildContext context, WidgetRef ref, bool current) async {
    final ok = await showNxSheet<bool>(
      context,
      builder: (sheet) => NxArmedConfirm(
        label: current ? 'Sign out this phone' : 'Revoke this device',
        icon: LucideIcons.logOut,
        question: current ? 'Revoke this device and sign out now?' : 'Revoke access for this device?',
        confirmLabel: 'Revoke',
        onConfirm: () async => Navigator.of(sheet).pop(true),
      ),
    );
    if (ok != true) return;
    try {
      if (current) {
        await ref.read(authProvider.notifier).logout();
        return;
      }
      await ref.read(apiClientProvider).delete('/auth/sessions/${session.integer('id')}');
      ref.invalidate(sessionsProvider);
    } on Object catch (e) {
      if (context.mounted) showApiError(context, e, 'Could not revoke the session.');
    }
  }
}
