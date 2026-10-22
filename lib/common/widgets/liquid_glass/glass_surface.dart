import 'dart:ui' as ui;

import 'package:PiliPlus/common/widgets/liquid_glass/glass_platform.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Reserved for navigation and controls. Content cards stay opaque.
/// iOS 26+ uses UIGlassEffect; other hosts use a legible blur fallback.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = 28,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final capabilities = GlassCapabilities.of(context);
    final colors = ColorScheme.of(context);
    final dark = colors.brightness == Brightness.dark;
    final opaque =
        capabilities.reduceTransparency || MediaQuery.highContrastOf(context);
    final shape = BorderRadius.circular(radius);

    if (capabilities.nativeGlass && !opaque) {
      // UIKit owns the glass outline and shadow. A Flutter rounded mask around
      // UIVisualEffectView clips its refraction and creates a second, fuzzy rim.
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ExcludeSemantics(
              child: IgnorePointer(
                child: _NativeGlassSurface(radius: radius, dark: dark),
              ),
            ),
          ),
          ClipRRect(
            borderRadius: shape,
            child: Padding(padding: padding, child: child),
          ),
        ],
      );
    }

    final surface = BackdropFilter(
      enabled: !opaque,
      filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface.withValues(
            alpha: opaque ? 1 : (dark ? 0.82 : 0.8),
          ),
          borderRadius: shape,
          border: Border.all(
            color: opaque
                ? colors.outline
                : Colors.white.withValues(alpha: dark ? 0.14 : 0.7),
            width: opaque ? 1 : 0.5,
          ),
        ),
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.16 : 0.06),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: Stack(
          children: [
            Positioned.fill(
              child: ExcludeSemantics(
                child: IgnorePointer(child: surface),
              ),
            ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}

class _NativeGlassSurface extends StatefulWidget {
  const _NativeGlassSurface({required this.radius, required this.dark});

  final double radius;
  final bool dark;

  @override
  State<_NativeGlassSurface> createState() => _NativeGlassSurfaceState();
}

class _NativeGlassSurfaceState extends State<_NativeGlassSurface> {
  MethodChannel? _channel;

  Map<String, Object> get _arguments => {
    'radius': widget.radius,
    'dark': widget.dark,
  };

  @override
  void didUpdateWidget(covariant _NativeGlassSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    _update();
  }

  Future<void> _update() async {
    try {
      await _channel?.invokeMethod<void>('update', _arguments);
    } on PlatformException {
      // The platform view can disappear while a route transition is running.
    }
  }

  @override
  Widget build(BuildContext context) => UiKitView(
    viewType: 'piliplus/glass_surface',
    creationParams: _arguments,
    creationParamsCodec: const StandardMessageCodec(),
    onPlatformViewCreated: (id) {
      _channel = MethodChannel('piliplus/glass_surface/$id');
      _update();
    },
  );
}
