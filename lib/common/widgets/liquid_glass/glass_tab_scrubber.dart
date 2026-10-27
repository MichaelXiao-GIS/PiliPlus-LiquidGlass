import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:PiliPlus/common/widgets/liquid_glass/glass_platform.dart';
import 'package:material_ui/material_ui.dart';

/// Flutter counterpart of the native glass lens, used on older hosts and while
/// routes are moving. Selection is committed only after the finger is released.
class GlassTabScrubber extends StatefulWidget {
  const GlassTabScrubber({
    super.key,
    required this.count,
    required this.selectedIndex,
    required this.onSelected,
    required this.itemBuilder,
  });

  final int count;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Widget Function(int index, bool previewSelected, bool showBackground)
  itemBuilder;

  @override
  State<GlassTabScrubber> createState() => _GlassTabScrubberState();
}

class _GlassTabScrubberState extends State<GlassTabScrubber>
    with SingleTickerProviderStateMixin {
  late final _settle = AnimationController(vsync: this);
  Rect? _lens;
  RectTween? _snap;
  int? _preview;
  int _generation = 0;
  Size _size = Size.zero;
  bool _rtl = false;
  bool _inside = true;

  @override
  void didUpdateWidget(covariant GlassTabScrubber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.count != oldWidget.count ||
        widget.selectedIndex != oldWidget.selectedIndex) {
      _reset();
    }
  }

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  void _reset() {
    _generation++;
    _settle.stop();
    _lens = null;
    _snap = null;
    _preview = null;
  }

  int _nearest(double x) {
    final slot = (x / (_size.width / widget.count)).floor().clamp(
      0,
      widget.count - 1,
    );
    return _rtl ? widget.count - slot - 1 : slot;
  }

  Rect _slot(int index) => Rect.fromLTWH(
    (_rtl ? widget.count - index - 1 : index) * _size.width / widget.count,
    0,
    _size.width / widget.count,
    _size.height,
  );

  void _follow(Offset point, double delta) {
    _inside = point.dy >= -36 && point.dy <= _size.height + 36;
    final index = _inside ? _nearest(point.dx) : widget.selectedIndex;
    final slot = _slot(index);
    final stretch =
        GlassCapabilities.duration(context) == Duration.zero || !_inside
        ? 0.0
        : math.min(18.0, delta.abs() * 0.6);
    final width = math.min(_size.width, slot.width + stretch);
    final center = _inside
        ? point.dx.clamp(width / 2, _size.width - width / 2)
        : slot.center.dx;
    setState(() {
      _preview = index;
      _lens = Rect.fromCenter(
        center: Offset(center, _size.height / 2),
        width: width,
        height: _size.height,
      );
    });
  }

  Future<void> _finish({bool cancelled = false}) async {
    if (_lens == null) return;
    final index = !cancelled && _inside ? _preview! : widget.selectedIndex;
    final generation = ++_generation;
    setState(() {
      _preview = index;
      _snap = RectTween(begin: _lens, end: _slot(index));
    });
    _settle.duration = GlassCapabilities.duration(context, 320);
    try {
      await _settle.forward(from: 0).orCancel;
    } on TickerCanceled {
      return;
    }
    if (!mounted || generation != _generation) return;
    setState(_reset);
    if (index != widget.selectedIndex) widget.onSelected(index);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      final rtl = Directionality.of(context) == TextDirection.rtl;
      if (_size != size || _rtl != rtl) {
        _reset();
        _size = size;
        _rtl = rtl;
      }
      final colors = ColorScheme.of(context);
      final opaque =
          GlassCapabilities.of(context).reduceTransparency ||
          MediaQuery.highContrastOf(context);
      return Listener(
        // Once a drag wins its arena Flutter can report a cancelled pointer as
        // drag-end. Cancel the pending selection before that completion runs.
        onPointerCancel: (_) => setState(_reset),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onHorizontalDragStart: (details) {
            _reset();
            _follow(details.localPosition, 0);
          },
          onHorizontalDragUpdate: (details) {
            if (_lens != null) _follow(details.localPosition, details.delta.dx);
          },
          onHorizontalDragEnd: (_) => _finish(),
          onHorizontalDragCancel: () => _finish(cancelled: true),
          onVerticalDragStart: (_) {},
          child: AnimatedBuilder(
            animation: _settle,
            builder: (context, _) => Stack(
              fit: StackFit.expand,
              children: [
                if (_lens != null)
                  Positioned.fromRect(
                    rect:
                        _snap?.transform(
                          Curves.easeOutCubic.transform(_settle.value),
                        ) ??
                        _lens!,
                    child: ExcludeSemantics(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(_size.height / 2),
                        child: BackdropFilter(
                          enabled: !opaque,
                          filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: DecoratedBox(
                            key: const ValueKey('glass-tab-lens'),
                            decoration: BoxDecoration(
                              color: opaque
                                  ? colors.surfaceContainerHighest
                                  : null,
                              gradient: opaque
                                  ? null
                                  : LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        colors.onSurface.withValues(
                                          alpha: 0.12,
                                        ),
                                        colors.surface.withValues(alpha: 0.14),
                                        colors.onSurface.withValues(
                                          alpha: 0.09,
                                        ),
                                      ],
                                    ),
                              borderRadius: BorderRadius.circular(
                                _size.height / 2,
                              ),
                              border: Border.all(
                                color: opaque
                                    ? colors.onSurface
                                    : Colors.white.withValues(alpha: 0.7),
                                width: opaque ? 2 : 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                Row(
                  children: [
                    for (var i = 0; i < widget.count; i++)
                      Expanded(
                        child: widget.itemBuilder(
                          i,
                          i == (_preview ?? widget.selectedIndex),
                          _preview == null,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
