import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/core/format.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';
import 'package:nexus_mobile/features/code/code_widgets.dart';
import 'package:nexus_mobile/features/code/github.dart';

enum _Tab { pulls, commits, branches }

/// Web GithubRepoView: pull requests, commits and branches for one repository.
class GithubRepoScreen extends ConsumerStatefulWidget {
  const GithubRepoScreen({required this.owner, required this.repo, super.key});

  final String owner;
  final String repo;

  @override
  ConsumerState<GithubRepoScreen> createState() => _GithubRepoScreenState();
}

class _GithubRepoScreenState extends ConsumerState<GithubRepoScreen> {
  _Tab _tab = _Tab.pulls;
  String _filter = 'open';
  bool _starBusy = false;
  bool? _starred;

  RepoKey get _key => (owner: widget.owner, repo: widget.repo);

  Future<void> _toggleStar(bool current) async {
    setState(() => _starBusy = true);
    try {
      final next = await ref.read(githubApiProvider).setStar(widget.owner, widget.repo, starred: !current);
      setState(() => _starred = next);
      ref.invalidate(githubReposProvider);
    } on Object catch (e) {
      if (mounted) showApiError(context, e, 'Could not update the star.');
    } finally {
      if (mounted) setState(() => _starBusy = false);
    }
  }

  Future<void> _createBranch(String? defaultBranch, List<Json> branches) async {
    final created = await showNxSheet<bool>(
      context,
      title: 'New branch',
      builder: (_) => _BranchForm(
        repo: _key,
        branches: [for (final b in branches) b.text('name')],
        from: defaultBranch ?? branches.firstOrNull?.str('name'),
      ),
    );
    if (created ?? false) ref.invalidate(githubBranchesProvider(_key));
  }

  Future<void> _deleteBranch(String branch) async {
    final ok = await showNxConfirm(context, message: 'Delete branch “$branch”?');
    if (!ok) return;
    try {
      await ref.read(githubApiProvider).deleteBranch(widget.owner, widget.repo, branch);
      ref.invalidate(githubBranchesProvider(_key));
      if (mounted) showNxToast(context, 'Branch deleted.');
    } on Object catch (e) {
      if (mounted) showApiError(context, e, 'Could not delete the branch.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    final info = ref
        .watch(githubReposProvider)
        .value
        ?.where((r) => r.str('owner') == widget.owner && r.str('name') == widget.repo)
        .firstOrNull;
    final current = ref.watch(githubRepoProvider(_key)).value;
    final defaultBranch = current?.str('default_branch') ?? info?.str('default_branch');
    final starred = _starred ?? current?.flag('starred') ?? info?.flag('starred') ?? false;
    final language = current?.str('language') ?? info?.str('language');
    final isPrivate = current?.flag('private') ?? info?.flag('private') ?? false;
    final pushed = current?.date('pushed_at') ?? info?.date('pushed_at');
    final description = current?.str('description') ?? info?.str('description');
    final url = current?.str('html_url') ?? info?.str('html_url');

    return NxPage(
      onRefresh: () async {
        ref
          ..invalidate(githubRepoProvider(_key))
          ..invalidate(githubRepoPullsProvider((_key, _filter)))
          ..invalidate(githubCommitsProvider(_key))
          ..invalidate(githubBranchesProvider(_key));
      },
      children: [
        NxStage(
          compact: true,
          eyebrow: [
            widget.owner,
            if (isPrivate) 'Private' else 'Public',
            if (pushed != null) 'pushed ${relativeTime(pushed)}',
          ].join(' · '),
          title: widget.repo,
          lede: description ?? (defaultBranch == null ? null : 'Default branch $defaultBranch.'),
          actions: [
            NxButton(
              'New pull request',
              icon: LucideIcons.plus,
              onPressed: () => context.push('/github/${widget.owner}/${widget.repo}/pulls/new'),
            ),
            if (url != null)
              NxIconButton(LucideIcons.externalLink, tooltip: 'Open on GitHub', onPressed: () => openExternal(url)),
            NxIconButton(
              starred ? LucideIcons.starOff : LucideIcons.star,
              tooltip: starred ? 'Unstar repository' : 'Star repository',
              filled: starred,
              onPressed: _starBusy ? null : () => _toggleStar(starred),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: NxPillNav<_Tab>(
                items: const [(_Tab.pulls, 'Pull requests'), (_Tab.commits, 'Commits'), (_Tab.branches, 'Branches')],
                value: _tab,
                onChanged: (t) => setState(() => _tab = t),
              ),
            ),
            if (language != null) ...[
              const SizedBox(width: 10),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: languageColour(language) ?? c.ink3, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Text(language, style: NxText.sans(size: 12.5, color: c.ink2)),
            ],
          ],
        ),
        const SizedBox(height: 12),
        switch (_tab) {
          _Tab.pulls => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NxPillNav<String>(items: pullFilters, value: _filter, onChanged: (f) => setState(() => _filter = f)),
              const SizedBox(height: 8),
              NxAsync(
                value: ref.watch(githubRepoPullsProvider((_key, _filter))),
                onRetry: () => ref.invalidate(githubRepoPullsProvider((_key, _filter))),
                loading: const NxSkeleton(height: 220, radius: NxRadius.md),
                data: (pulls) => pulls.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('No pull requests for this filter.', style: NxText.muted(context)),
                      )
                    : Column(
                        children: [
                          for (final (i, p) in pulls.indexed)
                            PullRow(pull: p, owner: widget.owner, repo: widget.repo, first: i == 0),
                        ],
                      ),
              ),
            ],
          ),
          _Tab.commits => NxAsync(
            value: ref.watch(githubCommitsProvider(_key)),
            onRetry: () => ref.invalidate(githubCommitsProvider(_key)),
            loading: const NxSkeleton(height: 300, radius: NxRadius.md),
            data: (commits) => commits.isEmpty
                ? Text('No commits found.', style: NxText.muted(context))
                : Column(
                    children: [for (final (i, cm) in commits.indexed) CommitRow(commit: cm, first: i == 0)],
                  ),
          ),
          _Tab.branches => NxAsync(
            value: ref.watch(githubBranchesProvider(_key)),
            onRetry: () => ref.invalidate(githubBranchesProvider(_key)),
            loading: const NxSkeleton(height: 220, radius: NxRadius.md),
            data: (branches) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: NxButton(
                    'New branch',
                    icon: LucideIcons.plus,
                    compact: true,
                    variant: NxButtonVariant.secondary,
                    onPressed: () => _createBranch(defaultBranch, branches),
                  ),
                ),
                const SizedBox(height: 8),
                if (branches.isEmpty)
                  Text('No branches found.', style: NxText.muted(context))
                else
                  for (final (i, b) in branches.indexed)
                    _BranchRow(
                      name: b.text('name'),
                      isDefault: b.str('name') == defaultBranch,
                      protected: b.flag('protected'),
                      first: i == 0,
                      onOpenPull: () => context.push(
                        Uri(
                          path: '/github/${widget.owner}/${widget.repo}/pulls/new',
                          queryParameters: {'head': b.text('name')},
                        ).toString(),
                      ),
                      onDelete: () => _deleteBranch(b.text('name')),
                    ),
              ],
            ),
          ),
        },
      ],
    );
  }
}

class _BranchRow extends StatelessWidget {
  const _BranchRow({
    required this.name,
    required this.isDefault,
    required this.protected,
    required this.first,
    required this.onOpenPull,
    required this.onDelete,
  });

  final String name;
  final bool isDefault;
  final bool protected;
  final bool first;
  final VoidCallback onOpenPull;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    Widget tag(String label) => Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(color: c.tint2, borderRadius: BorderRadius.circular(NxRadius.pill)),
      child: Text(label, style: NxText.sans(size: 11, color: c.ink2)),
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: first ? null : Border(top: BorderSide(color: c.line)),
      ),
      child: Row(
        children: [
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: NxText.mono(size: 12.5, color: c.ink, weight: FontWeight.w600),
            ),
          ),
          if (isDefault) tag('Default'),
          if (protected) tag('Protected'),
          const Spacer(),
          if (!isDefault)
            TextButton(
              onPressed: onOpenPull,
              child: Text(
                'Open PR',
                style: NxText.sans(size: 13, weight: FontWeight.w600, color: c.acc),
              ),
            ),
          NxIconButton(
            LucideIcons.trash2,
            tooltip: 'Delete $name',
            size: 34,
            onPressed: isDefault || protected ? null : onDelete,
          ),
        ],
      ),
    );
  }
}

class _BranchForm extends ConsumerStatefulWidget {
  const _BranchForm({required this.repo, required this.branches, this.from});

  final RepoKey repo;
  final List<String> branches;
  final String? from;

  @override
  ConsumerState<_BranchForm> createState() => _BranchFormState();
}

class _BranchFormState extends ConsumerState<_BranchForm> {
  final _name = TextEditingController();
  late String? _from = widget.from;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(githubApiProvider).createBranch(widget.repo.owner, widget.repo.repo, name: name, from: _from);
      if (mounted) {
        showNxToast(context, 'Branch $name created.');
        Navigator.of(context).pop(true);
      }
    } on Object catch (e) {
      if (mounted) showApiError(context, e, 'Could not create the branch.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      NxForm(
        children: [
          NxTextField(label: 'Name', hint: 'feature/my-change', controller: _name, autofocus: true),
          NxPickerField<String>(
            label: 'From',
            options: [for (final b in widget.branches) (b, b)],
            value: _from,
            searchable: widget.branches.length > 8,
            clearable: false,
            onChanged: (v) => setState(() => _from = v),
          ),
        ],
      ),
      NxSheetActions(label: 'Create branch', busy: _saving, onSubmit: _name.text.trim().isEmpty ? null : _save),
    ],
  );
}
