import 'package:PiliPlus/common/widgets/view_safe_area.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_platform.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_surface.dart';
import 'package:material_ui/material_ui.dart';

class AppBarAni extends StatelessWidget {
  const AppBarAni({
    super.key,
    required this.child,
    required this.controller,
    required this.isTop,
    required this.isFullScreen,
    required this.removeSafeArea,
  });

  final Widget child;
  final AnimationController controller;
  final bool isTop;
  final bool isFullScreen;
  final bool removeSafeArea;

  static final _topPos = Tween<Offset>(
    begin: const Offset(0.0, -1.0),
    end: Offset.zero,
  );

  static const _topDecoration = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: <Color>[
      Colors.transparent,
      Color(0xBF000000),
    ],
    tileMode: TileMode.mirror,
  );

  static final _bottomPos = Tween<Offset>(
    begin: const Offset(0, 1.2),
    end: Offset.zero,
  );

  static const _bottomDecoration = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[
      Colors.transparent,
      Color(0xBF000000),
    ],
    tileMode: TileMode.mirror,
  );

  @override
  Widget build(BuildContext context) {
    if (GlassCapabilities.isIOS && isFullScreen) {
      final theme = Theme.of(context);
      final controls = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Theme(
          data: theme.copyWith(
            colorScheme: theme.colorScheme.copyWith(
              brightness: Brightness.dark,
              surface: const Color(0xFF1C1C1E),
              onSurface: Colors.white,
            ),
          ),
          child: GlassSurface(
            child: removeSafeArea
                ? child
                : ViewSafeArea(left: true, right: true, child: child),
          ),
        ),
      );
      if (GlassCapabilities.duration(context) == Duration.zero) {
        return FadeTransition(opacity: controller, child: controls);
      }
      return SlideTransition(
        position: controller.drive(isTop ? _topPos : _bottomPos),
        child: controls,
      );
    }
    return SlideTransition(
      position: controller.drive(isTop ? _topPos : _bottomPos),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: isTop ? _topDecoration : _bottomDecoration,
        ),
        child: removeSafeArea
            ? child
            : ViewSafeArea(
                left: isFullScreen,
                right: isFullScreen,
                child: child,
              ),
      ),
    );
  }
}
