import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/core/format.dart';
import 'package:nexus_mobile/core/native/open_external.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';
import 'package:nexus_mobile/features/code/code_widgets.dart';
import 'package:nexus_mobile/features/code/github.dart';
import 'package:nexus_mobile/features/collections/collection_fields.dart';
import 'package:nexus_mobile/features/home/home_modules.dart';

/// Shown on every Code page until GitHub is linked.
class ConnectGithubState extends ConsumerWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => NxEmptyState(
    icon: LucideIcons.codeXml,
    title: 'GitHub is not linked',
    body:
        'Connecting asks GitHub for read access to your repositories and permission to open, review and merge '
        'pull requests.',
    actionLabel: 'Connect GitHub',
    onAction: () => connectGithub(context, ref),
  );
}

/// Web GithubView: open pull requests headline, recent commits, the PR inbox
/// and every synced repository.
class GithubScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<GithubScreen> createState() => _GithubScreenState();
}

class _GithubScreenState extends ConsumerState<GithubScreen> {
  bool _starredOnly = false;
  bool _syncing = false;

  Future<void> _sync() async {
    setState(() => _syncing = true);
    await syncGithub(context, ref);
    if (mounted) setState(() => _syncing = false);
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(githubStatusProvider);
    final connected = status.value?.flag('connected') ?? false;

    return NxPage(
      onRefresh: () async {
        refreshGithub(ref);
        await ref.read(githubStatusProvider.future);
      },
      children: [
        if (status.isLoading && status.value == null)
          const NxPageSkeleton()
        else if (!connected) ...[
          const NxStage(
            compact: true,
            eyebrow: 'Code',
            title: 'Your',
            accent: 'code',
            lede: 'Link GitHub to browse repositories, review pull request diffs and merge without leaving Nexus.',
          ),
          const SizedBox(height: 22),
          const ConnectGithubState(),
        ] else
          _connected(context, status.value!),
      ],
    );
  }

  Widget _connected(BuildContext context, Json status) {
    final c = context.nx;
    final profile = ref.watch(githubProfileProvider).value;
    final reposAsync = ref.watch(githubReposProvider);
    final repos = reposAsync.value ?? const <Json>[];
    final pulseAsync = ref.watch(githubPulseProvider);
    final pulse = pulseAsync.value;
    final open = pulse?.list('open_pulls') ?? const <Json>[];
    final merged = pulse?.list('merged_pulls') ?? const <Json>[];
    final commits = pulse?.list('commits') ?? const <Json>[];

    final eyebrow = [
      if (profile?.str('login') case final login?) '@$login' else 'GitHub',
      if (status.date('last_synced_at') case final at?) 'Synced ${relativeTime(at)}',
    ].join(' · ');

    final (title, accent) = pulse == null
        ? ('Your', 'code')
        : (open.isEmpty ? ('All', 'clear') : (plural(open.length, 'pull request'), 'open'));

    final lede = () {
      if (profile?.str('bio') case final bio?) return bio;
      final latest = repos
          .map((r) => r.date('pushed_at'))
          .nonNulls
          .fold<DateTime?>(null, (best, at) => best == null || at.isAfter(best) ? at : best);
      final count = plural(repos.length, 'repository', 'repositories');
      return latest == null ? '$count synced from GitHub.' : '$count, last pushed ${relativeTime(latest)}.';
    }();

    final privateCount = repos.where((r) => r.flag('private')).length;
    final latest = commits.firstOrNull;
    final fields = [
      CollectionField(
        key: 'repos',
        label: 'Repositories',
        value: '${repos.length}',
        sub: privateCount > 0 ? '$privateCount private' : null,
      ),
      CollectionField(
        key: 'open',
        label: 'Open PRs',
        value: '${open.length}',
        variant: FieldVariant.tint,
        to: '/github/pulls',
      ),
      CollectionField(key: 'merged', label: 'Recently merged', value: '${merged.length}', variant: FieldVariant.tint),
      if (latest != null)
        CollectionField(
          key: 'latest',
          label: 'Latest commit',
          aside: latest.date('author_date') == null ? null : relativeTime(latest.date('author_date')),
          title: firstLine(latest.str('message')),
          sub: latest.obj('repository')?.str('full_name') ?? latest.obj('repository')?.str('name'),
          variant: FieldVariant.outline,
          span: 2,
        )
      else
        CollectionField(
          key: 'followers',
          label: 'Followers',
          value: '${profile?.integer('followers') ?? 0}',
          sub: profile?.integer('following') == null ? null : 'following ${profile!.integer('following')}',
          variant: FieldVariant.outline,
        ),
    ];

    final shown = _starredOnly ? repos.where((r) => r.flag('starred')).toList() : repos;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NxStage(
          eyebrow: eyebrow,
          title: title,
          accent: accent,
          lede: lede,
          visual: profile?.str('avatar_url') == null ? null : NxImage(url: profile!.str('avatar_url')),
          actions: [
            if (open.isNotEmpty) NxButton('Review pull requests', onPressed: () => context.go('/github/pulls')),
            NxButton(
              'Sync',
              icon: LucideIcons.refreshCw,
              variant: NxButtonVariant.secondary,
              loading: _syncing,
              onPressed: _sync,
            ),
            if (profile?.str('html_url') case final url?)
              NxIconButton(LucideIcons.externalLink, tooltip: 'Open on GitHub', onPressed: () => openExternal(url)),
            NxIconButton(
              LucideIcons.unplug,
              tooltip: 'Disconnect GitHub',
              onPressed: () => disconnectGithub(context, ref),
            ),
          ],
        ),
        CollectionFields(section: SectionKey.code, fields: fields),
        const SizedBox(height: 22),
        const CodeNav(value: '/github'),
        if (status.flag('needs_reauth'))
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
              decoration: BoxDecoration(
                color: NexusColors.warn.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(NxRadius.md),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.clock, size: 16, color: NexusColors.warn),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'GitHub needs you to authorise Nexus again before it can sync.',
                      style: NxText.sans(size: 13.5, color: c.ink),
                    ),
                  ),
                  NxButton('Reconnect', compact: true, onPressed: () => connectGithub(context, ref)),
                ],
              ),
            ),
          ),
        const NxSectionHeader('Recent commits'),
        if (pulseAsync.isLoading && pulse == null)
          const NxSkeleton(height: 180, radius: NxRadius.md)
        else if (commits.isEmpty)
          Text('No commits in the last few days.', style: NxText.muted(context))
        else
          for (final (i, cm) in commits.take(8).indexed)
            CommitRow(commit: cm, repo: cm.obj('repository')?.str('name'), first: i == 0),
        NxSectionHeader(
          'Open pull requests',
          actionLabel: 'All pull requests',
          onAction: () => context.go('/github/pulls'),
        ),
        if (pulseAsync.isLoading && pulse == null)
          const NxSkeleton(height: 140, radius: NxRadius.md)
        else if (open.isEmpty)
          Text('Nothing waiting on you.', style: NxText.muted(context))
        else
          for (final (i, p) in open.take(6).indexed) PullRow(pull: p, showRepo: true, first: i == 0),
        if (merged.isNotEmpty) ...[
          const NxSectionHeader('Recently merged', top: 22),
          for (final (i, p) in merged.take(4).indexed) PullRow(pull: p, showRepo: true, merged: true, first: i == 0),
        ],
        NxSectionHeader('Repositories · ${shown.length}'),
        NxPillNav<bool>(
          items: const [(false, 'All'), (true, 'Starred')],
          value: _starredOnly,
          onChanged: (v) => setState(() => _starredOnly = v),
        ),
        const SizedBox(height: 8),
        if (reposAsync.isLoading && repos.isEmpty)
          const NxSkeleton(height: 240, radius: NxRadius.md)
        else if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _starredOnly
                  ? 'No starred repositories yet.'
                  : 'No repositories synced yet — hit Sync to pull them from GitHub.',
              style: NxText.muted(context),
            ),
          )
        else
          for (final (i, r) in shown.indexed) RepoRow(repo: r, first: i == 0),
      ],
    );
  }
}
