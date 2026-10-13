import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/core/format.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';
import 'package:nexus_mobile/features/collections/collection_fields.dart';
import 'package:nexus_mobile/features/sports/sport_widgets.dart';
import 'package:nexus_mobile/features/sports/sports.dart';

/// Web SportView: the next fixture (or latest result) as the headline, then
/// fixtures, results, majors, league tables and followed competitions.
class SportScreen extends ConsumerStatefulWidget {
  const new({required this.sport, super.key});

  final String sport;

  @override
  ConsumerState<SportScreen> createState() => _SportScreenState();
}

class _SportScreenState extends ConsumerState<SportScreen> {
  bool _syncing = false;

  String get _label => sportLabels[widget.sport] ?? widget.sport;

  Future<void> _sync() async {
    setState(() => _syncing = true);
    await syncSports(context, ref, widget.sport);
    if (mounted) setState(() => _syncing = false);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(sportOverviewProvider(widget.sport));
    final nav = NxPillNav<String>(
      items: [for (final MapEntry(:key, :value) in sportLabels.entries) (key, value)],
      value: widget.sport,
      onChanged: (s) => context.go('/sports/$s'),
    );

    return NxPage(
      onRefresh: () async {
        ref.invalidate(sportOverviewProvider(widget.sport));
        await ref.read(sportOverviewProvider(widget.sport).future);
      },
      children: [
        NxAsync(
          value: async,
          onRetry: () => ref.invalidate(sportOverviewProvider(widget.sport)),
          data: (o) {
            final empty = o.list('leagues').isEmpty && o.list('upcoming').isEmpty && o.list('recent').isEmpty;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _stage(context, o),
                if (!empty) CollectionFields(section: SectionKey.sports, fields: _fields(o)),
                const SizedBox(height: 22),
                nav,
                if (empty)
                  Padding(
                    padding: const EdgeInsets.only(top: 22),
                    child: NxEmptyState(
                      icon: LucideIcons.trophy,
                      title: 'No ${_label.toLowerCase()} yet',
                      body: 'Run a sync to pull competitions, fixtures and results from TheSportsDB.',
                      actionLabel: 'Sync now',
                      onAction: _syncing ? null : _sync,
                    ),
                  )
                else
                  ..._blocks(context, o),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _stage(BuildContext context, Json o) {
    final c = context.nx;
    final upcoming = o.list('upcoming');
    final recent = o.list('recent');
    final (Json? event, String? kind) = upcoming.isNotEmpty
        ? (upcoming.first, 'Next up')
        : (recent.isNotEmpty ? (recent.first, 'Latest') : (null, null));

    final (String title, String? accent) = switch (event) {
      null => (_label, 'on hold'),
      final e when !hasMatchup(e) => (eventName(e), null),
      final e when hasScore(e) => (
        '${teamLabel(e.str('home_team'), widget.sport)} ${e.number('home_score')?.round() ?? 0}–${e.number('away_score')?.round() ?? 0}',
        teamLabel(e.str('away_team'), widget.sport),
      ),
      final e => (teamLabel(e.str('home_team'), widget.sport), 'vs ${teamLabel(e.str('away_team'), widget.sport)}'),
    };

    final lede = event == null
        ? 'Nothing synced for this sport yet. Run a sync to pull fixtures and results from TheSportsDB.'
        : [
            eventWhen(event),
            [?event.str('venue'), ?event.str('country')].join(', '),
          ].where((s) => s.isNotEmpty).join(' · ');

    final thumb = sizedImage(event?.str('thumb_url'), ImageSize.medium);
    final visual = thumb != null
        ? NxImage(url: thumb)
        : ColoredBox(
            color: const Color(0xFFF4F1EC),
            child: Center(
              child: event?.str('league_badge_url') != null
                  ? TeamBadge(url: event!.str('league_badge_url'), label: event.str('league_name'), size: 96)
                  : Icon(LucideIcons.trophy, size: 56, color: c.ink3),
            ),
          );

    return NxStage(
      eyebrow: [_label, ?kind, ?(event?.str('series') ?? event?.str('league_name'))].join(' · '),
      title: title,
      accent: accent,
      lede: lede,
      visual: visual,
      actions: [
        NxButton(
          'Sync',
          icon: LucideIcons.refreshCw,
          variant: NxButtonVariant.secondary,
          loading: _syncing,
          onPressed: _sync,
        ),
      ],
    );
  }

  List<CollectionField> _fields(Json o) {
    final upcoming = o.list('upcoming');
    final recent = o.list('recent');
    final leagues = o.list('leagues');
    final majors = o.list('majors');
    final table = o.list('standings').where((b) => b.list('rows').isNotEmpty).firstOrNull;
    final top = table == null ? null : tableRows(table, limit: 1).firstOrNull;
    return [
      CollectionField(
        key: 'upcoming',
        label: 'Coming up',
        value: '${upcoming.length}',
        sub: upcoming.isEmpty ? 'Nothing scheduled yet' : eventWhen(upcoming.first),
        span: 2,
      ),
      CollectionField(
        key: 'recent',
        label: 'Results',
        value: '${recent.length}',
        sub: recent.isEmpty ? null : 'Latest: ${eventName(recent.first)}',
        variant: FieldVariant.tint,
      ),
      CollectionField(
        key: 'leagues',
        label: 'Competitions',
        value: '${leagues.length}',
        sub: leagues.isEmpty ? 'Awaiting sync' : null,
        variant: FieldVariant.outline,
      ),
      if (table != null && top != null)
        CollectionField(
          key: 'leader',
          label: 'Top of the ${table.str('league') ?? 'table'}',
          title: top.team,
          sub: '${top.points} pts · ${plural(int.tryParse(top.played) ?? 0, 'game')}',
          variant: FieldVariant.tint,
          span: 2,
        )
      else
        CollectionField(
          key: 'majors',
          label: 'Majors',
          value: '${majors.length}',
          sub: majors.isEmpty ? 'None on the calendar' : (majors.first.str('series') ?? eventName(majors.first)),
          variant: FieldVariant.tint,
          span: 2,
        ),
    ];
  }

  List<Widget> _blocks(BuildContext context, Json o) {
    final c = context.nx;
    final upcoming = o.list('upcoming');
    final recent = o.list('recent');
    final majors = o.list('majors');
    final tables = o.list('standings').where((b) => b.list('rows').isNotEmpty).toList();
    final leagues = o.list('leagues');

    List<Widget> rows(List<Json> events) => [
      for (final (i, e) in events.indexed) SportsEventRow(event: e, first: i == 0),
    ];

    return [
      if (upcoming.isNotEmpty) ...[const NxSectionHeader('Coming up'), ...rows(upcoming)],
      const NxSectionHeader('Results'),
      if (recent.isEmpty) Text('No results cached yet.', style: NxText.muted(context)) else ...rows(recent),
      if (majors.isNotEmpty) ...[const NxSectionHeader('Majors & signature events'), ...rows(majors)],
      if (tables.isNotEmpty) ...[
        const NxSectionHeader('Tables'),
        for (final (i, b) in tables.indexed)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 28),
            child: SportsTable(block: b),
          ),
      ],
      if (leagues.isNotEmpty) ...[
        const NxSectionHeader('Competitions we follow'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final l in leagues)
              Container(
                padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
                decoration: BoxDecoration(color: c.tint, borderRadius: BorderRadius.circular(NxRadius.pill)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TeamBadge(url: l.str('badge_url'), label: l.str('name'), size: 22),
                    const SizedBox(width: 8),
                    Text(l.text('name'), style: NxText.sans(size: 13, color: c.ink)),
                  ],
                ),
              ),
          ],
        ),
      ],
    ];
  }
}
