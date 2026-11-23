import 'dart:ui' show ImageFilter;

import 'package:material_ui/material_ui.dart';

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

  @override
  Widget build(BuildContext context) {
    final enabled = !opaque && blur > 0;
    final tint = color.withValues(alpha: opaque ? 1 : tintOpacity * blur);
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRect(
          child: BackdropFilter(
            enabled: enabled,
            filter: ImageFilter.blur(
              sigmaX: sigma * blur,
              sigmaY: sigma * blur,
            ),
            child: CustomPaint(
              painter: enabled
                  ? _FeatherMask(solidExtent, featherExtent)
                  : null,
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [tint, tint, color.withValues(alpha: 0)],
              stops: [0, solidExtent / (solidExtent + featherExtent), 1],
            ),
          ),
        ),
      ],
    );
  }
}

class _FeatherMask extends CustomPainter {
  const _FeatherMask(this.solidExtent, this.featherExtent);

  final double solidExtent;
  final double featherExtent;

  static const _gradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFFFFFFF),
      Color(0xD7FFFFFF),
      Color(0x80FFFFFF),
      Color(0x28FFFFFF),
      Color(0x00FFFFFF),
    ],
  );

  @override
  void paint(Canvas canvas, Size size) {
    final feather = Rect.fromLTWH(0, solidExtent, size.width, featherExtent);
    // Paint inside the backdrop's own layer so the mask fades only the blurred
    // copy. The original feed beneath it stays sharp as the mask clears.
    canvas.drawRect(
      feather,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = _gradient.createShader(feather),
    );
  }

  @override
  bool shouldRepaint(_FeatherMask oldDelegate) =>
      solidExtent != oldDelegate.solidExtent ||
      featherExtent != oldDelegate.featherExtent;
}
