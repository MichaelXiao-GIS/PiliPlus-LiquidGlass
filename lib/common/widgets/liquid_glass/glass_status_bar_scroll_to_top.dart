import 'dart:async';

import 'package:PiliPlus/common/widgets/liquid_glass/glass_platform.dart';
import 'package:flutter/widgets.dart';

/// Connect the native iOS status-bar action to the visible feed in our custom
/// layout. Resolve the position at tap time, after any retained-tab changes.
class GlassStatusBarScrollToTop extends StatefulWidget {
  const GlassStatusBarScrollToTop({
    super.key,
    required this.position,
    required this.child,
  });

  final ScrollPosition? Function() position;
  final Widget child;

  @override
  State<GlassStatusBarScrollToTop> createState() =>
      _GlassStatusBarScrollToTopState();
}

class _GlassStatusBarScrollToTopState extends State<GlassStatusBarScrollToTop>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    if (GlassCapabilities.isIOS) WidgetsBinding.instance.addObserver(this);
  }

  @override
  void handleStatusBarTap() {
    if (!mounted || !GlassCapabilities.isIOS) return;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;

    final route = ModalRoute.of(context);
    // Details, dialogs and interactive returns must not scroll the feed behind
    // them. This does not assume the status bar is at the window's top edge.
    if (route == null ||
        !route.isCurrent ||
        route.willHandlePopInternally ||
        route.navigator?.userGestureInProgress == true ||
        (route.animation != null && !route.animation!.isCompleted) ||
        (route.secondaryAnimation != null &&
            !route.secondaryAnimation!.isDismissed)) {
      return;
    }

    final position = widget.position();
    if (position == null ||
        !position.hasContentDimensions ||
        position.axis != Axis.vertical) {
      return;
    }
    final top = position.minScrollExtent;
    if (position.pixels <= top) return;

    final duration = GlassCapabilities.duration(context, 1000);
    if (duration == Duration.zero) {
      position.jumpTo(top);
    } else {
      // Match Flutter's native scroll-to-top curve; never invoke refresh.
      unawaited(
        position.animateTo(top, duration: duration, curve: Curves.easeOutCirc),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
