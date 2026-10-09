import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/core/format.dart';
import 'package:nexus_mobile/core/native/open_external.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';
import 'package:nexus_mobile/features/code/github.dart';

/// Overview · Pull requests · Search · Stats (web CodeNav).
class CodeNav extends StatelessWidget {
  const CodeNav({required this.value, super.key});

  final String value;

  @override
  Widget build(BuildContext context) => NxPillNav<String>(
    items: const [
      ('/github', 'Overview'),
      ('/github/pulls', 'Pull requests'),
      ('/github/search', 'Search'),
      ('/github/stats', 'Stats'),
    ],
    value: value,
    onChanged: (to) => to == value ? null : context.go(to),
  );
}

/// GitHub avatars are third-party URLs; NxImage keeps them on the shared cache.
class GithubAvatar extends StatelessWidget {
  const GithubAvatar({required this.url, this.size = 26, super.key});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: NxImage(url: url, radius: size, avatar: true, fallbackIcon: LucideIcons.user),
  );
}

class _Meta extends StatelessWidget {
  const _Meta(this.parts);

  final List<String> parts;

  @override
  Widget build(BuildContext context) => Text(
    parts.where((p) => p.isNotEmpty).join(' · '),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: NxText.sans(size: 12.5, color: context.nx.ink3),
  );
}

class _Hairline extends StatelessWidget {
  const _Hairline({required this.child, this.onTap, this.first = false});

  final Widget child;
  final VoidCallback? onTap;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final body = Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: first ? null : Border(top: BorderSide(color: context.nx.line)),
      ),
      child: child,
    );
    return onTap == null ? body : InkWell(onTap: onTap, child: body);
  }
}

/// A repository: owner/name, description, language and last push (web RepoRow).
class RepoRow extends StatelessWidget {
  const RepoRow({required this.repo, this.first = false, this.stars, super.key});

  final Json repo;
  final bool first;
  final int? stars;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    final (owner, name) = (repo.str('owner'), repo.str('name'));
    final language = repo.str('language');
    return _Hairline(
      first: first,
      onTap: owner != null && name != null
          ? () => context.push('/github/$owner/$name')
          : () => openExternal(repo.str('html_url')),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${owner ?? ''}/',
                        style: TextStyle(color: c.ink3, fontWeight: FontWeight.w400),
                      ),
                      TextSpan(text: name ?? repo.text('full_name')),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: NxText.sans(weight: FontWeight.w600, color: c.ink),
                ),
              ),
              if (repo.flag('private')) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(
                    border: Border.all(color: c.lineStrong),
                    borderRadius: BorderRadius.circular(NxRadius.pill),
                  ),
                  child: Text('Private', style: NxText.sans(size: 11, color: c.ink3)),
                ),
              ],
              if (repo.flag('starred')) ...[
                const SizedBox(width: 6),
                Icon(LucideIcons.star, size: 14, color: c.acc),
              ],
            ],
          ),
          if (repo.str('description') case final d?)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                d,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: NxText.sans(size: 13, color: c.ink2, height: 1.4),
              ),
            ),
          const SizedBox(height: 5),
          Row(
            children: [
              if (language != null) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: languageColour(language) ?? c.ink3, shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
              ],
              Expanded(
                child: _Meta([
                  ?language,
                  if (stars != null) '★ $stars',
                  if (repo.date('pushed_at') case final at?) 'Pushed ${relativeTime(at)}',
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A pull request with a state dot; opens the in-app detail (web PullRow).
class PullRow extends StatelessWidget {
  const PullRow({
    required this.pull,
    this.owner,
    this.repo,
    this.showRepo = false,
    this.first = false,
    this.merged = false,
    super.key,
  });

  final Json pull;
  final String? owner;
  final String? repo;
  final bool showRepo;
  final bool first;
  final bool merged;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    final r = pull.obj('repository');
    final o = owner ?? r?.str('owner');
    final n = repo ?? r?.str('name');
    final number = pull.integer('number');
    final kind = merged ? PullState.merged : pullState(pull);
    final tone = switch (kind) {
      PullState.open => NexusColors.ok,
      PullState.draft => c.ink3,
      PullState.merged => const Color(0xFFA371F7),
      PullState.closed => NexusColors.bad,
    };
    final user = pull.obj('user');
    return _Hairline(
      first: first,
      onTap: o != null && n != null && number != null
          ? () => context.push('/github/$o/$n/pulls/$number')
          : () => openExternal(pull.str('html_url')),
      child: Row(
        children: [
          Tooltip(
            message: kind.label,
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pull.text('title', 'Untitled'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: NxText.sans(weight: FontWeight.w600, color: c.ink, height: 1.35),
                ),
                const SizedBox(height: 2),
                _Meta([
                  if (showRepo && o != null && n != null) '$o/$n',
                  '#${number ?? '?'}',
                  if (kind != PullState.open) kind.label,
                  if (user?.str('login') case final login?) 'by $login',
                  if (pull.date('updated_at') case final at?) 'updated ${relativeTime(at)}',
                ]),
              ],
            ),
          ),
          if (user?.str('avatar_url') case final avatar?) ...[
            const SizedBox(width: 10),
            GithubAvatar(url: avatar),
          ],
        ],
      ),
    );
  }
}

/// A commit: subject line, where and when, and the short SHA (web CommitRow).
class CommitRow extends StatelessWidget {
  const CommitRow({required this.commit, this.repo, this.first = false, super.key});

  final Json commit;
  final String? repo;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    return _Hairline(
      first: first,
      onTap: commit.str('html_url') == null ? null : () => openExternal(commit.str('html_url')),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  firstLine(commit.str('message')),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: NxText.sans(weight: FontWeight.w500, color: c.ink, height: 1.35),
                ),
                const SizedBox(height: 2),
                _Meta([
                  ?repo,
                  ?commit.str('author_name'),
                  if (commit.date('author_date') case final at?) relativeTime(at),
                ]),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(shortSha(commit.str('sha')), style: NxText.mono(color: c.ink3)),
        ],
      ),
    );
  }
}

/// Changed files with expandable unified diffs (web NexusGithubDiffViewer,
/// single-column for phones).
class DiffViewer extends StatefulWidget {
  const DiffViewer({required this.files, super.key});

  final List<Json> files;

  @override
  State<DiffViewer> createState() => _DiffViewerState();
}

class _DiffViewerState extends State<DiffViewer> {
  final _open = <String>{};

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    if (widget.files.isEmpty) return Text('No file changes to show.', style: NxText.muted(context));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, f) in widget.files.indexed)
          Builder(
            builder: (context) {
              final key = f.str('filename') ?? f.str('sha') ?? 'file-$i';
              final open = _open.contains(key);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: c.line),
                  borderRadius: BorderRadius.circular(NxRadius.md),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      button: true,
                      expanded: open,
                      child: InkWell(
                        onTap: () => setState(() => open ? _open.remove(key) : _open.add(key)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                          child: Row(
                            children: [
                              AnimatedRotation(
                                turns: open ? .25 : 0,
                                duration: NxMotion.hover,
                                child: Icon(LucideIcons.chevronRight, size: 14, color: c.ink3),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  f.text('filename', 'unknown file'),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: NxText.mono(size: 12, color: c.ink, weight: FontWeight.w600),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '+${f.integer('additions') ?? 0}',
                                style: NxText.mono(size: 12, color: NexusColors.ok),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '−${f.integer('deletions') ?? 0}',
                                style: NxText.mono(size: 12, color: NexusColors.bad),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (open)
                      f.str('patch') == null
                          ? Padding(
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                'Patch not available for this file (binary or too large).',
                                style: NxText.muted(context),
                              ),
                            )
                          : _Patch(patch: f.str('patch')!),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

class _Patch extends StatelessWidget {
  const _Patch({required this.patch});

  final String patch;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    final hunks = parseUnifiedDiff(patch);
    final style = NxText.mono(color: c.ink);
    Widget row(DiffLine l) {
      final bg = switch (l.kind) {
        DiffKind.add => NexusColors.ok.withValues(alpha: .14),
        DiffKind.del => NexusColors.bad.withValues(alpha: .14),
        _ => Colors.transparent,
      };
      final sign = switch (l.kind) {
        DiffKind.add => '+',
        DiffKind.del => '−',
        _ => ' ',
      };
      return ColoredBox(
        color: bg,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 34,
              child: Text(
                '${l.oldLine ?? ''}',
                textAlign: TextAlign.right,
                style: style.copyWith(color: c.ink4),
              ),
            ),
            SizedBox(
              width: 34,
              child: Text(
                '${l.newLine ?? ''}',
                textAlign: TextAlign.right,
                style: style.copyWith(color: c.ink4),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$sign ${l.text}',
              softWrap: false,
              style: l.kind == DiffKind.meta ? style.copyWith(color: c.ink3) : style,
            ),
            const SizedBox(width: 12),
          ],
        ),
      );
    }

    return ColoredBox(
      color: c.tint,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final h in hunks) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                child: Text(h.header, style: style.copyWith(color: c.acc)),
              ),
              for (final l in h.lines) row(l),
            ],
          ],
        ),
      ),
    );
  }
}

/// A year of contributions, one column per week, scrolled to today
/// (web ContributionGrid).
class ContributionGrid extends StatelessWidget {
  const ContributionGrid({required this.weeks, this.total, super.key});

  final List<Json> weeks;
  final int? total;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    final max = weeks
        .expand((w) => w.list('contribution_days'))
        .fold<int>(1, (m, d) => math.max(m, d.integer('count') ?? 0));
    int level(int count) => count <= 0 ? 0 : math.min(4, (count / max * 4).ceil());
    const cell = 11.0;
    const gap = 3.0;
    return Semantics(
      label: total == null ? 'Contribution calendar' : '$total contributions in the last year',
      child: SizedBox(
        height: 7 * (cell + gap),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          reverse: true,
          itemCount: weeks.length,
          itemBuilder: (context, i) {
            final week = weeks[weeks.length - 1 - i];
            return Padding(
              padding: const EdgeInsets.only(left: gap),
              child: Column(
                children: [
                  for (final d in week.list('contribution_days'))
                    Tooltip(
                      message: '${plural(d.integer('count') ?? 0, 'contribution')} · ${_day(d.str('date'))}',
                      child: Container(
                        width: cell,
                        height: cell,
                        margin: const EdgeInsets.only(bottom: gap),
                        decoration: BoxDecoration(
                          color: switch (level(d.integer('count') ?? 0)) {
                            0 => c.tint2,
                            final l => c.acc.withValues(alpha: .25 + l * .1875),
                          },
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  static String _day(String? iso) {
    final d = iso == null ? null : DateTime.tryParse('${iso}T12:00:00');
    return d == null ? (iso ?? '') : DateFormat('EEE d MMM y').format(d);
  }
}
