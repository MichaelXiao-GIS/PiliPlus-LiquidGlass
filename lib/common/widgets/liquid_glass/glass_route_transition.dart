import 'package:flutter/widgets.dart';

/// Native platform views split Flutter's scene into separate overlay surfaces.
/// Keep glass in Flutter's scene while either route is moving, including a
/// paused/cancelled interactive pop. Restore UIKit only after both routes settle.
class GlassRouteTransition extends StatefulWidget {
  const GlassRouteTransition({super.key, required this.builder});

  final Widget Function(BuildContext context, bool transitioning) builder;

  @override
  State<GlassRouteTransition> createState() => _GlassRouteTransitionState();
}

class _GlassRouteTransitionState extends State<GlassRouteTransition> {
  ModalRoute<dynamic>? _route;
  Listenable? _changes;
  bool _transitioning = false;

  bool get _isTransitioning {
    final route = _route;
    if (route == null) return false;
    bool moving(Animation<double>? animation) =>
        animation != null &&
        (animation.status == AnimationStatus.forward ||
            animation.status == AnimationStatus.reverse ||
            (animation.value > 0 && animation.value < 1));
    return route.navigator?.userGestureInProgress == true ||
        moving(route.animation) ||
        moving(route.secondaryAnimation);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (_route != route) {
      _changes?.removeListener(_update);
      _route = route;
      _changes = Listenable.merge([
        route?.animation,
        route?.secondaryAnimation,
        route?.navigator?.userGestureInProgressNotifier,
      ])..addListener(_update);
    }
    _transitioning = _isTransitioning;
  }

  void _update() {
    final value = _isTransitioning;
    if (value != _transitioning) setState(() => _transitioning = value);
  }

  @override
  void dispose() {
    _changes?.removeListener(_update);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _transitioning);
}
