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
    final radius = sigma * blur;
    final broadFade = featherExtent * 0.78;
    final fineFadeStart = featherExtent * 0.20;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Soften small strokes before the broad blur fades. Restrict the
        // extra backdrop read to the transition strip below the solid area.
        if (enabled)
          Positioned(
            left: 0,
            right: 0,
            top: solidExtent,
            height: featherExtent,
            child: _MaskedBlur(
              radius: radius * 0.20,
              fadeStart: fineFadeStart,
              fadeExtent: featherExtent - fineFadeStart,
            ),
          ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: solidExtent + broadFade,
          child: _MaskedBlur(
            enabled: enabled,
            radius: radius,
            fadeStart: solidExtent,
            fadeExtent: broadFade,
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

class _MaskedBlur extends StatelessWidget {
  const _MaskedBlur({
    this.enabled = true,
    required this.radius,
    required this.fadeStart,
    required this.fadeExtent,
  });

  final bool enabled;
  final double radius;
  final double fadeStart;
  final double fadeExtent;

  @override
  Widget build(BuildContext context) => ClipRect(
    child: BackdropFilter(
      enabled: enabled,
      filter: ImageFilter.blur(sigmaX: radius, sigmaY: radius),
      child: CustomPaint(
        painter: enabled ? _FeatherMask(fadeStart, fadeExtent) : null,
      ),
    ),
  );
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
