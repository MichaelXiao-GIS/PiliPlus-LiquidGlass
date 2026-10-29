import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Tabs retain their natural label widths. On a narrow panel the actions get
/// their own row, leaving the full panel width available to scroll the tabs.
class VideoDetailTabs extends StatelessWidget {
  const VideoDetailTabs({
    super.key,
    required this.controller,
    required this.labels,
    required this.actions,
    required this.onTap,
    this.showIndicator = true,
  });

  final TabController controller;
  final List<String> labels;
  final Widget actions;
  final ValueChanged<int> onTap;
  final bool showIndicator;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final style = (TabBarTheme.of(context).labelStyle ?? const TextStyle())
        .copyWith(fontSize: 13);
    double measure(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textScaler: scaler,
        textDirection: Directionality.of(context),
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    final tabsWidth = labels.fold<double>(
      0,
      (width, label) => width + measure(label, style) + 28,
    );
    final actionsWidth =
        math.max(
          64.0,
          measure('发弹幕', const TextStyle(fontSize: 12)) + 20,
        ) +
        44 +
        12;
    final tabHeight = math.max(45.0, scaler.scale(13) * 1.4 + 16);
    final actionHeight = math.max(44.0, scaler.scale(12) * 1.4 + 8);
    final tabBar = SizedBox(
      height: tabHeight,
      child: TabBar(
        key: ObjectKey(controller),
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        padding: EdgeInsets.zero,
        labelPadding: const EdgeInsets.symmetric(horizontal: 14),
        dividerHeight: 0,
        dividerColor: Colors.transparent,
        indicator: showIndicator ? null : const BoxDecoration(),
        labelColor: showIndicator ? null : theme.colorScheme.onSurface,
        labelStyle: style,
        onTap: onTap,
        tabs: [
          for (final label in labels)
            Tab(
              height: tabHeight,
              child: Text(label, maxLines: 1, softWrap: false),
            ),
        ],
      ),
    );
    final actionBar = SizedBox(
      width: actionsWidth,
      height: actionHeight,
      child: actions,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (labels.isEmpty) {
            return Align(alignment: Alignment.centerRight, child: actionBar);
          }
          if (constraints.maxWidth < tabsWidth + actionsWidth) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                tabBar,
                Align(alignment: Alignment.centerRight, child: actionBar),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: tabBar),
              actionBar,
            ],
          );
        },
      ),
    );
  }
}
