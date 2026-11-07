import 'dart:ui' show ImageFilter;

import 'package:material_ui/material_ui.dart';

/// Clip the backdrop directly: a ShaderMask isolates it from Flutter's content
/// on Impeller. The narrow feather bands blend the real backdrop with gradually
/// decreasing blur; the continuous tint gradient hides their tonal boundaries.
class GlassFeatheredBackdrop extends StatelessWidget {
  const GlassFeatheredBackdrop({
    super.key,
    required this.solidExtent,
    required this.blur,
    required this.color,
    required this.opaque,
    this.featherExtent = 32,
    this.sigma = 14,
    this.tintOpacity = 0.62,
  });
  final double solidExtent;
  final double blur;
  final Color color;
  final bool opaque;
  final double featherExtent;
  final double sigma;
  final double tintOpacity;
  static const bands = 16;

  Widget _filter(double opacity) => ClipRect(
    child: BackdropFilter(
      enabled: !opaque && blur > 0,
      filter: ImageFilter.compose(
        outer: ColorFilter.mode(
          Colors.white.withValues(alpha: opacity),
          BlendMode.modulate,
        ),
        inner: ImageFilter.blur(
          sigmaX: sigma * blur * opacity,
          sigmaY: sigma * blur * opacity,
        ),
      ),
      child: const SizedBox.expand(),
    ),
  );

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        height: solidExtent,
        child: _filter(1),
      ),
      if (!opaque && blur > 0)
        for (var i = 0; i < bands; i++)
          Positioned(
            top: solidExtent + i * featherExtent / bands,
            left: 0,
            right: 0,
            height: featherExtent / bands,
            child: _filter(1 - (i + 0.5) / bands),
          ),
      Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withValues(alpha: opaque ? 1 : tintOpacity * blur),
                color.withValues(alpha: opaque ? 1 : tintOpacity * blur),
                color.withValues(alpha: 0),
              ],
              stops: [0, solidExtent / (solidExtent + featherExtent), 1],
            ),
          ),
        ),
      ),
    ],
  );
}
