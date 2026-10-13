import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:nexus_mobile/design/colors.dart';
import 'package:nexus_mobile/design/tokens.g.dart';
import 'package:nexus_mobile/design/typography.dart';
import 'package:nexus_mobile/design/widgets/nx_field.dart' show NxField;
import 'package:nexus_mobile/design/widgets/nx_glass.dart';
import 'package:nexus_mobile/design/widgets/nx_motion.dart';
import 'package:nexus_mobile/design/widgets/widgets.dart' show NxField;

/// Space the shell's floating top bar and phone bar take up, so pages can
/// scroll content underneath the blurred chrome.
class ShellInsets extends InheritedWidget {
  const new({required this.top, required this.bottom, required super.child, super.key});

  final double top;
  final double bottom;

  static ShellInsets? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<ShellInsets>();

  @override
  bool updateShouldNotify(ShellInsets old) => old.top != top || old.bottom != bottom;
}

const pagePad = 20.0;

/// Standard scrolling page: shell-aware padding, optional pull-to-refresh.
/// Sections stagger in when the page opens; ones built later (scrolled to,
/// or arriving with data after the opening beat) just appear.
class NxPage extends StatefulWidget {
  const new({required this.children, this.onRefresh, this.controller, this.padTop = 8, super.key}) : slivers = null;

  const new slivers({required List<Widget> this.slivers, this.onRefresh, this.controller, this.padTop = 8, super.key})
    : children = const [];

  final List<Widget> children;
  final List<Widget>? slivers;
  final Future<void> Function()? onRefresh;
  final ScrollController? controller;
  final double padTop;

  @override
  State<NxPage> createState() => _NxPageState();
}

class _NxPageState extends State<NxPage> {
  static const _openingBeat = Duration(milliseconds: 700);
  final _opened = Stopwatch()..start();

  Widget _section(int index, Widget child) => _KeepAlive(
    key: child.key,
    child: NxRise(index: index, animate: _opened.elapsed < _openingBeat, child: child),
  );

  @override
  Widget build(BuildContext context) {
    final insets = ShellInsets.maybeOf(context);
    final mq = MediaQuery.of(context);
    final top = (insets?.top ?? mq.padding.top) + widget.padTop;
    final bottom = (insets?.bottom ?? mq.padding.bottom) + 32;
    final onRefresh = widget.onRefresh;

    final body =
        widget.slivers ??
        [
          SliverList.list(children: [for (final (i, child) in widget.children.indexed) _section(i, child)]),
        ];

    Widget scroll = CustomScrollView(
      controller: widget.controller,
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(pagePad, top, pagePad, bottom),
          sliver: SliverMainAxisGroup(slivers: body),
        ),
      ],
    );

    if (onRefresh != null) {
      scroll = RefreshIndicator(
        onRefresh: () {
          HapticFeedback.mediumImpact();
          return onRefresh();
        },
        edgeOffset: top - widget.padTop,
        color: context.nx.acc,
        backgroundColor: context.nx.surface2,
        child: scroll,
      );
    }
    return scroll;
  }
}

/// Keeps a page section built once seen, so scrolling back doesn't rebuild
/// it (or replay its entrance).
class _KeepAlive extends StatefulWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class NxSectionHeader extends StatelessWidget {
  const new(this.title, {this.actionLabel, this.onAction, this.top = 30, super.key});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final double top;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Semantics(header: true, child: Text(title.toUpperCase(), style: NxText.label(context))),
          ),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  actionLabel!,
                  style: NxText.sans(size: 13, weight: FontWeight.w500, color: context.nx.acc),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class NxPanel extends StatelessWidget {
  const new({required this.child, this.padding = const EdgeInsets.all(16), this.onTap, super.key});

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    final box = Container(
      padding: padding,
      decoration: ShapeDecoration(
        color: c.tint,
        shape: NxGlassBorder.raised(c, radius: NxRadius.xl),
      ),
      child: child,
    );
    return onTap == null ? box : GestureDetector(onTap: onTap, child: box);
  }
}

/// Two-column bento grid for [NxField]s (`span` 1 or 2), matching the phone
/// layout of web NxBento.
class NxBento extends StatelessWidget {
  const new({required this.children, this.gap = 10, this.top = 22, super.key});

  final List<Widget> children;
  final double gap;
  final double top;

  @override
  Widget build(BuildContext context) {
    final rows = <List<Widget>>[];
    var current = <Widget>[];
    var used = 0;
    for (final child in children) {
      final span = child is BentoItem ? child.span.clamp(1, 2) : 1;
      if (used + span > 2) {
        rows.add(current);
        current = [];
        used = 0;
      }
      current.add(child);
      used += span;
    }
    if (current.isNotEmpty) rows.add(current);
    var tile = 0;

    return Padding(
      padding: EdgeInsets.only(top: top),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) SizedBox(height: gap),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = 0; j < rows[i].length; j++) ...[
                    if (j > 0) SizedBox(width: gap),
                    Expanded(
                      flex: rows[i][j] is BentoItem ? (rows[i][j] as BentoItem).span : 1,
                      child: NxRise(index: tile++, distance: 14, child: rows[i][j]),
                    ),
                  ],
                  if (rows[i].length == 1 && (rows[i][0] is! BentoItem || (rows[i][0] as BentoItem).span == 1)) ...[
                    SizedBox(width: gap),
                    const Expanded(child: SizedBox()),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Widgets that occupy 1 or 2 bento columns.
mixin BentoItem on Widget {
  int get span;
}

/// Label/value tiles (web NxFacts).
class NxFacts extends StatelessWidget {
  const new(this.facts, {this.columns = 3, super.key});

  final List<(String, String?)> facts;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    final visible = facts.where((f) => f.$2 != null && f.$2!.isNotEmpty).toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, box) {
        final w = (box.maxWidth - (columns - 1) * 8) / columns;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (label, value) in visible)
              Container(
                width: w,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(color: c.tint, borderRadius: BorderRadius.circular(NxRadius.sm)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: NxText.sans(size: 11, color: c.ink3)),
                    const SizedBox(height: 2),
                    Text(
                      value!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: NxText.sans(size: 15, weight: FontWeight.w600, color: c.ink),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
