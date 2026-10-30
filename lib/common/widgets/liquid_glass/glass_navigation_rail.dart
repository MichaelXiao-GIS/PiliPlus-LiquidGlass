import 'dart:math' as math;
import 'dart:ui' show DisplayFeatureType;

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

  static double _leftOf(MediaQueryData data, GlassWindowGeometry window) {
    final left = window.railOnLeft(data);
    final inset = left ? data.viewPadding.left : data.viewPadding.right;
    final status = window.statusBarBounds(data);
    final lane = math.max(inset, gutter);
    // Safe-area width describes content clearance, not the visual center of
    // the system's status/camera column. Both glass groups follow that column.
    bool fitsColumn(double center) =>
        (left ? center <= lane : center >= data.size.width - lane) &&
        center - width / 2 >= 8 &&
        center + width / 2 <= data.size.width - 8;
    if (window.matches(data) &&
        window.verticalBarEdge == (left ? 'left' : 'right')) {
      // Duo can report a full-width 2pt statusBarFrame even with a vertical
      // status column. Its compact camera occlusion is the reliable axis;
      // exclude the tall reserved status region and active fold divisions.
      Rect? camera;
      for (final feature in data.displayFeatures) {
        final rect = feature.bounds;
        if (feature.type == DisplayFeatureType.cutout &&
            !rect.isEmpty &&
            rect.width <= lane &&
            rect.height <= lane &&
            rect.top >= 0 &&
            rect.bottom <= data.size.height &&
            fitsColumn(rect.center.dx) &&
            (camera == null ||
                rect.width * rect.height < camera.width * camera.height)) {
          camera = rect;
        }
      }
      if (camera != null) return camera.center.dx - width / 2;
      // Hosts without a compact camera region may provide a real vertical
      // status frame. Ignore horizontal or out-of-window frames on rotation.
      if (!status.isEmpty &&
          status.width < data.size.width / 2 &&
          fitsColumn(status.center.dx)) {
        return status.center.dx - width / 2;
      }
    }
    return left
        ? (inset >= gutter ? (inset - width) / 2 : inset + 8)
        : data.size.width -
              (inset >= gutter ? (inset + width) / 2 : inset + width + 8);
  }

  static EdgeInsets contentInsetsOf(BuildContext context) {
    final data = MediaQuery.of(context);
    final safe = data.viewPadding;
    final window = GlassCapabilities.of(context).window;
    final left = window.railOnLeft(data);
    final inset = left ? safe.left : safe.right;
    final x = _leftOf(data, window);
    // Reserve the actual rail bounds plus its content-side gap. A status
    // column shifted inward may extend beyond the system's safe-area lane.
    final reserved = math.max(
      inset,
      left ? x + width + 8 : data.size.width - x + 8,
    );
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
    final x = _leftOf(data, window);
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
