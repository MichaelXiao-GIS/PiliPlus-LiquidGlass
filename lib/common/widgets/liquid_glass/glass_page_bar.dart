import 'package:PiliPlus/common/widgets/liquid_glass/glass_feathered_backdrop.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_platform.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_surface.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_window_geometry.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Keeps existing route actions, search inputs and bottom tabs intact.
class GlassPageBar extends StatelessWidget {
  const GlassPageBar({super.key, required this.child, this.overlay = false});

  final AppBar child;
  final bool overlay;

  static double topInset(BuildContext context) {
    if (!GlassCapabilities.isIOS) return 0;
    final data = MediaQuery.of(context);
    final alongside = GlassCapabilities.of(context).window.topToolbarRect(
      data,
      height: kToolbarHeight,
    );
    return data.padding.top + (alongside == null ? kToolbarHeight + 14 : 0);
  }

  @override
  Widget build(BuildContext context) {
    final data = MediaQuery.of(context);
    final theme = Theme.of(context);
    final systemStyle =
        child.systemOverlayStyle ??
        theme.appBarTheme.systemOverlayStyle ??
        (theme.brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark);
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = child.preferredSize.height;
        final alongside = (constraints.maxWidth - data.size.width).abs() < 2
            ? GlassCapabilities.of(context).window
                  .topToolbarRect(data, height: height)
            : null;
        final extent = data.padding.top + (alongside == null ? height + 14 : 0);
        final rect =
            alongside ??
            glassControlRegion(
              data,
              Rect.fromLTRB(
                data.padding.left + 12,
                data.padding.top + 6,
                constraints.maxWidth - data.padding.right - 12,
                data.padding.top + 6 + height,
              ),
              Axis.horizontal,
            );
        final bar = SizedBox(
          height: extent,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              rect.left,
              rect.top,
              constraints.maxWidth - rect.right,
              extent - rect.bottom,
            ),
            child: GlassSurface(
              radius: 28,
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                removeLeft: true,
                removeRight: true,
                child: Theme(
                  data: theme.copyWith(
                    appBarTheme: theme.appBarTheme.copyWith(
                      systemOverlayStyle: systemStyle,
                    ),
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        );
        final systemBar = AnnotatedRegion<SystemUiOverlayStyle>(
          // The capsule can sit beside the status region; cover that region too
          // so iOS still chooses legible status glyphs from this page's theme.
          value: systemStyle,
          child: bar,
        );
        if (!overlay) return systemBar;
        final opaque =
            GlassCapabilities.of(context).reduceTransparency ||
            MediaQuery.highContrastOf(context);
        final color = ColorScheme.of(context).surface;
        if (opaque) return ColoredBox(color: color, child: systemBar);
        // Fade through the toolbar and slightly past it. Painting the feather
        // outside the bar preserves the content inset and the controls' hit area.
        final solidExtent = data.padding.top.clamp(0.0, extent * 0.55);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: -28,
              child: IgnorePointer(
                child: GlassFeatheredBackdrop(
                  solidExtent: solidExtent,
                  featherExtent: extent + 28 - solidExtent,
                  blur: 1,
                  sigma: 18,
                  tintOpacity: 0.18,
                  color: color,
                  opaque: false,
                ),
              ),
            ),
            systemBar,
          ],
        );
      },
    );
  }
}

/// Keeps a nested body's fixed controls below the overlay only as they reach it.
/// Padding the body unconditionally would leave a second toolbar-sized gap
/// between the dynamic content and its comment tabs before the header collapses.
class GlassNestedScrollBody extends StatefulWidget {
  const GlassNestedScrollBody({super.key, required this.child});
  final Widget child;

  @override
  State<GlassNestedScrollBody> createState() => _GlassNestedScrollBodyState();
}

class _GlassNestedScrollBodyState extends State<GlassNestedScrollBody> {
  ScrollController? _outer;
  bool _updateQueued = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final outer = context
        .findAncestorStateOfType<NestedScrollViewState>()!
        .outerController;
    if (_outer != outer) {
      _outer?.removeListener(_queueUpdate);
      _outer = outer..addListener(_queueUpdate);
    }
  }

  void _queueUpdate() {
    if (_updateQueued) return;
    _updateQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateQueued = false;
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    _outer?.removeListener(_queueUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inset = GlassPageBar.topInset(context);
    final position = _outer!.hasClients ? _outer!.position : null;
    final remaining = position?.hasContentDimensions == true
        ? position!.maxScrollExtent - position.pixels
        : inset;
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (_) {
        _queueUpdate();
        return false;
      },
      child: Padding(
        padding: EdgeInsets.only(top: (inset - remaining).clamp(0, inset)),
        child: widget.child,
      ),
    );
  }
}
