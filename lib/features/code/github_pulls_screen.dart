import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/core/format.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';
import 'package:nexus_mobile/features/code/code_widgets.dart';
import 'package:nexus_mobile/features/code/github.dart';
import 'package:nexus_mobile/features/code/github_screen.dart';
import 'package:nexus_mobile/features/home/home_modules.dart';

const _emptyBody = {
  'open': 'Nothing open — you are all caught up.',
  'merged': 'No merged pull requests yet.',
  'closed': 'No closed pull requests.',
  'all': 'No pull requests found.',
};

/// Web GithubPullsView: every pull request across your repositories.
class GithubPullsScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<GithubPullsScreen> createState() => _GithubPullsScreenState();
}

class _GithubPullsScreenState extends ConsumerState<GithubPullsScreen> {
  String _filter = 'open';

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(githubStatusProvider);
    final connected = status.value?.flag('connected') ?? false;
    final inbox = ref.watch(githubInboxProvider(_filter));
    final label = pullFilters.firstWhere((f) => f.$1 == _filter).$2.toLowerCase();
    final lede = inbox.value == null
        ? 'Across every repository you have access to.'
        : '${plural(inbox.value!.length, '$label pull request')} across your repositories.';

    return NxPage(
      onRefresh: () async {
        ref.invalidate(githubInboxProvider(_filter));
        await ref.read(githubInboxProvider(_filter).future);
      },
      children: [
        NxStage(compact: true, eyebrow: 'Code', title: 'Pull', accent: 'requests', lede: lede),
        const SizedBox(height: 22),
        const CodeNav(value: '/github/pulls'),
        const SizedBox(height: 16),
        if (status.isLoading && status.value == null)
          const NxSkeleton(height: 240, radius: NxRadius.md)
        else if (!connected)
          const ConnectGithubState()
        else ...[
          NxPillNav<String>(items: pullFilters, value: _filter, onChanged: (f) => setState(() => _filter = f)),
          const SizedBox(height: 10),
          NxAsync(
            value: inbox,
            onRetry: () => ref.invalidate(githubInboxProvider(_filter)),
            loading: const NxSkeleton(height: 300, radius: NxRadius.md),
            data: (pulls) => pulls.isEmpty
                ? NxEmptyState(
                    compact: true,
                    icon: LucideIcons.gitPullRequest,
                    title: 'No pull requests',
                    body: _emptyBody[_filter],
                  )
                : Column(
                    children: [for (final (i, p) in pulls.indexed) PullRow(pull: p, showRepo: true, first: i == 0)],
                  ),
          ),
        ],
      ],
    );
  }
}
