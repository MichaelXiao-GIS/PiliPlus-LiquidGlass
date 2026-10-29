import 'dart:math' as math;
import 'dart:ui' show DisplayFeatureType;

import 'package:PiliPlus/common/widgets/liquid_glass/glass_window_geometry.dart';
import 'package:material_ui/material_ui.dart';

/// Content may extend beneath a corner camera; fixed controls avoid its local
/// occlusion separately. Unknown system insets retain the conservative layout.
class VideoDetailViewport extends StatelessWidget {
  const VideoDetailViewport({
    super.key,
    required this.insets,
    required this.origin,
    required this.builder,
  });

  final EdgeInsets insets;
  final Offset origin;
  final Widget Function(BuildContext context, Size size) builder;

  @override
  Widget build(BuildContext context) {
    final data = MediaQuery.of(context);
    final cameras = data.displayFeatures.where(
      (feature) => feature.type == DisplayFeatureType.cutout,
    );
    final contentInsets = insets.copyWith(
      left: cameras.any((camera) => camera.bounds.left < insets.left)
          ? 0
          : insets.left,
      right:
          cameras.any(
            (camera) => camera.bounds.right > data.size.width - insets.right,
          )
          ? 0
          : insets.right,
    );
    return Padding(
      padding: contentInsets,
      child: GlassContentViewport(
        origin: origin + Offset(contentInsets.left, contentInsets.top),
        child: Builder(
          builder: (context) => builder(context, MediaQuery.sizeOf(context)),
        ),
      ),
    );
  }
}

/// Keeps useful space for recommendation titles, rather than subtracting the
/// camera/status region from an already allocated sidebar.
abstract final class VideoPaneWidth {
  static double minimumPanel(double width) => math.min(320, width / 2);

  static double landscape(Size viewport) {
    final width = viewport.width;
    final preferredVideo =
        (viewport.height / width * 1.08).clamp(0.5, 0.7) * width;
    final panel = (width - preferredVideo).clamp(
      minimumPanel(width),
      math.min(425, width / 2),
    );
    return width - panel;
  }

  static double heightFitted(Size viewport, double ratio) => math.min(
    viewport.height * ratio,
    viewport.width - minimumPanel(viewport.width),
  );
}
