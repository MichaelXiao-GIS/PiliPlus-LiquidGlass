import 'package:PiliPlus/common/widgets/slotted_layout_helper.dart';
import 'package:flutter/rendering.dart' show ChildLayoutHelper;
import 'package:material_ui/material_ui.dart';

enum MainType { sideBar, bottomNav, body }

class MainLayout
    extends SlottedMultiChildRenderObjectWidget<MainType, RenderBox> {
  const MainLayout({
    super.key,
    required this.sideBar,
    required this.bottomNav,
    required this.body,
    this.floatingSideBar = false,
  });

  final Widget? sideBar;
  final Widget? bottomNav;
  final Widget body;
  final bool floatingSideBar;

  @override
  Iterable<MainType> get slots => MainType.values;

  @override
  Widget? childForSlot(slot) => switch (slot) {
    .sideBar => sideBar,
    .bottomNav => bottomNav,
    .body => body,
  };

  @override
  SlottedContainerRenderObjectMixin<MainType, RenderBox> createRenderObject(
    BuildContext context,
  ) {
    return _RenderMainLayout()..floatingSideBar = floatingSideBar;
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant SlottedContainerRenderObjectMixin<MainType, RenderBox> renderObject,
  ) {
    (renderObject as _RenderMainLayout).floatingSideBar = floatingSideBar;
  }
}

class _RenderMainLayout extends RenderBox
    with
        SlottedContainerRenderObjectMixin<MainType, RenderBox>,
        SlottedLayoutMixin {
  bool _floatingSideBar = false;
  set floatingSideBar(bool value) {
    if (_floatingSideBar == value) return;
    _floatingSideBar = value;
    markNeedsLayout();
  }

  RenderBox? get sideBar => childForSlot(.sideBar);
  RenderBox? get bottomNav => childForSlot(.bottomNav);
  RenderBox get body => childForSlot(.body)!;

  @override
  Iterable<MainType> get slots => MainType.values;

  @override
  void performLayout() {
    final constraints = this.constraints;
    size = constraints.biggest;

    final Offset bodyOffset;
    final BoxConstraints bodyConstraints;

    final sideBar = this.sideBar;
    if (sideBar != null) {
      if (_floatingSideBar) {
        sideBar.layout(BoxConstraints.tight(size));
        setOffset(sideBar, .zero);
        this.body.layout(BoxConstraints.tight(size));
        setOffset(this.body, .zero);
        return;
      }
      final sideBarWidth = ChildLayoutHelper.layoutChild(
        sideBar,
        BoxConstraints.tightFor(height: constraints.maxHeight),
      ).width;
      setOffset(sideBar, .zero);

      bodyOffset = Offset(sideBarWidth, 0);
      bodyConstraints = BoxConstraints.tightFor(
        width: constraints.maxWidth - sideBarWidth,
        height: constraints.maxHeight,
      );
    } else {
      final bottomNav = this.bottomNav;
      if (bottomNav != null) {
        final bottomNavSize = ChildLayoutHelper.layoutChild(
          bottomNav,
          constraints.loosen(),
        );
        setOffset(
          bottomNav,
          Offset(
            (constraints.maxWidth - bottomNavSize.width) / 2,
            constraints.maxHeight - bottomNavSize.height,
          ),
        );
      }

      bodyOffset = .zero;
      bodyConstraints = BoxConstraints.tightFor(
        width: constraints.maxWidth,
        height: constraints.maxHeight,
      );
    }

    final body = this.body..layout(bodyConstraints);
    setOffset(body, bodyOffset);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    void doPaint(RenderBox? child) {
      if (child != null) {
        context.paintChild(child, getOffset(child) + offset);
      }
    }

    if (!_floatingSideBar) doPaint(sideBar);
    doPaint(body);
    if (_floatingSideBar) doPaint(sideBar);
    doPaint(bottomNav);
  }
}
