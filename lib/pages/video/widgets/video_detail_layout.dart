import 'dart:math' as math;

import 'package:PiliPlus/common/widgets/liquid_glass/glass_window_geometry.dart';
import 'package:material_ui/material_ui.dart';

/// The player and its panels share the space remaining after safe-area insets.
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
  Widget build(BuildContext context) => Padding(
    padding: insets,
    child: GlassContentViewport(
      origin: origin + Offset(insets.left, insets.top),
      child: Builder(
        builder: (context) => builder(context, MediaQuery.sizeOf(context)),
      ),
    ),
  );
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
