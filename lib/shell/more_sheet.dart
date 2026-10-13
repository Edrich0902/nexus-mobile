import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nexus_mobile/core/router/navigation.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart';

/// "More" (web dock drawer): every non-tab destination as a tile in its own
/// field colour, two to a row.
Future<void> showMoreSheet(BuildContext context, String location) {
  final dests = [...Nav.primary, ...Nav.secondary].where((d) => !Nav.phoneTabs.contains(d)).toList();
  return showNxSheet<void>(
    context,
    builder: (sheet) => SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text('Everything in Nexus', style: NxText.label(sheet)),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.9,
            children: [
              for (final (i, d) in dests.indexed)
                NxRise(
                  index: i,
                  distance: 16,
                  child: _Tile(
                    dest: d,
                    active: Nav.isActive(d, location),
                    onTap: () {
                      Navigator.of(sheet).pop();
                      context.go(d.to);
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _Tile extends StatelessWidget {
  const new({required this.dest, required this.active, required this.onTap});

  final Destination dest;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final f = dest.section.field;
    return Semantics(
      button: true,
      selected: active,
      label: dest.label,
      excludeSemantics: true,
      child: NxPressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: f.bg,
            borderRadius: BorderRadius.circular(18),
            border: active ? Border.all(color: f.ink.withValues(alpha: .5), width: 2) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(dest.icon, size: 20, color: f.ink),
              Text(
                dest.label,
                style: NxText.sans(size: 14.5, weight: FontWeight.w700, color: f.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
