import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/core/format.dart';
import 'package:nexus_mobile/core/native/open_external.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';
import 'package:nexus_mobile/features/code/code_widgets.dart';
import 'package:nexus_mobile/features/code/github.dart';
import 'package:nexus_mobile/features/home/home_modules.dart';

const _mergeOptions = [
  ('squash', 'Squash and merge'),
  ('merge', 'Create a merge commit'),
  ('rebase', 'Rebase and merge'),
];

const _reviewLabel = {
  'APPROVED': 'Approved',
  'CHANGES_REQUESTED': 'Requested changes',
  'COMMENTED': 'Commented',
  'DISMISSED': 'Dismissed',
  'PENDING': 'Pending',
};

/// Web GithubPullDetailView: description, reviews (and a review form),
/// merge / draft controls and the changed files.
class GithubPullScreen extends ConsumerStatefulWidget {
  const new({required this.owner, required this.repo, required this.number, super.key});

  final String owner;
  final String repo;
  final int number;

  @override
  ConsumerState<GithubPullScreen> createState() => _GithubPullScreenState();
}

class _GithubPullScreenState extends ConsumerState<GithubPullScreen> {
  final _review = TextEditingController();
  String _mergeMethod = 'squash';
  String? _busy;

  PullKey get _key => (owner: widget.owner, repo: widget.repo, number: widget.number);

  @override
  void initState() {
    super.initState();
    _review.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _review.dispose();
    super.dispose();
  }

  Future<void> _run(String action, Future<void> Function() task, {String? done}) async {
    setState(() => _busy = action);
    try {
      await task();
      ref
        ..invalidate(githubPullProvider(_key))
        ..invalidate(githubPulseProvider);
      if (done != null && mounted) showNxToast(context, done);
    } on Object catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _merge() async {
    final label = _mergeOptions.firstWhere((o) => o.$1 == _mergeMethod).$2;
    final ok = await showNxConfirm(
      context,
      message: '$label #${widget.number}?',
      confirmLabel: 'Merge',
      cancelLabel: 'Cancel',
    );
    if (!ok) return;
    await _run('merge', () async {
      final result = await ref.read(githubApiProvider).merge(_key, _mergeMethod);
      if (!result.flag('merged')) throw StateError(result.text('message', 'GitHub did not merge this pull request.'));
    }, done: 'Merged.');
  }

  Future<void> _submitReview(String event) async {
    final body = _review.text.trim();
    if (event != 'APPROVE' && body.isEmpty) return;
    await _run(event, () async {
      await ref.read(githubApiProvider).review(_key, event: event, body: body.isEmpty ? null : body);
      _review.clear();
    }, done: 'Review submitted.');
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(githubPullProvider(_key));
    return NxPage(
      onRefresh: () async {
        ref.invalidate(githubPullProvider(_key));
        await ref.read(githubPullProvider(_key).future);
      },
      children: [
        NxAsync(
          value: async,
          onRetry: () => ref.invalidate(githubPullProvider(_key)),
          data: (d) => _body(context, d.pull, d.files, d.reviews),
        ),
      ],
    );
  }

  Widget _body(BuildContext context, Json pull, List<Json> files, List<Json> reviews) {
    final c = context.nx;
    final kind = pullState(pull);
    final isOpen = kind == PullState.open || kind == PullState.draft;
    final canMerge = isOpen && !pull.flag('draft') && pull['mergeable'] != false;
    final comments = (pull.integer('comments') ?? 0) + (pull.integer('review_comments') ?? 0);

    final lede = [
      '${pull.obj('head')?.str('ref') ?? '?'} → ${pull.obj('base')?.str('ref') ?? '?'}',
      if (pull.integer('commits') case final n?) plural(n, 'commit'),
      if (pull.integer('changed_files') case final n?) plural(n, 'file'),
      if (pull.obj('user')?.str('login') case final login?) 'opened by $login ${relativeTime(pull.date('created_at'))}',
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NxStage(
          compact: true,
          eyebrow: '${widget.owner}/${widget.repo} · #${widget.number} · ${kind.label}',
          title: pull.text('title', 'Pull #${widget.number}'),
          lede: lede,
          actions: [
            if (isOpen && pull.flag('draft'))
              NxButton(
                'Ready for review',
                loading: _busy == 'ready',
                onPressed: () => _run('ready', () => ref.read(githubApiProvider).markReady(_key)),
              )
            else if (isOpen)
              NxButton(
                'Convert to draft',
                variant: NxButtonVariant.secondary,
                loading: _busy == 'draft',
                onPressed: () => _run('draft', () => ref.read(githubApiProvider).convertToDraft(_key)),
              ),
            if (pull.str('html_url') case final url?)
              NxIconButton(LucideIcons.externalLink, tooltip: 'Open on GitHub', onPressed: () => openExternal(url)),
          ],
        ),
        if (isOpen && pull['mergeable'] == false)
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: NexusColors.bad.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(NxRadius.md),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(LucideIcons.x, size: 16, color: NexusColors.bad),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'This branch has conflicts with ${pull.obj('base')?.text('ref')} — resolve them on GitHub before merging.',
                      style: NxText.sans(size: 13.5, color: c.ink, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (canMerge) ...[
          const NxSectionHeader('Merge'),
          NxPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                NxPickerField<String>(
                  label: 'Method',
                  options: _mergeOptions,
                  value: _mergeMethod,
                  clearable: false,
                  onChanged: (v) => setState(() => _mergeMethod = v ?? 'squash'),
                ),
                const SizedBox(height: 12),
                NxButton('Merge', icon: LucideIcons.check, wide: true, loading: _busy == 'merge', onPressed: _merge),
              ],
            ),
          ),
        ],
        const NxSectionHeader('Description'),
        if (pull.str('body') case final body?)
          SelectableText(body, style: NxText.sans(size: 14.5, color: c.ink, height: 1.55))
        else
          Text('No description provided.', style: NxText.muted(context)),
        const SizedBox(height: 10),
        Row(
          children: [
            Text('+${pull.integer('additions') ?? 0}', style: NxText.mono(size: 12.5, color: NexusColors.ok)),
            const SizedBox(width: 10),
            Text('−${pull.integer('deletions') ?? 0}', style: NxText.mono(size: 12.5, color: NexusColors.bad)),
            if (comments > 0) ...[
              const SizedBox(width: 10),
              Text(plural(comments, 'comment'), style: NxText.sans(size: 12.5, color: c.ink3)),
            ],
          ],
        ),
        NxSectionHeader('Reviews · ${reviews.length}'),
        if (reviews.isEmpty) Text('No reviews yet.', style: NxText.muted(context)),
        for (final (i, r) in reviews.indexed) _ReviewRow(review: r, first: i == 0),
        if (isOpen) ...[
          const SizedBox(height: 14),
          NxTextField(
            label: 'Review',
            hint: 'Leave a review — a comment is required to request changes.',
            controller: _review,
            maxLines: 4,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              NxButton(
                'Approve',
                compact: true,
                loading: _busy == 'APPROVE',
                onPressed: _busy == null ? () => _submitReview('APPROVE') : null,
              ),
              NxButton(
                'Request changes',
                compact: true,
                variant: NxButtonVariant.secondary,
                loading: _busy == 'REQUEST_CHANGES',
                onPressed: _review.text.trim().isEmpty || _busy != null ? null : () => _submitReview('REQUEST_CHANGES'),
              ),
              NxButton(
                'Comment',
                compact: true,
                variant: NxButtonVariant.ghost,
                loading: _busy == 'COMMENT',
                onPressed: _review.text.trim().isEmpty || _busy != null ? null : () => _submitReview('COMMENT'),
              ),
            ],
          ),
        ],
        NxSectionHeader('Files changed · ${files.length}'),
        DiffViewer(files: files),
      ],
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const new({required this.review, required this.first});

  final Json review;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    final state = review.str('state');
    final tone = switch (state) {
      'APPROVED' => NexusColors.ok,
      'CHANGES_REQUESTED' => NexusColors.bad,
      _ => c.ink3,
    };
    final user = review.obj('user');
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: first ? null : Border(top: BorderSide(color: c.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GithubAvatar(url: user?.str('avatar_url'), size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      user?.str('login') ?? 'Someone',
                      style: NxText.sans(weight: FontWeight.w600, color: c.ink),
                    ),
                    Text(
                      _reviewLabel[state] ?? state ?? '',
                      style: NxText.sans(size: 12.5, weight: FontWeight.w600, color: tone),
                    ),
                    Text(relativeTime(review.date('submitted_at')), style: NxText.sans(size: 12, color: c.ink3)),
                  ],
                ),
                if (review.str('body') case final body?)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(body, style: NxText.sans(size: 13.5, color: c.ink2, height: 1.45)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
