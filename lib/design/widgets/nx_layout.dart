import 'package:flutter/material.dart';
import 'package:nexus_mobile/design/colors.dart';
import 'package:nexus_mobile/design/tokens.g.dart';
import 'package:nexus_mobile/design/typography.dart';
import 'package:nexus_mobile/design/widgets/nx_field.dart' show NxField;
import 'package:nexus_mobile/design/widgets/widgets.dart' show NxField;

/// Space the shell's floating top bar and phone bar take up, so pages can
/// scroll content underneath the blurred chrome.
class ShellInsets extends InheritedWidget {
  const ShellInsets({required this.top, required this.bottom, required super.child, super.key});

  final double top;
  final double bottom;

  static ShellInsets? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<ShellInsets>();

  @override
  bool updateShouldNotify(ShellInsets old) => old.top != top || old.bottom != bottom;
}

const pagePad = 20.0;

/// Standard scrolling page: shell-aware padding, optional pull-to-refresh.
class NxPage extends StatelessWidget {
  const NxPage({required this.children, this.onRefresh, this.controller, this.padTop = 8, super.key}) : slivers = null;

  const NxPage.slivers({
    required List<Widget> this.slivers,
    this.onRefresh,
    this.controller,
    this.padTop = 8,
    super.key,
  }) : children = const [];

  final List<Widget> children;
  final List<Widget>? slivers;
  final Future<void> Function()? onRefresh;
  final ScrollController? controller;
  final double padTop;

  @override
  Widget build(BuildContext context) {
    final insets = ShellInsets.maybeOf(context);
    final mq = MediaQuery.of(context);
    final top = (insets?.top ?? mq.padding.top) + padTop;
    final bottom = (insets?.bottom ?? mq.padding.bottom) + 32;

    final body = slivers ?? [SliverList.list(children: children)];

    Widget scroll = CustomScrollView(
      controller: controller,
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
        onRefresh: onRefresh!,
        edgeOffset: top - padTop,
        color: context.nx.acc,
        backgroundColor: context.nx.surface2,
        child: scroll,
      );
    }
    return scroll;
  }
}

class NxSectionHeader extends StatelessWidget {
  const NxSectionHeader(this.title, {this.actionLabel, this.onAction, this.top = 30, super.key});

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
  const NxPanel({required this.child, this.padding = const EdgeInsets.all(16), this.onTap, super.key});

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.nx;
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(NxRadius.xl),
        border: Border.all(color: c.line),
      ),
      child: child,
    );
    return onTap == null ? box : GestureDetector(onTap: onTap, child: box);
  }
}

/// Two-column bento grid for [NxField]s (`span` 1 or 2), matching the phone
/// layout of web NxBento.
class NxBento extends StatelessWidget {
  const NxBento({required this.children, this.gap = 10, this.top = 22, super.key});

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
                      child: rows[i][j],
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
  const NxFacts(this.facts, {this.columns = 3, super.key});

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

/// Rise-in entrance (web `.nx-rise`).
class NxRise extends StatelessWidget {
  const NxRise({required this.child, this.delay = Duration.zero, super.key});

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: NxMotion.enter + delay,
      curve: Interval(delay.inMilliseconds / (NxMotion.enter + delay).inMilliseconds, 1, curve: NxMotion.ease),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 10 * (1 - t)), child: child),
      ),
      child: child,
    );
  }
}
