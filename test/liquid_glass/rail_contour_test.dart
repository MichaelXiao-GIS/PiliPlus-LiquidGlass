import 'dart:math' as math;

import 'package:PiliPlus/common/widgets/liquid_glass/glass_navigation_bar.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_navigation_rail.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_surface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

// Check the visible discs against the capsule's curved ends, rather than just
// comparing rectangles: centered rectangles alone missed the touching rims.
void expectClearContour(Rect disc, Rect capsule) {
  final outline = RRect.fromRectAndRadius(capsule, const Radius.circular(30));
  final radius = disc.shortestSide / 2 + 5.9;
  for (var step = 0; step < 32; step++) {
    final angle = 2 * math.pi * step / 32;
    expect(
      outline.contains(
        disc.center + Offset(math.cos(angle), math.sin(angle)) * radius,
      ),
      isTrue,
      reason:
          'The selected disc must keep a clear 6pt gap from the capsule rim.',
    );
  }
}

void main() {
  for (final actionCount in [2, 3]) {
    for (final selected in [0, 2]) {
      for (final textScale in [1.0, 3.0]) {
        testWidgets(
          'separate circular contours: $actionCount actions, selected $selected, text $textScale',
          (tester) async {
            const size = Size(466, 678);
            await tester.binding.setSurfaceSize(size);
            addTearDown(() => tester.binding.setSurfaceSize(null));
            await tester.pumpWidget(
              MaterialApp(
                home: MediaQuery(
                  data: MediaQueryData(
                    size: size,
                    viewPadding: const EdgeInsets.only(right: 90),
                    textScaler: TextScaler.linear(textScale),
                  ),
                  child: GlassNavigationRail(
                    selectedIndex: selected,
                    onSelected: (_) {},
                    destinations: [
                      for (var i = 0; i < 3; i++)
                        GlassDestination(
                          label: '导航$i',
                          symbol: 'house',
                          icon: const Icon(Icons.home),
                        ),
                    ],
                    actions: [
                      for (var i = 0; i < actionCount; i++)
                        SizedBox.square(
                          key: ValueKey('action$i'),
                          dimension: 44,
                          child: const Icon(Icons.person),
                        ),
                    ],
                    compactLeading: const Icon(Icons.more_horiz),
                  ),
                ),
              ),
            );
            final toolbar = tester.getRect(find.byType(GlassSurface).first);
            final navigation = tester.getRect(find.byType(GlassSurface).last);
            for (var i = 0; i < actionCount; i++) {
              final rect = tester.getRect(find.byKey(ValueKey('action$i')));
              expect(rect.center.dx, toolbar.center.dx);
              expectClearContour(rect, toolbar);
            }
            final buttonFinder = find.byWidgetPredicate(
              (widget) =>
                  widget is IconButton && widget.tooltip == '导航$selected',
            );
            final button = tester.widget<IconButton>(buttonFinder);
            expect(button.style!.shape!.resolve({}), isA<CircleBorder>());
            expectClearContour(tester.getRect(buttonFinder), navigation);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
