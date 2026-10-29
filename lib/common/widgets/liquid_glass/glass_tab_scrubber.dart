import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:PiliPlus/common/widgets/liquid_glass/glass_platform.dart';
import 'package:material_ui/material_ui.dart';

/// Flutter counterpart of the native glass lens, used on older hosts. Selection is committed only after the finger is released.
class GlassTabScrubber extends StatefulWidget {
  const GlassTabScrubber({
    super.key,
    required this.count,
    required this.selectedIndex,
    required this.onSelected,
    required this.itemBuilder,
    this.axis = Axis.horizontal,
  });

  final Axis axis;
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
    if (widget.axis != oldWidget.axis ||
        widget.count != oldWidget.count ||
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

  bool get _vertical => widget.axis == Axis.vertical;
  double get _extent => _vertical ? _size.height : _size.width;
  double _main(Offset point) => _vertical ? point.dy : point.dx;

  int _nearest(double position) {
    final slot = (position / (_extent / widget.count)).floor().clamp(
      0,
      widget.count - 1,
    );
    return _rtl ? widget.count - slot - 1 : slot;
  }

  Rect _slot(int index) {
    final offset =
        (_rtl ? widget.count - index - 1 : index) * _extent / widget.count;
    return _vertical
        ? Rect.fromLTWH(0, offset, _size.width, _extent / widget.count)
        : Rect.fromLTWH(offset, 0, _extent / widget.count, _size.height);
  }

  void _follow(Offset point, double delta) {
    final cross = _vertical ? point.dx : point.dy;
    final crossExtent = _vertical ? _size.width : _size.height;
    _inside = cross >= -36 && cross <= crossExtent + 36;
    final index = _inside ? _nearest(_main(point)) : widget.selectedIndex;
    final slot = _slot(index);
    final stretch =
        GlassCapabilities.duration(context) == Duration.zero || !_inside
        ? 0.0
        : math.min(18.0, delta.abs() * 0.6);
    final length = math.min(_extent, _extent / widget.count + stretch);
    final center = _inside
        ? _main(point).clamp(length / 2, _extent - length / 2)
        : _main(slot.center);
    setState(() {
      _preview = index;
      _lens = Rect.fromCenter(
        center: _vertical
            ? Offset(_size.width / 2, center)
            : Offset(center, _size.height / 2),
        width: _vertical ? _size.width : length,
        height: _vertical ? length : _size.height,
      );
    });
  }

  void _start(DragStartDetails details) {
    _reset();
    _follow(details.localPosition, 0);
  }

  void _drag(DragUpdateDetails details) {
    if (_lens != null) _follow(details.localPosition, _main(details.delta));
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
      final rtl = !_vertical && Directionality.of(context) == TextDirection.rtl;
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
          onHorizontalDragStart: _vertical ? (_) {} : _start,
          onHorizontalDragUpdate: _vertical ? null : _drag,
          onHorizontalDragEnd: _vertical ? null : (_) => _finish(),
          onHorizontalDragCancel: _vertical
              ? null
              : () => _finish(cancelled: true),
          onVerticalDragStart: _vertical ? _start : (_) {},
          onVerticalDragUpdate: _vertical ? _drag : null,
          onVerticalDragEnd: _vertical ? (_) => _finish() : null,
          onVerticalDragCancel: _vertical
              ? () => _finish(cancelled: true)
              : null,
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
                        borderRadius: BorderRadius.circular(
                          math.min(_size.width, _size.height) / 2,
                        ),
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
                                math.min(_size.width, _size.height) / 2,
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
                Flex(
                  direction: widget.axis,
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
