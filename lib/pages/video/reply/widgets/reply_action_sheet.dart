import 'dart:math' as math;
import 'dart:ui' show DisplayFeatureType;

import 'package:material_ui/material_ui.dart';

Future<void> showReplyActionSheet({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  final ios = Theme.of(context).platform == TargetPlatform.iOS;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    // The reply panel already owns its tappable drag handle.
    showDragHandle: false,
    useSafeArea: !ios,
    constraints: ios
        ? const BoxConstraints()
        : BoxConstraints(
            maxWidth: math.min(640, MediaQuery.sizeOf(context).shortestSide),
          ),
    backgroundColor: ios ? Colors.transparent : null,
    elevation: ios ? 0 : null,
    builder: ios
        ? (context) => ReplyActionSheet(child: builder(context))
        : builder,
  );
}

/// A window-centered menu; a side status lane is not a full-height obstacle.
class ReplyActionSheet extends StatelessWidget {
  const ReplyActionSheet({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final data = MediaQuery.of(context);
      final window = MediaQuery.of(Navigator.of(context).context);
      final size = constraints.biggest;
      var sideGap = 12.0;
      // The modal route removes top padding when useSafeArea is false.
      // Recover it for a full-window sheet without overriding fold sub-screens.
      final topSafe = data.size == window.size
          ? window.viewPadding.top
          : data.viewPadding.top;
      var topGap = math.max(12.0, topSafe + 12);
      final bottomGap = math.max(12.0, data.viewPadding.bottom);
      var hasSideOcclusion = false;
      for (final feature in data.displayFeatures) {
        final rect = feature.bounds;
        if (feature.type != DisplayFeatureType.cutout ||
            rect.isEmpty ||
            !rect.overlaps(Offset.zero & size)) {
          continue;
        }
        final atLeft = rect.center.dx < size.width / 4;
        final atRight = rect.center.dx > size.width * 3 / 4;
        if (!atLeft && !atRight) continue;
        hasSideOcclusion = true;
        if (rect.center.dy < size.height / 2) {
          // Short portrait menus sit below the camera/status region. Only
          // limit their height; don't remove an entire side of the window.
          topGap = math.max(topGap, rect.bottom + 12);
        } else {
          // A camera near the bottom can meet the menu. Use equal margins
          // on both sides so avoidance does not shift its visual center.
          sideGap = math.max(
            sideGap,
            (atLeft ? rect.right : size.width - rect.left) + 12,
          );
        }
      }
      if (!hasSideOcclusion) {
        sideGap += math.max(data.padding.left, data.padding.right);
      }
      final theme = Theme.of(context);
      return Padding(
        padding: EdgeInsets.only(bottom: bottomGap),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: math.min(560, math.max(0, size.width - sideGap * 2)),
              maxHeight: math.max(0, size.height - topGap - bottomGap),
            ),
            child: Material(
              key: const ValueKey('reply-action-sheet'),
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(28),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(child: child),
            ),
          ),
        ),
      );
    },
  );
}
