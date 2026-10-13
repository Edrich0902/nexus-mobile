import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/core/format.dart';
import 'package:nexus_mobile/design/profile.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';
import 'package:nexus_mobile/features/code/code_widgets.dart';
import 'package:nexus_mobile/features/code/github.dart';
import 'package:nexus_mobile/features/code/github_screen.dart';
import 'package:nexus_mobile/features/collections/collection_fields.dart';
import 'package:nexus_mobile/features/home/home_modules.dart';

/// Web GithubStatsView: contribution calendar, streaks, recent activity,
/// languages and the most active repositories.
class GithubStatsScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<GithubStatsScreen> createState() => _GithubStatsScreenState();
}

class _GithubStatsScreenState extends ConsumerState<GithubStatsScreen> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    try {
      await ref.read(githubApiProvider).stats(refresh: true);
      ref.invalidate(githubStatsProvider);
    } on Object catch (e) {
      if (mounted) showApiError(context, e, 'Could not refresh stats.');
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(githubStatusProvider);
    final connected = status.value?.flag('connected') ?? false;
    final statsAsync = connected ? ref.watch(githubStatsProvider) : null;
    final s = statsAsync?.value;

    final eyebrow = switch (s?.date('computed_at')) {
      final at? => 'Last 12 months · updated ${relativeTime(at)}',
      null => 'Last 12 months',
    };
    final lede = s == null
        ? null
        : (s.integer('current_streak') ?? 0) == 0
        ? 'Longest streak this year: ${plural(s.integer('longest_streak') ?? 0, 'day')}.'
        : 'On a ${plural(s.integer('current_streak') ?? 0, 'day')} streak — the longest this year was '
              '${plural(s.integer('longest_streak') ?? 0, 'day')}.';

    return NxPage(
      onRefresh: () async {
        ref.invalidate(githubStatsProvider);
        if (connected) await ref.read(githubStatsProvider.future);
      },
      children: [
        NxStage(
          compact: true,
          eyebrow: eyebrow,
          title: s == null ? 'Your' : NumberFormat.decimalPattern().format(s.integer('total_contributions') ?? 0),
          accent: 'contributions',
          lede: lede,
          actions: [
            if (connected)
              NxButton(
                'Refresh',
                icon: LucideIcons.refreshCw,
                variant: NxButtonVariant.secondary,
                loading: _refreshing,
                onPressed: _refresh,
              ),
          ],
        ),
        const SizedBox(height: 22),
        const CodeNav(value: '/github/stats'),
        const SizedBox(height: 4),
        if (status.isLoading && status.value == null)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: NxSkeleton(height: 300, radius: NxRadius.lg),
          )
        else if (!connected)
          const Padding(padding: EdgeInsets.only(top: 12), child: ConnectGithubState())
        else
          NxAsync(
            value: statsAsync!,
            onRetry: () => ref.invalidate(githubStatsProvider),
            loading: const Padding(
              padding: EdgeInsets.only(top: 12),
              child: NxSkeleton(height: 300, radius: NxRadius.lg),
            ),
            data: (s) => s.isEmpty
                ? const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: NxEmptyState(
                      icon: LucideIcons.chartColumn,
                      title: 'Stats are not ready yet',
                      body: 'Contribution stats are computed after the first GitHub sync. Try refreshing in a minute.',
                    ),
                  )
                : _ready(context, s),
          ),
      ],
    );
  }

  Widget _ready(BuildContext context, Json s) {
    final spark = s.list('sparkline');
    final values = [for (final p in spark) (p.integer('count') ?? 0).toDouble()];
    String day(String? iso) {
      final d = iso == null ? null : DateTime.tryParse('${iso}T12:00:00');
      return d == null ? (iso ?? '') : DateFormat('d MMM').format(d);
    }

    final languages = s.list('languages');
    final total = languages.fold<int>(0, (a, l) => a + (l.integer('count') ?? 0));
    final current = s.integer('current_streak') ?? 0;
    final longest = s.integer('longest_streak') ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CollectionFields(
          section: SectionKey.code,
          fields: [
            CollectionField(
              key: 'streak',
              label: 'Current streak',
              value: '$current',
              sub: current == 1 ? 'day' : 'days',
            ),
            CollectionField(
              key: 'longest',
              label: 'Longest streak',
              value: '$longest',
              sub: longest == 1 ? 'day' : 'days',
              variant: FieldVariant.tint,
            ),
            CollectionField(
              key: 'open',
              label: 'Open PRs',
              value: '${s.integer('open_pr_count') ?? 0}',
              variant: FieldVariant.tint,
              to: '/github/pulls',
            ),
            CollectionField(
              key: 'merged',
              label: 'Merged PRs',
              value: '${s.integer('merged_pr_count') ?? 0}',
              variant: FieldVariant.outline,
            ),
          ],
        ),
        const NxSectionHeader('Contribution calendar'),
        NxPanel(
          child: ContributionGrid(
            weeks: s.obj('calendar')?.list('weeks') ?? const [],
            total: s.integer('total_contributions'),
          ),
        ),
        NxSectionHeader('Last ${spark.length} days · ${values.fold<double>(0, (a, b) => a + b).round()}'),
        if (spark.isEmpty)
          Text('No recent activity.', style: NxText.muted(context))
        else
          NxPanel(
            child: NxHourBars(
              values,
              height: 140,
              ticks: [
                day(spark.first.str('date')),
                day(spark[spark.length ~/ 2].str('date')),
                day(spark.last.str('date')),
              ],
            ),
          ),
        const NxSectionHeader('Languages'),
        if (languages.isEmpty)
          Text('No language data yet.', style: NxText.muted(context))
        else
          NxMeters(labelWidth: 96, showWords: true, [
            for (final l in languages.take(8))
              ProfileAxis(
                l.text('language'),
                total == 0 ? 0 : (l.integer('count') ?? 0) / total,
                '${total == 0 ? 0 : ((l.integer('count') ?? 0) / total * 100).round()}%',
              ),
          ]),
        if (s.list('top_repos').isNotEmpty) ...[
          const NxSectionHeader('Most active repositories'),
          for (final (i, r) in s.list('top_repos').indexed) RepoRow(repo: r, first: i == 0),
        ],
      ],
    );
  }
}
