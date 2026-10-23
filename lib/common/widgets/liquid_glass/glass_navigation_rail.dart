import 'package:PiliPlus/common/widgets/liquid_glass/glass_navigation_bar.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_surface.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_window_geometry.dart';
import 'package:material_ui/material_ui.dart';

/// A compact phone landscape rail. Safe-area padding stays outside the glass.
class GlassNavigationRail extends StatelessWidget {
  const GlassNavigationRail({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
    required this.leading,
  });

  static const width = 72.0;
  final List<GlassDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Widget leading;

  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.viewPaddingOf(context);
    final colors = ColorScheme.of(context);
    final data = MediaQuery.of(context);
    final region = glassControlRegion(
      data,
      Rect.fromLTWH(
        safe.left + 8,
        safe.top + 8,
        width,
        data.size.height - safe.vertical - 16,
      ),
      Axis.vertical,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        safe.left + 8,
        region.top,
        8,
        data.size.height - region.bottom,
      ),
      child: SizedBox(
        width: width,
        child: GlassSurface(
          child: MediaQuery.removePadding(
            context: context,
            removeLeft: true,
            removeRight: true,
            removeTop: true,
            removeBottom: true,
            child: SizedBox(
              width: width,
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          leading,
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            spacing: 4,
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
                                      minimumSize: const Size(52, 48),
                                      backgroundColor: i == selectedIndex
                                          ? colors.primary.withValues(
                                              alpha: 0.14,
                                            )
                                          : Colors.transparent,
                                      foregroundColor: i == selectedIndex
                                          ? colors.primary
                                          : colors.onSurfaceVariant,
                                    ),
                                    icon: Badge(
                                      isLabelVisible:
                                          destinations[i].badge != null,
                                      label:
                                          destinations[i].badge?.isNotEmpty ==
                                              true
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
    );
  }
}
