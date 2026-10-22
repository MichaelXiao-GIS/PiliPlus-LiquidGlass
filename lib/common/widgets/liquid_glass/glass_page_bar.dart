import 'package:PiliPlus/common/widgets/liquid_glass/glass_surface.dart';
import 'package:material_ui/material_ui.dart';

/// Keeps existing route actions, search inputs and bottom tabs intact.
class GlassPageBar extends StatelessWidget {
  const GlassPageBar({super.key, required this.child});

  final AppBar child;

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: GlassSurface(
        radius: 28,
        child: MediaQuery.removePadding(
          context: context,
          removeTop: true,
          child: child,
        ),
      ),
    ),
  );
}
