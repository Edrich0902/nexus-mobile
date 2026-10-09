import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:nexus_mobile/core/api/json.dart';
import 'package:nexus_mobile/core/auth/auth.dart';
import 'package:nexus_mobile/core/format.dart';
import 'package:nexus_mobile/design/ambient.dart';
import 'package:nexus_mobile/design/ambient_palette.dart';
import 'package:nexus_mobile/design/palettes.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';
import 'package:nexus_mobile/features/home/activity.dart';
import 'package:nexus_mobile/features/home/home_modules.dart';
import 'package:nexus_mobile/features/home/hub_api.dart';

final nowProvider = FutureProvider<Json>((ref) async {
  if (ref.watch(authProvider) is! SignedIn) return const {};
  return ref.watch(hubApiProvider).now();
});

const _momentAmbient = <String, Ambient>{
  'music': NxMoments.music,
  'race': NxMoments.race,
  'cellar': NxMoments.cellar,
  'morning': NxMoments.morning,
  'afternoon': NxMoments.afternoon,
  'evening': NxMoments.evening,
  'night': NxMoments.evening,
};

/// Home (web HomeView): "now" stage, serif summary, module fields, the
/// activity stream and what's coming up.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Timer? _nowTimer;
  Timer? _activityTimer;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _nowTimer = Timer.periodic(const Duration(seconds: 30), (_) => ref.invalidate(nowProvider));
    _activityTimer = Timer.periodic(const Duration(minutes: 2), (_) => ref.invalidate(activityProvider));
    _lifecycle = AppLifecycleListener(onResume: () => ref.invalidate(nowProvider));
  }

  @override
  void dispose() {
    _nowTimer?.cancel();
    _activityTimer?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    refreshHomeModules(ref);
    ref
      ..invalidate(activityProvider)
      ..invalidate(nowProvider);
    await ref.read(nowProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(nowProvider);
    final modules = ref.watch(homeModulesProvider);
    final data = now.value;
    final palette = data?.obj('palette');
    final ambient = ambientFromJson(palette) ?? (data == null ? null : _momentAmbient[data.str('moment')]);

    return AmbientOverride(
      ambient: ambient,
      child: NxPage(
        onRefresh: _refresh,
        children: [
          if (data == null && now.isLoading)
            const NxPageSkeleton(rows: 0)
          else if (data == null || data.isEmpty)
            const NxStage(eyebrow: 'Today', title: 'Welcome', accent: 'back')
          else
            _NowStage(now: data),
          if (modules.summary.isNotEmpty) ...[
            const SizedBox(height: 20),
            NxRise(child: NxSerifSummary(modules.summary)),
          ],
          if (modules.loading && modules.fields.every((f) => f.value == '0' || f.value == '—'))
            const Padding(
              padding: EdgeInsets.only(top: 22),
              child: NxSkeleton(height: 260, radius: NxRadius.xl),
            )
          else
            NxBento(
              children: [
                for (final f in modules.fields)
                  NxField(
                    key: ValueKey(f.key),
                    bg: f.section.field.bg,
                    ink: f.section.field.ink,
                    variant: f.tint ? FieldVariant.tint : FieldVariant.solid,
                    label: f.label,
                    aside: f.aside,
                    value: f.value,
                    valueSize: f.valueSize,
                    sub: f.sub,
                    span: f.span,
                    minHeight: f.span == 2 ? 170 : 120,
                    onTap: () => context.go(f.to),
                  ),
              ],
            ),
          const NxSectionHeader('Your stream'),
          const _Stream(),
          const NxSectionHeader('Coming up'),
          if (modules.upcoming.isEmpty)
            Text('Nothing on the calendar.', style: NxText.muted(context))
          else ...[
            const NxStreamGroup('Next'),
            for (final u in modules.upcoming)
              NxStreamItem(
                key: ValueKey(u.key),
                time: shortDay(u.when),
                color: u.section.field.bg,
                kind: u.kind,
                meta: u.meta,
                title: u.title,
                future: true,
                onTap: () => context.go(u.to),
              ),
          ],
        ],
      ),
    );
  }
}

class _NowStage extends StatelessWidget {
  const _NowStage({required this.now});

  final Json now;

  @override
  Widget build(BuildContext context) {
    final image = now.str('image');
    final actions = now.list('actions');
    return NxStage(
      key: ValueKey(now.str('moment')),
      eyebrow: now.str('eyebrow'),
      live: now.flag('live'),
      title: now.str('title'),
      accent: now.str('accent'),
      lede: now.str('lede'),
      progress: now.number('progress'),
      visual: image == null ? null : NxImage(url: image),
      actions: [
        for (final a in actions)
          NxButton(
            a.text('label'),
            variant: a.str('kind') == 'primary' ? NxButtonVariant.primary : NxButtonVariant.secondary,
            onPressed: () {
              final to = a.text('to');
              if (to.startsWith('/')) context.go(to);
            },
          ),
      ],
    );
  }
}

class _Stream extends ConsumerWidget {
  const _Stream();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(activityProvider);
    final c = context.nx;
    return activity.when(
      skipLoadingOnRefresh: true,
      loading: () => Column(
        children: [
          for (var i = 0; i < 4; i++)
            const Padding(padding: EdgeInsets.only(bottom: 10), child: NxSkeleton(height: 64)),
        ],
      ),
      error: (e, _) => NxEmptyState(
        icon: LucideIcons.x,
        title: 'Could not load your stream',
        body: 'Try again in a moment.',
        actionLabel: 'Retry',
        onAction: () => ref.invalidate(activityProvider),
        compact: true,
      ),
      data: (state) {
        if (state.items.isEmpty) {
          return const NxEmptyState(
            icon: LucideIcons.activity,
            title: 'A quiet stream',
            body: 'Tastings, books, recipes, pushes and listening sessions show up here as they happen.',
            compact: true,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (label, events) in groupByDay(state.items)) ...[
              NxStreamGroup(label),
              for (final e in events)
                NxStreamItem(
                  key: ValueKey(e.str('id')),
                  time: streamStamp(e.date('occurred_at') ?? DateTime.now()),
                  color: activityColour(e),
                  kind: activityKind(e),
                  meta: activityVerb(e),
                  title: e.text('title'),
                  body: e.str('body'),
                  chips: activityChips(e),
                  onTap: switch (activityPath(e)) {
                    final String path => () => context.go(path),
                    null => null,
                  },
                ),
            ],
            if (state.cursor != null)
              Padding(
                padding: const EdgeInsets.only(left: 62, top: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: state.loadingMore ? null : () => ref.read(activityProvider.notifier).loadMore(),
                    icon: Icon(LucideIcons.chevronDown, size: 14, color: c.ink2),
                    label: Text('Show earlier', style: NxText.sans(size: 13, color: c.ink2)),
                    style: TextButton.styleFrom(
                      backgroundColor: c.tint,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
