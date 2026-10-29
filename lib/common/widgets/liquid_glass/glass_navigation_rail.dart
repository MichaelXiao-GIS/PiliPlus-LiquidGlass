import 'dart:math' as math;

import 'package:PiliPlus/common/widgets/liquid_glass/glass_navigation_bar.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_platform.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_surface.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_window_geometry.dart';
import 'package:material_ui/material_ui.dart';

/// Two content-sized control groups in the system's physical bar edge.
/// The surrounding space stays transparent and does not intercept the feed.
class GlassNavigationRail extends StatelessWidget {
  const GlassNavigationRail({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    required this.actions,
    required this.compactLeading,
  });

  static const width = 60.0;
  static const gutter = width + 16;
  final List<GlassDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<Widget> actions;
  final Widget compactLeading;
  static const _inset = 6.0;
  static const _buttonSize = 48.0;

  static EdgeInsets contentInsetsOf(BuildContext context) {
    final data = MediaQuery.of(context);
    final safe = data.viewPadding;
    final left = GlassCapabilities.of(context).window.railOnLeft(data);
    final inset = left ? safe.left : safe.right;
    // A wide system lane already contains the rail. A narrow notch safe area
    // pushes the rail inward, so reserve both that inset and the control lane.
    final reserved = inset >= gutter ? inset : inset + gutter;
    // Reserve the bar's horizontal lane, but let scrolling content paint
    // through the bottom safe area. Controls still use the full safe insets.
    return left
        ? safe.copyWith(left: reserved, bottom: 0)
        : safe.copyWith(right: reserved, bottom: 0);
  }

  @override
  Widget build(BuildContext context) {
    final data = MediaQuery.of(context);
    final safe = data.viewPadding;
    final window = GlassCapabilities.of(context).window;
    final colors = ColorScheme.of(context);
    final left = window.railOnLeft(data);
    final inset = left ? safe.left : safe.right;
    // Share the system edge gutter instead of reserving a second column.
    final x = left
        ? (inset >= gutter ? (inset - width) / 2 : inset + 8)
        : data.size.width -
              (inset >= gutter ? (inset + width) / 2 : inset + width + 8);
    var band = Rect.fromLTRB(
      x,
      safe.top + 12,
      x + width,
      math.max(safe.top + 12, data.size.height - safe.bottom - 12),
    );
    final status = window.statusBarBounds(data);
    if (status.overlaps(band)) {
      band = Rect.fromLTRB(
        band.left,
        math.max(band.top, status.bottom + 12),
        band.right,
        band.bottom,
      );
    }
    final region = glassControlRegion(data, band, Axis.vertical);
    final navHeight = destinations.length * _buttonSize + _inset * 2;
    final leadingHeight = actions.length * _buttonSize + _inset * 2;
    final expanded = region.height >= navHeight + leadingHeight + 20;
    final toolbarHeight = expanded ? leadingHeight : width;
    final available = math.max(0.0, region.height - toolbarHeight - 12);
    final height = math.min(navHeight, available);
    Widget surface(Widget child) => GlassSurface(
      radius: width / 2,
      child: MediaQuery.removePadding(
        context: context,
        removeLeft: true,
        removeRight: true,
        removeTop: true,
        removeBottom: true,
        // GlassSurface's stack loosens its foreground constraints. Fill the
        // capsule before centering controls, rather than centering in their
        // intrinsic (44/48pt) width at the capsule's leading edge.
        child: SizedBox.expand(child: child),
      ),
    );
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: region.left,
          top: region.top,
          width: width,
          height: toolbarHeight,
          child: surface(
            Padding(
              padding: const EdgeInsets.all(_inset),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final action in expanded ? actions : [compactLeading])
                    SizedBox(
                      width: _buttonSize,
                      height: _buttonSize,
                      child: Center(child: action),
                    ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: region.left,
          top: region.bottom - height,
          width: width,
          height: height,
          child: height >= navHeight
              ? GlassNavigationBar(
                  axis: Axis.vertical,
                  compact: true,
                  destinations: destinations,
                  selectedIndex: selectedIndex,
                  onSelected: onSelected,
                )
              : surface(
                  SingleChildScrollView(
                    primary: false,
                    padding: const EdgeInsets.all(_inset),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < destinations.length; i++)
                          Semantics(
                            container: true,
                            selected: i == selectedIndex,
                            label: destinations[i].label,
                            value: destinations[i].badge == null
                                ? null
                                : destinations[i].badge!.isEmpty
                                ? '有未读动态'
                                : '${destinations[i].badge} 条未读动态',
                            button: true,
                            onTap: () => onSelected(i),
                            excludeSemantics: true,
                            child: IconButton(
                              tooltip: destinations[i].label,
                              onPressed: () => onSelected(i),
                              style: IconButton.styleFrom(
                                fixedSize: const Size.square(_buttonSize),
                                shape: const CircleBorder(),
                                backgroundColor: i == selectedIndex
                                    ? colors.primary.withValues(alpha: 0.14)
                                    : Colors.transparent,
                                foregroundColor: i == selectedIndex
                                    ? colors.primary
                                    : colors.onSurfaceVariant,
                              ),
                              icon: Badge(
                                isLabelVisible: destinations[i].badge != null,
                                label: destinations[i].badge?.isNotEmpty == true
                                    ? Text(destinations[i].badge!)
                                    : null,
                                child: i == selectedIndex
                                    ? destinations[i].selectedIcon ??
                                          destinations[i].icon
                                    : destinations[i].icon,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
