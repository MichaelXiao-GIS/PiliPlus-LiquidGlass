import 'package:PiliPlus/common/widgets/liquid_glass/glass_platform.dart';
import 'package:PiliPlus/plugin/pl_player/utils/fullscreen.dart';
import 'package:flutter/widgets.dart';

/// Duo's side status panel overlaps edge-to-edge video. Hide its software
/// content while this playback route is current; other routes and horizontal
/// status bars retain their existing behavior. Hardware cutouts remain intact.
class VideoStatusBarScope extends StatefulWidget {
  const VideoStatusBarScope({super.key, required this.child, this.active});

  final Widget child;
  // The app's PageRoute observer excludes menus and sheets. A transient popup
  // above the player must not expose the status panel over the playing video.
  final bool? active;

  @override
  State<VideoStatusBarScope> createState() => _VideoStatusBarScopeState();
}

class _VideoStatusBarScopeState extends State<VideoStatusBarScope>
    with WidgetsBindingObserver {
  final _owner = Object();
  bool _sideStatusBar = false;
  bool _current = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _synchronize();
  }

  @override
  void didUpdateWidget(covariant VideoStatusBarScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active) _synchronize();
  }

  void _synchronize() {
    final window = GlassCapabilities.of(context).window;
    if (!GlassCapabilities.isIOS) {
      _sideStatusBar = false;
    } else if (window.matches(MediaQuery.of(context))) {
      _sideStatusBar =
          window.verticalBarEdge == 'left' || window.verticalBarEdge == 'right';
    }
    // Keep the last known preference during a fold's transient stale metrics.
    _current = widget.active ?? ModalRoute.isCurrentOf(context) ?? true;
    systemBarVisibility.suppressStatusBar(_owner, _current && _sideStatusBar);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _current && _sideStatusBar) {
      systemBarVisibility.reapply();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    systemBarVisibility.suppressStatusBar(_owner, false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
