import 'package:flutter/material.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';
import 'package:nexus_mobile/features/sports/sports.dart';

/// Club / competition crest with an initials fallback (web NexusTeamBadge).
class TeamBadge extends StatelessWidget {
  const new({required this.url, required this.label, this.size = 26, super.key});

  final String? url;
  final String? label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    final src = sizedImage(url, size > 48 ? ImageSize.small : ImageSize.tiny);
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: src == null
            ? DecoratedBox(
                decoration: BoxDecoration(color: c.tint2, shape: BoxShape.circle),
                child: Center(
                  child: Text(
                    initials(label),
                    style: NxText.sans(size: size * .36, weight: FontWeight.w700, color: c.ink2),
                  ),
                ),
              )
            : NxImage(url: src, fit: BoxFit.contain, background: Colors.transparent),
      ),
    );
  }
}

/// A fixture or result: when · home score away · competition (web SportsEventRow).
class SportsEventRow extends StatelessWidget {
  const new({required this.event, this.first = false, super.key});

  final Json event;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    final e = event;
    final sport = e.text('sport_slug');
    final scored = hasScore(e);
    final lines = scored ? const <String>[] : resultLines(e.str('result_text'), max: 4);
    final (h, a) = (e.number('home_score'), e.number('away_score'));
    final winner = h == null || a == null || h == a ? null : (h > a ? 'home' : 'away');
    final where = [?e.str('venue'), ?e.str('country')].join(', ');

    TextStyle side(String which) => NxText.sans(
      weight: winner == which ? FontWeight.w700 : FontWeight.w500,
      color: winner != null && winner != which ? c.ink3 : c.ink,
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: first ? null : Border(top: BorderSide(color: c.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(eventWhen(e), style: NxText.mono(size: 12, color: c.ink3)),
              const SizedBox(width: 10),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: e.flag('is_major')
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: c.acc.withValues(alpha: .16),
                            borderRadius: BorderRadius.circular(NxRadius.pill),
                          ),
                          child: Text(
                            e.str('series') ?? 'Major',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: NxText.sans(size: 11.5, weight: FontWeight.w600, color: c.acc),
                          ),
                        )
                      : Text(
                          e.text('league_name'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: NxText.sans(size: 12, color: c.ink3),
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (hasMatchup(e))
            Row(
              children: [
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          teamLabel(e.str('home_team'), sport),
                          maxLines: 2,
                          textAlign: TextAlign.right,
                          overflow: TextOverflow.ellipsis,
                          style: side('home'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TeamBadge(url: e.str('home_badge_url'), label: e.str('home_team')),
                    ],
                  ),
                ),
                SizedBox(
                  width: 64,
                  child: Text(
                    scored ? '${h?.round() ?? '–'}–${a?.round() ?? '–'}' : 'vs',
                    textAlign: TextAlign.center,
                    style: scored ? NxText.display(size: 20, color: c.ink) : NxText.sans(size: 13, color: c.ink3),
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      TeamBadge(url: e.str('away_badge_url'), label: e.str('away_team')),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          teamLabel(e.str('away_team'), sport),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: side('away'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                TeamBadge(url: e.str('league_badge_url'), label: e.str('league_name') ?? e.str('name')),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        eventName(e),
                        style: NxText.sans(weight: FontWeight.w600, color: c.ink),
                      ),
                      if (where.isNotEmpty) Text(where, style: NxText.sans(size: 12.5, color: c.ink3)),
                    ],
                  ),
                ),
              ],
            ),
          if (lines.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(lines.join(' · '), style: NxText.sans(size: 13, color: c.ink2, height: 1.45)),
            ),
        ],
      ),
    );
  }
}

const _formTone = {'W': NexusColors.ok, 'L': NexusColors.bad};

/// A league table as hairline rows with recent form (web SportsTable).
class SportsTable extends StatelessWidget {
  const new({required this.block, super.key});

  final Json block;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    final rows = tableRows(block);
    Widget n(String v, {bool strong = false}) => SizedBox(
      width: 32,
      child: Text(
        v,
        textAlign: TextAlign.right,
        style: NxText.sans(
          size: 13,
          weight: strong ? FontWeight.w700 : FontWeight.w400,
          color: strong ? c.ink : c.ink2,
        ),
      ),
    );

    return Semantics(
      label: '${block.str('league') ?? 'League'} table',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  block.text('league', 'League'),
                  style: NxText.sans(size: 16, weight: FontWeight.w600, color: c.ink),
                ),
              ),
              if (block.str('season') case final season?) Text(season, style: NxText.mono(color: c.ink3)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(width: 26, child: Text('#', style: NxText.label(context))),
              Expanded(child: Text('Club', style: NxText.label(context))),
              SizedBox(width: 62, child: Text('Form', style: NxText.label(context))),
              for (final h in const ['P', 'GD', 'Pts'])
                SizedBox(
                  width: 32,
                  child: Text(h, textAlign: TextAlign.right, style: NxText.label(context)),
                ),
            ],
          ),
          for (final r in rows)
            Tooltip(
              message: r.note,
              triggerMode: r.note.isEmpty ? TooltipTriggerMode.manual : TooltipTriggerMode.longPress,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: c.line)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 26,
                      child: Text('${r.rank}', style: NxText.mono(color: c.ink3)),
                    ),
                    TeamBadge(url: r.badge, label: r.team, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        r.team,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: NxText.sans(size: 13.5, weight: FontWeight.w500, color: c.ink),
                      ),
                    ),
                    SizedBox(
                      width: 62,
                      child: Row(
                        children: [
                          for (final f in r.form)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 3),
                              decoration: BoxDecoration(
                                color: f == 'D' ? c.ink3 : (_formTone[f] ?? c.ink4),
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                    n(r.played),
                    n(r.gd),
                    n(r.points, strong: true),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
