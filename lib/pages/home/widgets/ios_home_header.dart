import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:PiliPlus/common/widgets/liquid_glass/glass_surface.dart';
import 'package:material_ui/material_ui.dart';

enum _HeaderPart { title, actions, search, tabs }

/// A single search control changes bounds; its native glass view, hit target
/// and accessibility element survive the transition between the two rows.
class IosHomeHeader extends StatelessWidget {
  const IosHomeHeader({
    super.key,
    required this.progress,
    required this.hint,
    required this.onSearch,
    required this.actions,
    required this.tabs,
    required this.tabsExtent,
  });

  final double progress;
  final String hint;
  final VoidCallback onSearch;
  final Widget actions;
  final Widget tabs;
  final double tabsExtent;

  static const searchKey = ValueKey('ios-home-search');
  static const titleKey = ValueKey('ios-home-title');
  static const actionsKey = ValueKey('ios-home-actions');
  static const tabsKey = ValueKey('ios-home-tabs');
  static const labelKey = ValueKey('ios-home-search-label');

  // Narrow early while lifting continuously. The eased horizontal finish and
  // gradual lift round off the old right-angle path and keep controls apart.
  static double horizontal(double progress) =>
      Curves.easeOutCubic.transform((progress / 0.60).clamp(0.0, 1.0));
  static double vertical(double progress) => progress * progress * progress;

  static double rowHeight(BuildContext context, double progress) {
    final font = lerpDouble(34, 28, horizontal(progress))!;
    return math.max(48, MediaQuery.textScalerOf(context).scale(font) * 1.2);
  }

  static double extentOf(BuildContext context, double progress, double tabs) =>
      12 + rowHeight(context, progress) + 52 * (1 - vertical(progress)) + tabs;

  @override
  Widget build(BuildContext context) {
    final colors = ColorScheme.of(context);
    final labelBlend = Curves.easeInOut.transform(
      (progress / 0.65).clamp(0.0, 1.0),
    );
    Widget label(String text, double opacity) => Opacity(
      opacity: opacity,
      child: Text(
        text,
        textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 2),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 16,
          height: 1.2,
          color: colors.onSurfaceVariant,
        ),
      ),
    );
    final titleStyle = TextStyle(
      fontSize: lerpDouble(34, 28, horizontal(progress)),
      height: 1.2,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.8,
      color: colors.onSurface,
    );
    final measure = TextPainter(
      text: TextSpan(text: '浏览', style: titleStyle.copyWith(fontSize: 28)),
      textScaler: MediaQuery.textScalerOf(context),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();
    final compactTitleWidth = measure.width;
    measure.dispose();

    return SizedBox(
      height: extentOf(context, progress, tabsExtent),
      child: CustomMultiChildLayout(
        delegate: _HomeHeaderLayout(
          progress: progress,
          rowHeight: rowHeight(context, progress),
          compactTitleWidth: compactTitleWidth,
          tabsExtent: tabsExtent,
        ),
        children: [
          LayoutId(
            id: _HeaderPart.title,
            child: Semantics(
              key: titleKey,
              container: true,
              header: true,
              child: FittedBox(
                alignment: Alignment.centerLeft,
                fit: BoxFit.scaleDown,
                child: Text('浏览', maxLines: 1, style: titleStyle),
              ),
            ),
          ),
          LayoutId(
            id: _HeaderPart.actions,
            child: KeyedSubtree(key: actionsKey, child: actions),
          ),
          LayoutId(
            id: _HeaderPart.search,
            child: Semantics(
              key: searchKey,
              container: true,
              excludeSemantics: true,
              button: true,
              label: '搜索视频、UP主和番剧',
              onTap: onSearch,
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  excludeFromSemantics: true,
                  borderRadius: BorderRadius.circular(28),
                  onTap: onSearch,
                  child: Center(
                    child: SizedBox(
                      height: lerpDouble(44, 40, horizontal(progress)),
                      child: GlassSurface(
                        child: Center(
                          child: Row(
                            children: [
                              SizedBox(
                                width: lerpDouble(16, 12, horizontal(progress)),
                              ),
                              Icon(
                                Icons.search_rounded,
                                size: lerpDouble(22, 20, horizontal(progress)),
                                color: colors.onSurfaceVariant,
                              ),
                              SizedBox(
                                width: lerpDouble(10, 6, horizontal(progress)),
                              ),
                              Expanded(
                                child: Stack(
                                  key: labelKey,
                                  alignment: Alignment.centerLeft,
                                  children: [
                                    label(hint, 1 - labelBlend),
                                    label('搜索', labelBlend),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          LayoutId(
            id: _HeaderPart.tabs,
            child: KeyedSubtree(key: tabsKey, child: tabs),
          ),
        ],
      ),
    );
  }
}

class _HomeHeaderLayout extends MultiChildLayoutDelegate {
  _HomeHeaderLayout({
    required this.progress,
    required this.rowHeight,
    required this.compactTitleWidth,
    required this.tabsExtent,
  });

  final double progress;
  final double rowHeight;
  final double compactTitleWidth;
  final double tabsExtent;

  @override
  void performLayout(Size size) {
    final horizontal = IosHomeHeader.horizontal(progress);
    final vertical = IosHomeHeader.vertical(progress);
    final actions = layoutChild(
      _HeaderPart.actions,
      BoxConstraints.loose(Size(size.width - 34, rowHeight)),
    );
    final actionsLeft = size.width - 14 - actions.width;
    positionChild(
      _HeaderPart.actions,
      Offset(actionsLeft, 8 + (rowHeight - actions.height) / 2),
    );

    // Reserve a readable small search field before allocating the title width.
    final titleMax = math.max(0.0, actionsLeft - 20 - 120 - 16);
    final compactWidth = math.min(compactTitleWidth, titleMax);
    final title = layoutChild(
      _HeaderPart.title,
      BoxConstraints.loose(
        Size(
          lerpDouble(actionsLeft - 20 - 8, compactWidth, horizontal)!,
          rowHeight,
        ),
      ),
    );
    positionChild(
      _HeaderPart.title,
      Offset(20, 8 + (rowHeight - title.height) / 2),
    );

    final left = lerpDouble(14, 20 + compactWidth + 8, horizontal)!;
    final right = lerpDouble(size.width - 14, actionsLeft - 8, horizontal)!;
    final top = lerpDouble(
      12 + rowHeight + 6,
      8 + (rowHeight - 44) / 2,
      vertical,
    )!;
    layoutChild(
      _HeaderPart.search,
      BoxConstraints.tight(Size(right - left, 44)),
    );
    positionChild(_HeaderPart.search, Offset(left, top));

    layoutChild(
      _HeaderPart.tabs,
      BoxConstraints.tight(Size(size.width, tabsExtent)),
    );
    positionChild(_HeaderPart.tabs, Offset(0, size.height - tabsExtent));
  }

  @override
  bool shouldRelayout(_HomeHeaderLayout oldDelegate) =>
      progress != oldDelegate.progress ||
      rowHeight != oldDelegate.rowHeight ||
      compactTitleWidth != oldDelegate.compactTitleWidth ||
      tabsExtent != oldDelegate.tabsExtent;
}
