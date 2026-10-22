import 'package:PiliPlus/common/style.dart';
import 'package:material_ui/material_ui.dart';

/// Keep the search field at its full size while clipping the part that scrolls
/// above the header. This also clips its embedded UIKit glass view.
class CollapsingSearchBar extends StatelessWidget {
  const CollapsingSearchBar({
    super.key,
    required this.fraction,
    required this.child,
  });

  final double fraction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final visible = fraction.clamp(0.0, 1.0);
    return Offstage(
      offstage: visible == 0,
      child: IgnorePointer(
        ignoring: visible < 1,
        child: ExcludeSemantics(
          excluding: visible < 1,
          child: ClipRect(
            child: Align(
              alignment: Alignment.bottomCenter,
              heightFactor: visible,
              child: SizedBox(height: Style.topBarHeight, child: child),
            ),
          ),
        ),
      ),
    );
  }
}
