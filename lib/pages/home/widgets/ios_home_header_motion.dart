import 'package:PiliPlus/common/widgets/liquid_glass/glass_platform.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// Retarget the same spring when scrolling reverses, preserving its velocity.
/// A near-critical response settles without bouncing into nearby controls.
class IosHomeHeaderMotion extends StatefulWidget {
  const IosHomeHeaderMotion({
    super.key,
    required this.compact,
    required this.builder,
    this.child,
  });

  final bool compact;
  final ValueWidgetBuilder<double> builder;
  final Widget? child;

  @override
  State<IosHomeHeaderMotion> createState() => _IosHomeHeaderMotionState();
}

class _IosHomeHeaderMotionState extends State<IosHomeHeaderMotion>
    with SingleTickerProviderStateMixin {
  static const _spring = SpringDescription(
    mass: 1,
    stiffness: 360,
    damping: 38,
  );
  late final _motion = AnimationController(
    vsync: this,
    value: widget.compact ? 1 : 0,
  );
  bool _reduceMotion = false;
  double get _target => widget.compact ? 1 : 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion =
        GlassCapabilities.of(context).reduceMotion ||
        MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) _motion.value = _target;
  }

  @override
  void didUpdateWidget(IosHomeHeaderMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.compact == widget.compact) return;
    if (_reduceMotion) {
      _motion.value = _target;
    } else {
      _motion.animateWith(
        SpringSimulation(
          _spring,
          _motion.value,
          _target,
          _motion.velocity,
          snapToEnd: true,
          tolerance: const Tolerance(distance: 0.0005, velocity: 0.005),
        ),
      );
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _motion,
    child: widget.child,
    builder: (context, child) => widget.builder(context, _motion.value, child),
  );
}
