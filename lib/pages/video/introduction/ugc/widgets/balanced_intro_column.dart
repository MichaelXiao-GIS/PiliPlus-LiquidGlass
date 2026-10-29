import 'dart:math' as math;

import 'package:PiliPlus/common/widgets/translucent_column.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Shares spare height above/below the action row without shrinking content.
/// A long title, expanded description or large text naturally removes the gap.
class BalancedIntroColumn extends TranslucentColumn {
  const BalancedIntroColumn({
    super.key,
    required this.availableHeight,
    super.children,
  }) : super(crossAxisAlignment: CrossAxisAlignment.start);

  final double availableHeight;

  @override
  RenderTranslucentColumn createRenderObject(BuildContext context) =>
      _RenderBalancedIntro(availableHeight, Directionality.of(context));

  @override
  void updateRenderObject(
    BuildContext context,
    RenderTranslucentColumn renderObject,
  ) {
    super.updateRenderObject(context, renderObject);
    (renderObject as _RenderBalancedIntro).availableHeight = availableHeight;
  }
}

class IntroActionGap extends LeafRenderObjectWidget {
  const IntroActionGap({super.key});
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderActionGap();
}

class _RenderActionGap extends RenderConstrainedBox {
  _RenderActionGap()
    : super(additionalConstraints: const BoxConstraints.tightFor(height: 8));
}

class _RenderBalancedIntro extends RenderTranslucentColumn {
  _RenderBalancedIntro(this._availableHeight, TextDirection direction)
    : super(
        direction: Axis.vertical,
        crossAxisAlignment: CrossAxisAlignment.start,
        textDirection: direction,
      );

  double _availableHeight;
  set availableHeight(double value) {
    if (_availableHeight == value) return;
    _availableHeight = value;
    markNeedsLayout();
  }

  double extraGap(double naturalHeight) => math.min(
    math.max(0.0, constraints.maxHeight - naturalHeight),
    ((_availableHeight - naturalHeight) / 2).clamp(0.0, 48.0).toDouble(),
  );

  @override
  void performLayout() {
    super.performLayout();
    final gap = extraGap(size.height);
    if (gap == 0) return;
    var afterGap = false;
    RenderBox? child = firstChild;
    while (child != null) {
      final data = child.parentData! as FlexParentData;
      if (afterGap) data.offset += Offset(0, gap);
      if (child is _RenderActionGap) afterGap = true;
      child = data.nextSibling;
    }
    if (afterGap) {
      size = constraints.constrain(Size(size.width, size.height + gap));
    }
  }
}
