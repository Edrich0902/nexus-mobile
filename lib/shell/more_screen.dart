import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nexus_mobile/core/router/navigation.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';
import 'package:nexus_mobile/features/home/home_modules.dart';
import 'package:nexus_mobile/features/home/home_refresh.dart';

/// The More tab: every destination outside the tab bar. Sections with a
/// live pulse (shared with Home) get a field; the rest are quick links.
class MoreScreen extends ConsumerWidget {
  const new({super.key});

  /// Leads the bento at full width with a large value.
  static const _lead = 'code';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modules = ref.watch(homeModulesProvider);
    final fields = {for (final f in modules.fields) f.key: f};
    final dests = [...Nav.primary, ...Nav.secondary].where((d) => !Nav.phoneTabs.contains(d)).toList();
    final live = [
      ?fields[_lead],
      for (final d in dests)
        if (d.key != _lead) ?fields[d.key],
    ];
    final links = dests.where((d) => !fields.containsKey(d.key)).toList();
    final loading = modules.loading && live.every((f) => f.value == '0' || f.value == '—');

    return NxPage(
      onRefresh: () async => invalidateHomeSurfaces(ref),
      children: [
        const NxStage(
          eyebrow: 'Everything else',
          title: 'All of',
          accent: 'Nexus',
          lede: 'Your other sections at a glance.',
        ),
        NxSwitcher(
          child: loading
              ? const Padding(
                  key: ValueKey('loading'),
                  padding: EdgeInsets.only(top: 22),
                  child: NxSkeleton(height: 420, radius: NxRadius.xl),
                )
              : NxBento(
                  key: const ValueKey('fields'),
                  children: [
                    for (final (i, f) in live.indexed)
                      NxField(
                        key: ValueKey(f.key),
                        bg: f.section.field.bg,
                        ink: f.section.field.ink,
                        variant: f.tint ? FieldVariant.tint : FieldVariant.solid,
                        label: f.label,
                        aside: f.aside,
                        value: f.value,
                        valueSize: f.key == _lead ? 72 : (i < 3 ? 44 : 32),
                        sub: f.sub,
                        span: f.key == _lead ? 2 : 1,
                        minHeight: f.key == _lead ? 160 : (i < 3 ? 120 : 96),
                        onTap: () => context.go(f.to),
                      ),
                  ],
                ),
        ),
        if (links.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                for (final (i, d) in links.indexed) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(child: _QuickLink(d)),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// Icon-over-label button in the destination's field colour.
class _QuickLink extends StatelessWidget {
  const new(this.dest);

  final Destination dest;

  @override
  Widget build(BuildContext context) {
    final f = dest.section.field;
    return NxPressable(
      onTap: () => context.go(dest.to),
      semanticLabel: dest.label,
      child: Container(
        height: 76,
        decoration: BoxDecoration(color: f.bg, borderRadius: BorderRadius.circular(NxRadius.xl)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(dest.icon, size: 20, color: f.ink),
            const SizedBox(height: 6),
            Text(
              dest.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: NxText.sans(size: 12, weight: FontWeight.w600, color: f.ink),
            ),
          ],
        ),
      ),
    );
  }
}
