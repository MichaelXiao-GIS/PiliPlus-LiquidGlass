import 'dart:ui' as ui;

import 'package:PiliPlus/common/widgets/liquid_glass/glass_feathered_backdrop.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('blur reveals backdrop detail continuously across the feather', (
    tester,
  ) async {
    const pixelsKey = ValueKey('pixels');
    const top = 19;
    const solid = 24;
    const feather = 48;
    const width = 96;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: pixelsKey,
            child: SizedBox(
              width: width.toDouble(),
              height: 112,
              child: Stack(
                children: [
                  for (var i = 0; i < width ~/ 4; i++)
                    Positioned(
                      left: i * 4.0,
                      top: 0,
                      bottom: 0,
                      width: 4,
                      child: ColoredBox(
                        color: i.isEven ? Colors.black : Colors.white,
                      ),
                    ),
                  const Positioned(
                    left: 9,
                    right: 5,
                    top: top * 1.0,
                    height: (solid + feather) * 1.0,
                    child: GlassFeatheredBackdrop(
                      solidExtent: solid * 1.0,
                      featherExtent: feather * 1.0,
                      blur: 1,
                      color: Colors.white,
                      opaque: false,
                      tintOpacity: 0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final pixels = await tester.runAsync(() async {
      final image = await tester
          .renderObject<RenderRepaintBoundary>(find.byKey(pixelsKey))
          .toImage(pixelRatio: 1);
      try {
        return await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      } finally {
        image.dispose();
      }
    });
    int red(int x, int y) => pixels!.getUint8((y * width + x) * 4);
    int contrast(int y) => (red(41, y) - red(45, y)).abs();

    expect(contrast(top - 1), 255);
    expect(contrast(top + solid - 1), lessThan(10));
    expect(contrast(top + solid + feather), 255);
    for (var y = top + solid; y <= top + solid + feather; y++) {
      expect(
        contrast(y) - contrast(y - 1),
        inInclusiveRange(-2, 12),
        reason: 'Visible jump in stripe contrast at row $y',
      );
    }
    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(
      tester.widget<BackdropFilter>(find.byType(BackdropFilter)).enabled,
      isTrue,
    );
  });
  testWidgets('flat and opaque headers disable backdrop sampling', (
    tester,
  ) async {
    for (final state in [(0.0, false), (1.0, true)]) {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: GlassFeatheredBackdrop(
            solidExtent: 24,
            blur: state.$1,
            color: Colors.white,
            opaque: state.$2,
          ),
        ),
      );
      expect(
        tester
            .widgetList<BackdropFilter>(find.byType(BackdropFilter))
            .where((filter) => filter.enabled),
        isEmpty,
      );
    }
  });
}
