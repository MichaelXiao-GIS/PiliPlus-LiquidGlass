import 'dart:math' as math;

import 'package:PiliPlus/common/widgets/liquid_glass/glass_platform.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_surface.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_tab_scrubber.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_window_geometry.dart';
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
    this.compact = false,
    this.axis = Axis.horizontal,
  }) : assert(destinations.length > 1),
       assert(selectedIndex >= 0 && selectedIndex < destinations.length);

  final List<GlassDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool compact;

  /// A vertical bar fills its parent; its caller owns the safe-area placement.
  final Axis axis;

  @override
  State<GlassNavigationBar> createState() => _GlassNavigationBarState();
}

class _GlassNavigationBarState extends State<GlassNavigationBar>
    with SingleTickerProviderStateMixin {
  MethodChannel? _channel;
  late final _collapse = AnimationController(
    vsync: this,
    value: widget.compact ? 1 : 0,
  )..addListener(_update);
  late final _progress = CurvedAnimation(
    parent: _collapse,
    curve: Curves.easeInOutCubic,
  );

  Map<String, Object?> _arguments(BuildContext context) => {
    'selectedIndex': widget.selectedIndex,
    'axis': widget.axis.name,
    'rtl': Directionality.of(context) == TextDirection.rtl,
    'dark': Theme.of(context).brightness == Brightness.dark,
    'tint': ColorScheme.of(context).primary.toARGB32(),
    'textScale': MediaQuery.textScalerOf(context).scale(12) / 12,
    'compactProgress': widget.axis == Axis.vertical ? 1.0 : _progress.value,
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
    } on MissingPluginException {
      // A route transition can dispose the native view before this update.
    }
  }

  @override
  void didUpdateWidget(covariant GlassNavigationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.compact != oldWidget.compact) _animate();
    _update();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animate();
    _update();
  }

  @override
  void dispose() {
    _progress.dispose();
    _collapse.dispose();
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  void _animate() {
    final duration = GlassCapabilities.duration(context, 280);
    if (duration == Duration.zero) {
      _collapse.value = widget.compact ? 1 : 0;
    } else {
      _collapse.animateTo(widget.compact ? 1 : 0, duration: duration);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _progress,
    builder: (context, _) => _buildBar(context),
  );

  Widget _buildBar(BuildContext context) {
    final capabilities = GlassCapabilities.of(context);
    final textScale = MediaQuery.textScalerOf(context).scale(12) / 12;
    final expanded = 1 - _progress.value;
    final height = 54.0 + expanded * (10 + math.max(0.0, textScale - 1) * 24);
    final width = math.min(
      430.0,
      10 +
          widget.destinations.length *
              (64.0 + expanded * (20 + math.max(0.0, textScale - 1) * 16)),
    );
    // Keep the original native view alive under a pushed route. Replacing it
    // with Flutter's more opaque fallback causes a visible flash on swipe-back.
    final native = capabilities.nativeGlass;
    if (!native && _channel != null) {
      _channel!.setMethodCallHandler(null);
      _channel = null;
    }
    if (widget.axis == Axis.vertical) {
      return _surface(context, native, 60);
    }
    final data = MediaQuery.of(context);
    final left = math.max(data.padding.left, 16.0);
    final right = math.max(data.padding.right, 16.0);
    final band = Rect.fromLTWH(
      left,
      data.size.height - math.max(data.padding.bottom, 8.0) - height,
      data.size.width - left - right,
      height,
    );
    final region = glassControlRegion(data, band, Axis.horizontal);

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Padding(
        padding: EdgeInsets.only(
          left: region.left - band.left,
          right: band.right - region.right,
        ),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: SizedBox(
            width: width,
            height: height,
            child: _surface(context, native, height),
          ),
        ),
      ),
    );
  }

  Widget _surface(BuildContext context, bool native, double height) => native
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
          padding: EdgeInsets.all(widget.axis == Axis.vertical ? 6 : 5),
          child: GlassTabScrubber(
            axis: widget.axis,
            count: widget.destinations.length,
            selectedIndex: widget.selectedIndex,
            onSelected: widget.onSelected,
            itemBuilder: (index, preview, showBackground) =>
                _destination(context, index, preview, showBackground),
          ),
        );

  Widget _destination(
    BuildContext context,
    int index,
    bool selected,
    bool showBackground,
  ) {
    final destination = widget.destinations[index];
    final colors = ColorScheme.of(context);
    final foreground = selected ? colors.primary : colors.onSurface;
    if (widget.axis == Axis.vertical) {
      return Semantics(
        container: true,
        selected: index == widget.selectedIndex,
        label: destination.label,
        value: destination.badge == null
            ? null
            : destination.badge!.isEmpty
            ? '有未读动态'
            : '${destination.badge} 条未读动态',
        button: true,
        onTap: () => widget.onSelected(index),
        excludeSemantics: true,
        child: IconButton(
          tooltip: destination.label,
          onPressed: () => widget.onSelected(index),
          style: IconButton.styleFrom(
            fixedSize: const Size.square(48),
            shape: const CircleBorder(),
            backgroundColor: selected && showBackground
                ? colors.primary.withValues(alpha: 0.14)
                : Colors.transparent,
            foregroundColor: selected
                ? colors.primary
                : colors.onSurfaceVariant,
          ),
          icon: Badge(
            isLabelVisible: destination.badge != null,
            label: destination.badge?.isNotEmpty == true
                ? Text(destination.badge!)
                : null,
            child: selected
                ? destination.selectedIcon ?? destination.icon
                : destination.icon,
          ),
        ),
      );
    }
    return Semantics(
      selected: index == widget.selectedIndex,
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
          duration: showBackground
              ? GlassCapabilities.duration(context)
              : Duration.zero,
          decoration: BoxDecoration(
            color: selected && showBackground
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
                    ClipRect(
                      child: Align(
                        heightFactor: widget.axis == Axis.vertical
                            ? 0
                            : 1 - _progress.value,
                        child: Opacity(
                          opacity: widget.axis == Axis.vertical
                              ? 0
                              : 1 - _progress.value,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: ExcludeSemantics(
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
                          ),
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
