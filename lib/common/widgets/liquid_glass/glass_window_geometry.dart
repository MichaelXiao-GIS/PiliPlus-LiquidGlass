import 'dart:math' as math;
import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/widgets.dart';

Rect _scaleRect(Rect rect, double factor) => Rect.fromLTWH(
  rect.left * factor,
  rect.top * factor,
  rect.width * factor,
  rect.height * factor,
);

/// Scene-local metrics. No device names or assumed inner/outer screen sizes.
@immutable
class GlassWindowGeometry {
  const GlassWindowGeometry({
    this.size = Size.zero,
    this.scale = 1,
    this.horizontalSizeClass = 0,
    this.verticalSizeClass = 0,
    this.safeArea = EdgeInsets.zero,
    this.features = const [],
    this.verticalBarEdge,
    this.statusBarFrame = Rect.zero,
  });

  factory GlassWindowGeometry.fromMap(Map<dynamic, dynamic> map) {
    double number(dynamic value) =>
        value is num && value.isFinite ? value.toDouble() : 0;
    final safe = map['safeArea'] as Map? ?? const {};
    final status = map['statusBarFrame'] as Map? ?? const {};
    return GlassWindowGeometry(
      size: Size(number(map['width']), number(map['height'])),
      scale: number(map['scale']),
      horizontalSizeClass: (map['horizontalSizeClass'] as num?)?.toInt() ?? 0,
      verticalSizeClass: (map['verticalSizeClass'] as num?)?.toInt() ?? 0,
      verticalBarEdge: map['verticalBarEdge'] as String?,
      statusBarFrame: Rect.fromLTWH(
        number(status['x']),
        number(status['y']),
        number(status['width']),
        number(status['height']),
      ),
      safeArea: EdgeInsets.fromLTRB(
        number(safe['left']),
        number(safe['top']),
        number(safe['right']),
        number(safe['bottom']),
      ),
      features: [
        for (final region in map['regions'] as List? ?? const [])
          if (region is Map &&
              number(region['width']) > 0 &&
              number(region['height']) > 0)
            DisplayFeature(
              bounds: Rect.fromLTWH(
                number(region['x']),
                number(region['y']),
                number(region['width']),
                number(region['height']),
              ),
              type: region['kind'] == 'division'
                  ? DisplayFeatureType.hinge
                  : DisplayFeatureType.cutout,
              state: region['kind'] == 'division'
                  ? DisplayFeatureState.postureHalfOpened
                  : DisplayFeatureState.unknown,
            ),
      ],
    );
  }

  final Size size;
  final double scale;
  final int horizontalSizeClass;
  final int verticalSizeClass;
  final EdgeInsets safeArea;
  final List<DisplayFeature> features;

  /// Physical edge, resolved by UIKit so RTL never moves the hardware bar.
  final String? verticalBarEdge;
  final Rect statusBarFrame;

  Rect statusBarBounds(MediaQueryData data) =>
      matches(data) ? _scaleRect(statusBarFrame, _factor(data)) : Rect.zero;

  /// Open Duo portrait exposes a corner status region instead of a full-width
  /// top bar. Reuse its empty lane only with matching, explicit system regions.
  Rect? topToolbarRect(MediaQueryData data, {required double height}) {
    if (!matches(data) ||
        verticalBarEdge != 'none' ||
        horizontalSizeClass != 2 ||
        data.size.width < 600 ||
        data.size.height <= data.size.width ||
        data.padding.top < height + 16) {
      return null;
    }
    final band = Rect.fromLTWH(
      math.max(24, data.padding.left + 12),
      (data.padding.top - height) / 2,
      data.size.width -
          math.max(24, data.padding.left + 12) -
          math.max(24, data.padding.right + 12),
      height,
    );
    final blockers = <Rect>[
      for (final feature in data.displayFeatures)
        if (feature.type == DisplayFeatureType.cutout &&
            feature.bounds.overlaps(band))
          feature.bounds,
      if (statusBarBounds(data) case final status
          when status.height > 8 && status.width < data.size.width / 2)
        status,
    ];
    // Ordinary phones, iPads and incomplete transition metrics keep SafeArea.
    if (!blockers.any(
      (r) =>
          r.top < data.padding.top &&
          (r.left <= 2 || r.right >= data.size.width - 2),
    )) {
      return null;
    }
    final protected = data.copyWith(
      displayFeatures: [
        ...data.displayFeatures,
        for (final r in blockers)
          DisplayFeature(
            bounds: r.inflate(12),
            type: DisplayFeatureType.cutout,
            state: DisplayFeatureState.unknown,
          ),
      ],
    );
    final rect = glassControlRegion(protected, band, Axis.horizontal);
    final minimum = math.max(300, data.textScaler.scale(20) * 12);
    if (rect.width < minimum ||
        protected.displayFeatures.any((f) => f.bounds.overlaps(rect))) {
      return null;
    }
    return rect;
  }

  /// Right inset for a bottom control below a corner-mounted status area.
  double bottomControlRightInset(MediaQueryData data, {required double top}) {
    final inset = data.viewPadding.right;
    if (inset <= 12 || verticalBarEdge != 'right' || !matches(data)) {
      return inset;
    }
    final size = data.size;
    final lane = Rect.fromLTWH(size.width - inset, 0, inset, size.height);
    final hasCornerCutout = data.displayFeatures.any(
      (f) =>
          f.type == DisplayFeatureType.cutout &&
          f.bounds.overlaps(lane) &&
          f.bounds.top <= 1 &&
          f.bounds.right >= size.width - 1 &&
          f.bounds.bottom <= top,
    );
    final bottomLane = Rect.fromLTRB(lane.left, top, lane.right, lane.bottom);
    if (!hasCornerCutout ||
        statusBarBounds(data).overlaps(bottomLane) ||
        data.displayFeatures.any((f) => f.bounds.overlaps(bottomLane))) {
      return inset;
    }
    return 12;
  }

  bool railOnLeft(MediaQueryData data) =>
      matches(data) && verticalBarEdge == 'left';

  double _factor(MediaQueryData data) => scale / data.devicePixelRatio;

  // Reject stale traits during a display/window change, until UIKit catches up.
  bool matches(MediaQueryData data) =>
      size.width > 0 &&
      size.height > 0 &&
      (size.width * _factor(data) - data.size.width).abs() < 2 &&
      (size.height * _factor(data) - data.size.height).abs() < 2;

  bool bottomNavigation(MediaQueryData data) {
    if (matches(data) && verticalBarEdge != null) {
      if (verticalBarEdge != 'none') return false;
      // An open Duo in portrait returns to horizontal bars, even with a
      // regular horizontal size class. The outer display reports an edge.
      return data.size.height >= data.size.width && data.size.height >= 500;
    }
    if (matches(data) && horizontalSizeClass != 0 && verticalSizeClass != 0) {
      return horizontalSizeClass == 1 && verticalSizeClass == 2;
    }
    return data.size.width - data.viewPadding.horizontal < 700 &&
        data.size.height >= 500;
  }

  MediaQueryData apply(MediaQueryData data) {
    if (!matches(data)) return data;
    final factor = _factor(data);
    final safe = safeArea * factor;
    final viewPadding = EdgeInsets.fromLTRB(
      math.max(data.viewPadding.left, safe.left),
      math.max(data.viewPadding.top, safe.top),
      math.max(data.viewPadding.right, safe.right),
      math.max(data.viewPadding.bottom, safe.bottom),
    );
    return data.copyWith(
      viewPadding: viewPadding,
      padding: EdgeInsets.fromLTRB(
        math.max(0, viewPadding.left - data.viewInsets.left),
        math.max(0, viewPadding.top - data.viewInsets.top),
        math.max(0, viewPadding.right - data.viewInsets.right),
        math.max(0, viewPadding.bottom - data.viewInsets.bottom),
      ),
      displayFeatures: [
        ...data.displayFeatures,
        for (final feature in features)
          if (!data.displayFeatures.any(
            (existing) => existing.bounds == _scaleRect(feature.bounds, factor),
          ))
            DisplayFeature(
              bounds: _scaleRect(feature.bounds, factor),
              type: feature.type,
              state: feature.state,
            ),
      ],
    );
  }
}

/// Keeps a toolbar or rail on one side of an active fold, while the scrolling
/// content remains continuous. Ties favor the trailing/bottom region.
Rect glassControlRegion(MediaQueryData data, Rect band, Axis axis) {
  var parts = <Rect>[band];
  for (final feature in data.displayFeatures) {
    final block = feature.bounds;
    if (!block.overlaps(band)) continue;
    parts = [
      for (final part in parts)
        if (!block.overlaps(part))
          part
        else ...[
          if (axis == Axis.horizontal && block.left > part.left)
            Rect.fromLTRB(
              part.left,
              part.top,
              math.min(block.left, part.right),
              part.bottom,
            ),
          if (axis == Axis.horizontal && block.right < part.right)
            Rect.fromLTRB(
              math.max(block.right, part.left),
              part.top,
              part.right,
              part.bottom,
            ),
          if (axis == Axis.vertical && block.top > part.top)
            Rect.fromLTRB(
              part.left,
              part.top,
              part.right,
              math.min(block.top, part.bottom),
            ),
          if (axis == Axis.vertical && block.bottom < part.bottom)
            Rect.fromLTRB(
              part.left,
              math.max(block.bottom, part.top),
              part.right,
              part.bottom,
            ),
        ],
    ];
  }
  if (parts.isEmpty) return band;
  return parts.reduce(
    (a, b) => a.width * a.height > b.width * b.height ? a : b,
  );
}

/// A fixed toolbar can share its original height without spanning the fold.
class GlassControlBand extends StatelessWidget {
  const GlassControlBand({
    super.key,
    required this.height,
    required this.child,
    this.origin = Offset.zero,
  });
  final double height;
  final Widget child;
  final Offset origin;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final data = MediaQuery.of(context);
      final local = data.copyWith(
        displayFeatures: [
          for (final feature in data.displayFeatures)
            DisplayFeature(
              bounds: feature.bounds.shift(-origin),
              type: feature.type,
              state: feature.state,
            ),
        ],
      );
      final rect = glassControlRegion(
        local,
        Rect.fromLTWH(0, 0, constraints.maxWidth, height),
        Axis.horizontal,
      );
      return Padding(
        padding: EdgeInsets.only(
          left: rect.left,
          right: constraints.maxWidth - rect.right,
        ),
        child: child,
      );
    },
  );
}

/// Project system regions into a padded content viewport, including safe areas.
class GlassContentViewport extends StatelessWidget {
  const GlassContentViewport({
    super.key,
    required this.origin,
    required this.child,
  });
  final Offset origin;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final data = MediaQuery.of(context);
      final viewport = origin & constraints.biggest;
      // A display switch can deliver the new layout constraints one frame
      // before MediaQuery's scene metrics. Keep the viewport inside the source
      // bounds without turning that size difference into extra safe padding.
      final source = data.copyWith(
        size: Size(
          math.max(data.size.width, viewport.right),
          math.max(data.size.height, viewport.bottom),
        ),
      );
      return MediaQuery(
        data: source
            .removeDisplayFeatures(viewport)
            .copyWith(
              size: viewport.size,
              displayFeatures: [
                for (final feature in data.displayFeatures)
                  if (viewport.overlaps(feature.bounds))
                    DisplayFeature(
                      bounds: viewport.intersect(feature.bounds).shift(-origin),
                      type: feature.type,
                      state: feature.state,
                    ),
              ],
            ),
        child: child,
      );
    },
  );
}
