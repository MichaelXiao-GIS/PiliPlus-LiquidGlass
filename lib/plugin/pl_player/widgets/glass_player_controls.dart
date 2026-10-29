import 'dart:math' as math;
import 'dart:ui' show DisplayFeatureType;

import 'package:PiliPlus/common/widgets/liquid_glass/glass_platform.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_surface.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_window_geometry.dart';
import 'package:material_ui/material_ui.dart';

/// The safe area belongs outside the glass, never inside its button padding.
/// Each control band also avoids the actual camera/fold regions it crosses.
Rect playerControlBand(MediaQueryData data, Size size, bool top) {
  final safe = data.viewPadding;
  final safeTop = math.min(size.height, safe.top + 12);
  final safeBottom = math.max(safeTop, size.height - safe.bottom - 12);
  // A horizontal hinge splits the usable height; choose a single panel before
  // placing the toolbar. Vertical hinges/camera islands split its width below.
  final region = glassControlRegion(
    data.copyWith(
      displayFeatures: [
        for (final feature in data.displayFeatures)
          if (feature.bounds.width > feature.bounds.height &&
              feature.bounds.width >= size.width - safe.horizontal - 32)
            feature,
      ],
    ),
    Rect.fromLTRB(16, safeTop, math.max(16, size.width - 16), safeBottom),
    Axis.vertical,
  );
  final upper = region.top;
  final lower = region.bottom;
  final height = math.min(lower - upper, top ? 64.0 : 180.0);
  final bandTop = top ? upper : lower - height;
  final bandBottom = top ? upper + height : lower;
  double edgeInset(double inset, bool left) {
    final cameras = data.displayFeatures.where(
      (feature) =>
          feature.type == DisplayFeatureType.cutout &&
          (left
              ? feature.bounds.left < inset
              : feature.bounds.right > size.width - inset),
    );
    // UIKit's rectangular safe area can reserve the entire right edge for a
    // camera in the bottom corner. Only relax it when actual occlusion regions
    // confirm this band's edge is clear; old OS/unknown metrics stay safe.
    if (cameras.isNotEmpty &&
        cameras.every(
          (camera) =>
              camera.bounds.bottom + 8 <= bandTop ||
              camera.bounds.top - 8 >= bandBottom,
        )) {
      return 0;
    }
    return inset;
  }

  final left = math.min(size.width, edgeInset(safe.left, true) + 16);
  final right = math.max(left, size.width - edgeInset(safe.right, false) - 16);
  return glassControlRegion(
    data,
    Rect.fromLTRB(
      left,
      bandTop,
      right,
      bandBottom,
    ),
    Axis.horizontal,
  );
}

/// Relocate only the inline back button, without narrowing either toolbar.
class InlinePlayerBackControl extends StatelessWidget {
  const InlinePlayerBackControl({
    super.key,
    required this.child,
    required this.onBack,
    this.enabled = true,
    this.animation = const AlwaysStoppedAnimation(1),
  });
  final Widget child;
  final VoidCallback onBack;
  final bool enabled;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    if (!enabled || !GlassCapabilities.isIOS) return child;
    final data = MediaQuery.of(context);
    if (data.size.width <= data.size.height) return child;
    return LayoutBuilder(
      builder: (context, constraints) {
        Rect? camera;
        for (final feature in data.displayFeatures) {
          if (feature.type == DisplayFeatureType.cutout &&
              feature.bounds.left < 96 &&
              feature.bounds.top < 64 &&
              feature.bounds.overlaps(Offset.zero & constraints.biggest)) {
            camera = camera == null
                ? feature.bounds
                : camera.expandToInclude(feature.bounds);
          }
        }
        if (camera == null || camera.bottom + 52 > constraints.maxHeight) {
          return child;
        }
        final left = (camera.center.dx - 22)
            .clamp(
              4.0,
              math.max(4.0, constraints.maxWidth - 48),
            )
            .toDouble();
        return _InlineBackRelocated(
          child: Stack(
            fit: StackFit.expand,
            children: [
              child,
              Positioned(
                left: left,
                top: camera.bottom + 8,
                width: 44,
                height: 44,
                child: AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) => IgnorePointer(
                    ignoring: animation.value < 0.99,
                    child: ExcludeSemantics(
                      excluding: animation.value < 0.99,
                      child: child!,
                    ),
                  ),
                  child: FadeTransition(
                    opacity: animation,
                    child: IconButton(
                      key: const ValueKey('inline-back-below-camera'),
                      tooltip: '返回',
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.chevron_left,
                        color: Colors.white,
                        shadows: [Shadow(color: Colors.black, blurRadius: 3)],
                      ),
                      onPressed: onBack,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class InlinePlayerBackSlot extends StatelessWidget {
  const InlinePlayerBackSlot({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Visibility(
    visible:
        context.dependOnInheritedWidgetOfExactType<_InlineBackRelocated>() ==
        null,
    maintainSize: true,
    maintainAnimation: true,
    maintainState: true,
    child: child,
  );
}

class _InlineBackRelocated extends InheritedWidget {
  const _InlineBackRelocated({required super.child});
  @override
  bool updateShouldNotify(_InlineBackRelocated oldWidget) => false;
}

class GlassPlayerChrome extends StatelessWidget {
  const GlassPlayerChrome({
    super.key,
    required this.animation,
    required this.header,
    required this.footer,
  });

  final Animation<double> animation;
  final Widget header;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final data = MediaQuery.of(context);
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        colorScheme: theme.colorScheme.copyWith(
          brightness: Brightness.dark,
          surface: const Color(0xFF1C1C1E),
          onSurface: Colors.white,
        ),
      ),
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) => IgnorePointer(
          ignoring: animation.value < 0.99,
          child: ExcludeSemantics(
            excluding: animation.value < 0.99,
            child: child!,
          ),
        ),
        child: Stack(
          children: [
            for (final top in [true, false])
              Positioned.fill(
                child: CustomSingleChildLayout(
                  delegate: _PlayerControlPlacement(data, top),
                  child: FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position:
                          GlassCapabilities.duration(context) == Duration.zero
                          ? const AlwaysStoppedAnimation(Offset.zero)
                          : animation.drive(
                              Tween(
                                begin: Offset(0, top ? -0.15 : 0.15),
                                end: Offset.zero,
                              ),
                            ),
                      child: top
                          ? header
                          : GlassSurface(
                              key: const ValueKey('player-glass-dock'),
                              radius: 32,
                              child: footer,
                            ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PlayerControlPlacement extends SingleChildLayoutDelegate {
  _PlayerControlPlacement(this.data, this.top);
  final MediaQueryData data;
  final bool top;

  Rect bandFor(Size size) {
    if (top) return playerControlBand(data, size, true);
    final safe = data.viewPadding;
    final cameras = data.displayFeatures.where(
      (feature) => feature.type == DisplayFeatureType.cutout,
    );
    // A short dock need not inherit the full-width toolbar's camera inset.
    // First center it in the screen/panel, then test its actual painted bounds.
    return playerControlBand(
      data.copyWith(
        viewPadding: safe.copyWith(
          left: cameras.any((c) => c.bounds.left < safe.left) ? 0 : safe.left,
          right: cameras.any((c) => c.bounds.right > size.width - safe.right)
              ? 0
              : safe.right,
        ),
        displayFeatures: [
          for (final feature in data.displayFeatures)
            if (feature.type != DisplayFeatureType.cutout) feature,
        ],
      ),
      size,
      false,
    );
  }

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final band = bandFor(constraints.biggest);
    final width = top
        ? band.width
        : math.min(band.width, (band.width * 0.72).clamp(440.0, 620.0));
    return BoxConstraints.tightFor(width: width);
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final band = bandFor(size);
    final position = Offset(
      band.center.dx - childSize.width / 2,
      top ? band.top : band.bottom - childSize.height,
    );
    if (top) return position;
    var dock = position & childSize;
    final blocks = data.displayFeatures
        .map((f) => f.bounds.inflate(8))
        .toList();
    for (final block in blocks) {
      if (!dock.overlaps(block)) continue;
      final alternatives =
          [
                dock.shift(Offset(0, block.top - dock.bottom)),
                dock.shift(Offset(block.left - dock.right, 0)),
                dock.shift(Offset(block.right - dock.left, 0)),
              ]
              .where(
                (rect) =>
                    rect.left >= band.left &&
                    rect.right <= band.right &&
                    rect.top >= data.viewPadding.top + 12 &&
                    rect.bottom <= band.bottom &&
                    !blocks.any(rect.overlaps),
              )
              .toList()
            ..sort(
              (a, b) => (a.topLeft - position).distanceSquared.compareTo(
                (b.topLeft - position).distanceSquared,
              ),
            );
      if (alternatives.isNotEmpty) dock = alternatives.first;
    }
    return dock.topLeft;
  }

  @override
  bool shouldRelayout(_PlayerControlPlacement oldDelegate) =>
      data != oldDelegate.data || top != oldDelegate.top;
}

class GlassPlayerHeader extends StatelessWidget {
  const GlassPlayerHeader({
    super.key,
    required this.back,
    required this.title,
    required this.actions,
  });
  final Widget back;
  final Widget title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final actionsWidth = actions.length * 44.0 + 12;
      final leadingWidth = math.min(
        math.min(360.0, constraints.maxWidth * 0.45),
        constraints.maxWidth - actionsWidth - 16,
      );
      return Row(
        children: [
          SizedBox(
            width: math.max(56, leadingWidth),
            child: GlassSurface(
              key: const ValueKey('player-glass-title'),
              padding: const EdgeInsets.all(6),
              child: Row(
                children: [
                  back,
                  if (leadingWidth >= 140)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4, right: 10),
                        child: title,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const Spacer(),
          const SizedBox(width: 16),
          GlassSurface(
            key: const ValueKey('player-glass-actions'),
            padding: const EdgeInsets.all(6),
            child: Row(mainAxisSize: MainAxisSize.min, children: actions),
          ),
        ],
      );
    },
  );
}

class GlassPlayerTransportRow extends StatelessWidget {
  const GlassPlayerTransportRow({
    super.key,
    required this.play,
    required this.time,
    required this.actions,
  });
  final Widget play;
  final Widget time;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final controls = Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: actions,
      );
      final textScale = MediaQuery.textScalerOf(context).scale(13) / 13;
      final timeWidth = 110 * textScale;
      if (constraints.maxWidth < 44 + timeWidth + actions.length * 48) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              children: [
                play,
                const SizedBox(width: 6),
                Expanded(child: time),
              ],
            ),
            controls,
          ],
        );
      }
      return Row(
        children: [
          play,
          const SizedBox(width: 6),
          Expanded(child: time),
          controls,
        ],
      );
    },
  );
}

/// Carries less-used playback controls into the existing top "more" sheet.
class GlassPlayerExtraControls extends InheritedWidget {
  const GlassPlayerExtraControls({
    super.key,
    required this.builder,
    required super.child,
  });
  final WidgetBuilder builder;
  static WidgetBuilder? of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<GlassPlayerExtraControls>()
      ?.builder;
  @override
  bool updateShouldNotify(GlassPlayerExtraControls oldWidget) => true;
}

/// Always present in the iOS dock, even when no subtitle track is available.
class PlayerSubtitleButton extends StatelessWidget {
  const PlayerSubtitleButton({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      selectedIndex == 0 ? Icons.closed_caption_outlined : Icons.closed_caption,
      color: labels.isEmpty ? Colors.white38 : Colors.white,
      size: 24,
    );
    if (labels.isEmpty) {
      return SizedBox.square(
        dimension: 44,
        child: IconButton(
          tooltip: 'CC 字幕：暂无可用字幕',
          onPressed: null,
          icon: icon,
        ),
      );
    }
    return PopupMenuButton<int>(
      key: const ValueKey('player-cc-button'),
      tooltip: selectedIndex == 0 ? 'CC 字幕：已关闭' : 'CC 字幕：已开启',
      initialValue: selectedIndex,
      onSelected: onSelected,
      color: const Color(0xF21C1C1E),
      itemBuilder: (_) => [
        for (var i = 0; i <= labels.length; i++)
          CheckedPopupMenuItem(
            value: i,
            checked: selectedIndex == i,
            child: Text(
              i == 0 ? '关闭字幕' : labels[i - 1],
              style: const TextStyle(color: Colors.white),
            ),
          ),
      ],
      child: SizedBox.square(dimension: 44, child: Center(child: icon)),
    );
  }
}
