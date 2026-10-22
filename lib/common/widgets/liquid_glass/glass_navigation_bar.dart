import 'dart:math' as math;

import 'package:PiliPlus/common/widgets/liquid_glass/glass_platform.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_surface.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

@immutable
class GlassDestination {
  const GlassDestination({
    required this.label,
    required this.symbol,
    required this.icon,
    this.selectedIcon,
    this.badge,
  });

  final String label;
  final String symbol;
  final Widget icon;
  final Widget? selectedIcon;

  /// null hides the badge, an empty string represents an unread dot.
  final String? badge;
}

class GlassNavigationBar extends StatefulWidget {
  const GlassNavigationBar({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  }) : assert(destinations.length > 1),
       assert(selectedIndex >= 0 && selectedIndex < destinations.length);

  final List<GlassDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  State<GlassNavigationBar> createState() => _GlassNavigationBarState();
}

class _GlassNavigationBarState extends State<GlassNavigationBar> {
  MethodChannel? _channel;

  Map<String, Object?> _arguments(BuildContext context) => {
    'selectedIndex': widget.selectedIndex,
    'dark': Theme.of(context).brightness == Brightness.dark,
    'tint': ColorScheme.of(context).primary.toARGB32(),
    'textScale': MediaQuery.textScalerOf(context).scale(12) / 12,
    'destinations': [
      for (final destination in widget.destinations)
        {
          'label': destination.label,
          'symbol': destination.symbol,
          'badge': destination.badge,
        },
    ],
  };

  Future<void> _update() async {
    try {
      await _channel?.invokeMethod<void>('update', _arguments(context));
    } on PlatformException {
      // Route disposal may race with a theme or badge update.
    }
  }

  @override
  void didUpdateWidget(covariant GlassNavigationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _update();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _update();
  }

  @override
  void dispose() {
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final capabilities = GlassCapabilities.of(context);
    final textScale = MediaQuery.textScalerOf(context).scale(12) / 12;
    final height = 64.0 + math.max(0.0, textScale - 1) * 24;
    final native = capabilities.nativeGlass;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: SizedBox(
          height: height,
          child: native
              ? UiKitView(
                  viewType: 'piliplus/glass_navigation',
                  creationParams: _arguments(context),
                  creationParamsCodec: const StandardMessageCodec(),
                  onPlatformViewCreated: (id) {
                    if (!mounted) return;
                    _channel = MethodChannel('piliplus/glass_navigation/$id');
                    _channel!.setMethodCallHandler((call) async {
                      if (call.method == 'select' && mounted) {
                        final index = call.arguments as int;
                        if (index >= 0 && index < widget.destinations.length) {
                          widget.onSelected(index);
                        }
                      }
                    });
                    _update();
                  },
                )
              : GlassSurface(
                  radius: height / 2,
                  padding: const EdgeInsets.all(5),
                  child: Row(
                    children: [
                      for (var i = 0; i < widget.destinations.length; i++)
                        Expanded(child: _destination(context, i)),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _destination(BuildContext context, int index) {
    final destination = widget.destinations[index];
    final selected = index == widget.selectedIndex;
    final colors = ColorScheme.of(context);
    final foreground = selected ? colors.primary : colors.onSurface;
    return Semantics(
      selected: selected,
      button: true,
      label: destination.label,
      onTap: () => widget.onSelected(index),
      value: destination.badge == null
          ? null
          : destination.badge!.isEmpty
          ? '有未读动态'
          : '${destination.badge} 条未读动态',
      child: Tooltip(
        message: destination.label,
        excludeFromSemantics: true,
        child: AnimatedContainer(
          duration: GlassCapabilities.duration(context),
          decoration: BoxDecoration(
            color: selected
                ? colors.onSurface.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(32),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              excludeFromSemantics: true,
              borderRadius: BorderRadius.circular(32),
              onTap: () => widget.onSelected(index),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ExcludeSemantics(
                      child: Badge(
                        isLabelVisible: destination.badge != null,
                        label: destination.badge?.isNotEmpty == true
                            ? Text(destination.badge!)
                            : null,
                        child: IconTheme(
                          data: IconThemeData(size: 23, color: foreground),
                          child: selected
                              ? destination.selectedIcon ?? destination.icon
                              : destination.icon,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    ExcludeSemantics(
                      child: Text(
                        destination.label,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                          color: foreground,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
