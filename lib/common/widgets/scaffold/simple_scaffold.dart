import 'dart:math' as math;

import 'package:PiliPlus/common/widgets/slotted_layout_helper.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_page_bar.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_platform.dart';
import 'package:flutter/rendering.dart' show ChildLayoutHelper;
import 'package:material_ui/material_ui.dart';

class SimpleScaffold extends StatelessWidget {
  const SimpleScaffold({
    super.key,
    this.backgroundColor,
    this.fab,
    this.appBar,
    this.overlayAppBar = false,
    required this.body,
  });

  final Color? backgroundColor;
  final Widget? fab;
  final Widget? appBar;
  final bool overlayAppBar;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      child: ScaffoldLayout(
        overlayAppBar: overlayAppBar && GlassCapabilities.isIOS,
        fab: fab,
        appBar: GlassCapabilities.isIOS && appBar is AppBar
            ? GlassPageBar(overlay: overlayAppBar, child: appBar as AppBar)
            : appBar,
        body: body,
      ),
    );
  }
}

enum ScaffoldType { fab, appBar, body }

class ScaffoldLayout
    extends SlottedMultiChildRenderObjectWidget<ScaffoldType, RenderBox> {
  const ScaffoldLayout({
    super.key,
    this.fab,
    this.appBar,
    required this.body,
    this.overlayAppBar = false,
  });

  final bool overlayAppBar;
  final Widget? fab;
  final Widget? appBar;
  final Widget body;

  @override
  Iterable<ScaffoldType> get slots => ScaffoldType.values;

  @override
  Widget? childForSlot(slot) => switch (slot) {
    .fab => fab,
    .appBar => appBar,
    .body => body,
  };

  @override
  SlottedContainerRenderObjectMixin<ScaffoldType, RenderBox> createRenderObject(
    BuildContext context,
  ) {
    return _RenderScaffoldLayout()..overlayAppBar = overlayAppBar;
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant SlottedContainerRenderObjectMixin<ScaffoldType, RenderBox>
    renderObject,
  ) {
    (renderObject as _RenderScaffoldLayout).overlayAppBar = overlayAppBar;
  }
}

class _RenderScaffoldLayout extends RenderBox
    with
        SlottedContainerRenderObjectMixin<ScaffoldType, RenderBox>,
        SlottedLayoutMixin {
  bool _overlayAppBar = false;
  set overlayAppBar(bool value) {
    if (_overlayAppBar == value) return;
    _overlayAppBar = value;
    markNeedsLayout();
  }

  RenderBox? get fab => childForSlot(.fab);
  RenderBox? get appBar => childForSlot(.appBar);
  RenderBox get body => childForSlot(.body)!;

  @override
  Iterable<ScaffoldType> get slots => ScaffoldType.values;

  @override
  void performLayout() {
    final constraints = this.constraints;
    size = constraints.biggest;

    final Offset bodyOffset;
    final BoxConstraints bodyConstraints;

    final appBar = this.appBar;
    if (appBar != null) {
      final appBarHeight = ChildLayoutHelper.layoutChild(
        appBar,
        BoxConstraints.tightFor(width: constraints.maxWidth),
      ).height;
      setOffset(appBar, .zero);

      bodyOffset = Offset(0, _overlayAppBar ? 0 : appBarHeight);
      bodyConstraints = BoxConstraints.tightFor(
        width: constraints.maxWidth,
        height: math.max(
          constraints.maxHeight - (_overlayAppBar ? 0 : appBarHeight),
          0.0,
        ),
      );
    } else {
      bodyOffset = .zero;
      bodyConstraints = constraints;
    }

    final body = this.body..layout(bodyConstraints);
    setOffset(body, bodyOffset);

    final fab = this.fab;
    if (fab != null) {
      final fabSize = ChildLayoutHelper.layoutChild(fab, constraints.loosen());
      setOffset(
        fab,
        Offset(
          constraints.maxWidth - fabSize.width,
          constraints.maxHeight - fabSize.height,
        ),
      );
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    void doPaint(RenderBox? child) {
      if (child != null) {
        context.paintChild(child, getOffset(child) + offset);
      }
    }

    doPaint(body);
    doPaint(appBar);
    doPaint(fab);
  }
}
