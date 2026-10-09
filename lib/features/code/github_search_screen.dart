import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/design/debounced_search.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';
import 'package:nexus_mobile/features/code/code_widgets.dart';
import 'package:nexus_mobile/features/code/github.dart';
import 'package:nexus_mobile/features/code/github_screen.dart';
import 'package:nexus_mobile/features/home/home_modules.dart';

const _types = [('repositories', 'Repositories'), ('issues', 'Issues & PRs'), ('code', 'Code')];

final _githubSearchProvider = FutureProvider.autoDispose.family<Json, (String, String)>(
  (ref, k) => ref.watch(githubApiProvider).search(k.$1, k.$2),
);

/// Web GithubSearchView: repositories, issues / PRs and code across GitHub.
class GithubSearchScreen extends ConsumerStatefulWidget {
  const GithubSearchScreen({super.key});

  @override
  ConsumerState<GithubSearchScreen> createState() => _GithubSearchScreenState();
}

class _GithubSearchScreenState extends ConsumerState<GithubSearchScreen> with DebouncedSearch {
  String _type = 'repositories';

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(githubStatusProvider);
    final connected = status.value?.flag('connected') ?? false;

    return NxPage(
      children: [
        const NxStage(
          compact: true,
          eyebrow: 'Code',
          title: 'Search',
          accent: 'GitHub',
          lede: 'Repositories, issues, pull requests and code across everything you can see.',
        ),
        const SizedBox(height: 22),
        const CodeNav(value: '/github/search'),
        const SizedBox(height: 16),
        if (status.isLoading && status.value == null)
          const NxSkeleton(height: 240, radius: NxRadius.md)
        else if (!connected)
          const ConnectGithubState()
        else ...[
          NxSearchField(
            controller: searchController,
            hint: 'Search GitHub…',
            autofocus: true,
            onChanged: onSearchChanged,
            onSubmitted: submitSearch,
          ),
          const SizedBox(height: 12),
          NxPillNav<String>(items: _types, value: _type, onChanged: (t) => setState(() => _type = t)),
          const SizedBox(height: 12),
          if (searched.isEmpty)
            const NxEmptyState(
              compact: true,
              icon: LucideIcons.search,
              title: 'Start typing',
              body: 'GitHub search qualifiers work too — try user:, repo:, is:pr or language:.',
            )
          else
            NxAsync(
              value: ref.watch(_githubSearchProvider((searched, _type))),
              onRetry: () => ref.invalidate(_githubSearchProvider((searched, _type))),
              loading: const NxSkeleton(height: 300, radius: NxRadius.md),
              data: (result) => _results(context, result),
            ),
        ],
      ],
    );
  }

  Widget _results(BuildContext context, Json result) {
    final c = context.nx;
    final hits = result.list('items');
    if (hits.isEmpty) {
      return NxEmptyState(
        compact: true,
        icon: LucideIcons.search,
        title: 'No results',
        body: 'Nothing matched “$searched”.',
      );
    }
    Widget external({
      required bool first,
      required IconData icon,
      required String title,
      required String meta,
      String? url,
      Color? tone,
    }) => InkWell(
      onTap: () => openExternal(url),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: first ? null : Border(top: BorderSide(color: c.line)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: tone ?? c.ink3),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: NxText.sans(weight: FontWeight.w600, color: c.ink),
                  ),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: NxText.sans(size: 12.5, color: c.ink3),
                  ),
                ],
              ),
            ),
            Icon(LucideIcons.externalLink, size: 14, color: c.ink3),
          ],
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            '${NumberFormat.decimalPattern().format(result.integer('total_count') ?? hits.length)} results',
            style: NxText.muted(context, size: 12.5),
          ),
        ),
        for (final (i, hit) in hits.indexed)
          switch (_type) {
            'repositories' => RepoRow(repo: hit, first: i == 0, stars: hit.integer('stargazers_count')),
            'issues' when hit.flag('is_pull_request') => PullRow(pull: hit, showRepo: true, first: i == 0),
            'issues' => external(
              first: i == 0,
              icon: LucideIcons.circleDot,
              tone: hit.str('state') == 'closed' ? c.ink3 : NexusColors.ok,
              title: hit.text('title'),
              meta:
                  '${hit.obj('repository')?.text('full_name')} · issue #${hit.integer('number')} · ${hit.text('state')}',
              url: hit.str('html_url'),
            ),
            _ => external(
              first: i == 0,
              icon: LucideIcons.fileCode,
              title: hit.text('name'),
              meta: '${hit.obj('repository')?.text('full_name')} · ${hit.text('path')}',
              url: hit.str('html_url'),
            ),
          },
      ],
    );
  }
}
