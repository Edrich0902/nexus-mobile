import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/core/format.dart';
import 'package:nexus_mobile/core/native/open_external.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';
import 'package:nexus_mobile/features/code/code_widgets.dart';
import 'package:nexus_mobile/features/code/github.dart';

final _compareProvider = FutureProvider.autoDispose.family<Json, (RepoKey, String, String)>(
  (ref, k) => ref.watch(githubApiProvider).compare(k.$1.owner, k.$1.repo, k.$2, k.$3),
);

/// Web GithubPullCreateView: pick base / head, see the comparison, open the PR.
class GithubPullCreateScreen extends ConsumerStatefulWidget {
  const new({required this.owner, required this.repo, this.head, super.key});

  final String owner;
  final String repo;
  final String? head;

  @override
  ConsumerState<GithubPullCreateScreen> createState() => _GithubPullCreateScreenState();
}

class _GithubPullCreateScreenState extends ConsumerState<GithubPullCreateScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  String? _base;
  String? _head;
  bool _draft = false;
  bool _seeded = false;
  bool _saving = false;

  RepoKey get _key => (owner: widget.owner, repo: widget.repo);

  @override
  void initState() {
    super.initState();
    _title.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _seed(List<Json> branches, String? defaultBranch) {
    if (_seeded || branches.isEmpty) return;
    _seeded = true;
    final names = [for (final b in branches) b.text('name')];
    _base = defaultBranch ?? names.first;
    _head = widget.head != null && names.contains(widget.head)
        ? widget.head
        : names.where((n) => n != _base).firstOrNull;
    if (_head != null && _title.text.isEmpty) _title.text = titleFromBranch(_head!);
  }

  bool get _comparable => _base != null && _head != null && _base != _head;

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty || !_comparable) return;
    setState(() => _saving = true);
    try {
      final pull = await ref
          .read(githubApiProvider)
          .createPull(
            widget.owner,
            widget.repo,
            title: _title.text.trim(),
            head: _head!,
            base: _base!,
            body: _body.text.trim().isEmpty ? null : _body.text.trim(),
            draft: _draft,
          );
      ref.invalidate(githubRepoPullsProvider((_key, 'open')));
      final number = pull.integer('number');
      if (mounted && number != null) context.pushReplacement('/github/${widget.owner}/${widget.repo}/pulls/$number');
    } on Object catch (e) {
      if (mounted) showApiError(context, e, 'Could not open the pull request.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    final branchesAsync = ref.watch(githubBranchesProvider(_key));
    final defaultBranch = ref.watch(githubRepoProvider(_key)).value?.str('default_branch');
    if (branchesAsync.value case final branches?) _seed(branches, defaultBranch);
    final compare = _comparable ? ref.watch(_compareProvider((_key, _base!, _head!))) : null;
    final r = compare?.value;

    final lede = () {
      if (!_comparable) return 'Choose two different branches to compare.';
      if (r == null) return 'Merging $_head into $_base.';
      return '${['Merging $_head into $_base', if (r.integer('total_commits') case final n?) plural(n, 'commit'), plural(r.list('files').length, 'file'), if ((r.integer('behind_by') ?? 0) > 0) '${r.integer('behind_by')} behind'].join(' · ')}.';
    }();

    final options = [for (final b in branchesAsync.value ?? const <Json>[]) (b.text('name'), b.text('name'))];

    return NxPage(
      children: [
        NxStage(
          compact: true,
          eyebrow: '${widget.owner}/${widget.repo}',
          title: 'New',
          accent: 'pull request',
          lede: lede,
        ),
        const SizedBox(height: 22),
        NxAsync(
          value: branchesAsync,
          onRetry: () => ref.invalidate(githubBranchesProvider(_key)),
          loading: const NxSkeleton(height: 260, radius: NxRadius.lg),
          data: (_) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NxForm(
                children: [
                  NxFormRow(
                    children: [
                      NxPickerField<String>(
                        label: 'Base',
                        options: options,
                        value: _base,
                        searchable: options.length > 8,
                        clearable: false,
                        onChanged: (v) => setState(() => _base = v),
                      ),
                      NxPickerField<String>(
                        label: 'Compare',
                        options: options,
                        value: _head,
                        searchable: options.length > 8,
                        clearable: false,
                        onChanged: (v) => setState(() => _head = v),
                      ),
                    ],
                  ),
                  NxTextField(label: 'Title', controller: _title),
                  NxTextField(label: 'Description', controller: _body, maxLines: 6, hint: 'What changed and why'),
                ],
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _draft,
                activeTrackColor: c.acc,
                onChanged: (v) => setState(() => _draft = v),
                title: Text('Open as draft', style: NxText.sans(color: c.ink)),
              ),
              const SizedBox(height: 8),
              NxButton(
                _draft ? 'Open draft pull request' : 'Open pull request',
                wide: true,
                loading: _saving,
                onPressed: _title.text.trim().isEmpty || !_comparable ? null : _submit,
              ),
            ],
          ),
        ),
        if (compare != null) ...[
          NxSectionHeader('Files changed · ${r?.list('files').length ?? '…'}'),
          if (r?.str('html_url') case final url?)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => openExternal(url),
                child: Text('Compare on GitHub', style: NxText.sans(size: 13, color: c.acc)),
              ),
            ),
          NxAsync(
            value: compare,
            onRetry: () => ref.invalidate(_compareProvider((_key, _base!, _head!))),
            loading: const NxSkeleton(height: 160, radius: NxRadius.md),
            data: (r) => DiffViewer(files: r.list('files')),
          ),
        ],
      ],
    );
  }
}
