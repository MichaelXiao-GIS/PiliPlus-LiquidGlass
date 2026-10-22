import 'dart:ui' show ImageFilter;

import 'package:PiliPlus/common/widgets/liquid_glass/glass_platform.dart';
import 'package:material_ui/material_ui.dart';

/// A separate instance belongs to each main destination. Scroll direction does
/// not change the state: only returning near the top expands the navigation.
class GlassScrollController extends ChangeNotifier {
  double _blur = 0;
  bool _compact = false;

  double get blur => _blur;
  bool get compact => _compact;

  void update(double offset) {
    final blur = (offset / 64).clamp(0.0, 1.0);
    final compact = _compact ? offset > 12 : offset >= 64;
    if (blur == _blur && compact == _compact) return;
    _blur = blur;
    _compact = compact;
    notifyListeners();
  }
}

class GlassScrollScope extends InheritedWidget {
  const GlassScrollScope({
    super.key,
    required this.controller,
    required super.child,
  });

  final GlassScrollController controller;

  static GlassScrollController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<GlassScrollScope>()
      ?.controller;

  @override
  bool updateShouldNotify(GlassScrollScope oldWidget) =>
      controller != oldWidget.controller;
}

/// The inset is part of the scroll content, so it scrolls away while the
/// viewport itself continues behind the status bar and the pinned controls.
class GlassScrollInsets extends InheritedWidget {
  const GlassScrollInsets({
    super.key,
    required this.top,
    required super.child,
  });

  final double top;

  static double topOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GlassScrollInsets>()?.top ?? 0;

  @override
  bool updateShouldNotify(GlassScrollInsets oldWidget) => top != oldWidget.top;
}

class GlassScrollSpacer extends StatelessWidget {
  const GlassScrollSpacer({super.key});

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
    child: SizedBox(height: GlassScrollInsets.topOf(context)),
  );
}

/// Each category keeps its own offset, including while it is kept alive.
class GlassScrollBody extends StatefulWidget {
  const GlassScrollBody({
    super.key,
    this.active = true,
    required this.child,
  });

  final bool active;
  final Widget child;

  @override
  State<GlassScrollBody> createState() => _GlassScrollBodyState();
}

class _GlassScrollBodyState extends State<GlassScrollBody> {
  GlassScrollController? _controller;
  double _offset = 0;
  bool _parentActive = true;
  bool get _active => widget.active && _parentActive;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller = GlassScrollScope.maybeOf(context);
    _parentActive =
        context.dependOnInheritedWidgetOfExactType<_ScrollActivity>()?.active ??
        true;
    _restore();
  }

  @override
  void didUpdateWidget(GlassScrollBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _restore();
  }

  void _restore() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _active) _controller?.update(_offset);
    });
  }

  bool _onScroll(ScrollNotification notification) {
    // Ignore carousels, nested comment lists and the enclosing page switcher.
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }
    _updateMetrics(notification.metrics);
    return false;
  }

  void _updateMetrics(ScrollMetrics metrics) {
    final extent = metrics.maxScrollExtent - metrics.minScrollExtent;
    _offset = extent <= 0
        ? 0
        : (metrics.pixels - metrics.minScrollExtent).clamp(0.0, extent);
    if (_active) _controller?.update(_offset);
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: NotificationListener<ScrollMetricsNotification>(
          onNotification: (notification) {
            if (notification.depth == 0 &&
                notification.metrics.axis == Axis.vertical) {
              _updateMetrics(notification.metrics);
            }
            return false;
          },
          child: _ScrollActivity(active: _active, child: widget.child),
        ),
      );
}

class _ScrollActivity extends InheritedWidget {
  const _ScrollActivity({required this.active, required super.child});
  final bool active;
  @override
  bool updateShouldNotify(_ScrollActivity oldWidget) =>
      active != oldWidget.active;
}

/// Full-width scroll-edge material. Unlike a glass control, this has no rounded
/// outline, and it must sample the real content beneath the safe area.
class GlassScrollPage extends StatelessWidget {
  const GlassScrollPage({
    super.key,
    required this.header,
    required this.headerExtent,
    this.contentHeaderExtent,
    required this.body,
  });

  final Widget header;
  final double headerExtent;

  /// Keep the initial content inset stable while the controls move upward.
  final double? contentHeaderExtent;
  final Widget body;

  static bool enabled(BuildContext context) =>
      GlassCapabilities.isIOS &&
      MediaQuery.sizeOf(context).width < 700 &&
      GlassScrollScope.maybeOf(context) != null;

  @override
  Widget build(BuildContext context) {
    final controller = GlassScrollScope.maybeOf(context)!;
    final top = MediaQuery.viewPaddingOf(context).top;
    final extent = top + headerExtent;
    final colors = ColorScheme.of(context);
    final opaque =
        GlassCapabilities.of(context).reduceTransparency ||
        MediaQuery.highContrastOf(context);
    return Stack(
      children: [
        Positioned.fill(
          child: GlassScrollInsets(
            top: top + (contentHeaderExtent ?? headerExtent),
            child: body,
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: extent,
          child: AnimatedBuilder(
            animation: controller,
            child: Padding(
              padding: EdgeInsets.only(top: top),
              child: SizedBox(height: headerExtent, child: header),
            ),
            builder: (context, child) => Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: ClipRect(
                      child: BackdropFilter(
                        enabled: !opaque && controller.blur > 0,
                        filter: ImageFilter.blur(
                          sigmaX: 20 * controller.blur,
                          sigmaY: 20 * controller.blur,
                        ),
                        child: ColoredBox(
                          color: colors.surface.withValues(
                            alpha: opaque ? 1 : 0.78 * controller.blur,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                child!,
              ],
            ),
          ),
        ),
      ],
    );
  }
}
