import 'dart:ui' as ui;

import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_platform.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_surface.dart';
import 'package:PiliPlus/pages/home/widgets/collapsing_search_bar.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (final fraction in [1.0, 0.5, 0.01, 0.0]) {
    testWidgets('search at $fraction cannot paint over the title or tabs', (
      tester,
    ) async {
      const boundaryKey = Key('header');
      const tabsKey = Key('tabs');
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: RepaintBoundary(
              key: boundaryKey,
              child: SizedBox(
                width: 320,
                height: 180,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(
                      height: 60,
                      child: ColoredBox(color: Color(0xFF0000FF)),
                    ),
                    CollapsingSearchBar(
                      fraction: fraction,
                      child: const ColoredBox(color: Color(0xFFFF0000)),
                    ),
                    const SizedBox(
                      key: tabsKey,
                      height: 44,
                      child: ColoredBox(color: Color(0xFF00FF00)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      expect(
        tester.getTopLeft(find.byKey(tabsKey)).dy,
        closeTo(60 + Style.topBarHeight * fraction, 0.001),
      );
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(boundaryKey),
      );
      final pixels = await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        image.dispose();
        return bytes!;
      });
      // The last row of the title must stay blue even when the red search
      // field translates upward, and tabs must stay green immediately below.
      expect(pixels!.getUint32((59 * 320 + 20) * 4), 0x0000FFFF);
      final tabY = (60 + Style.topBarHeight * fraction).ceil() + 1;
      expect(pixels.getUint32((tabY * 320 + 20) * 4), 0x00FF00FF);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('hidden search cannot intercept taps or VoiceOver focus', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var fraction = 1.0;
    var taps = 0;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Column(
              children: [
                CollapsingSearchBar(
                  fraction: fraction,
                  child: TextButton(
                    onPressed: () => taps++,
                    child: const Text('搜索'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('搜索'));
    expect(taps, 1);
    for (final value in [0.5, 0.0]) {
      update(() => fraction = value);
      await tester.pumpAndSettle();
      expect(find.semantics.byLabel('搜索'), findsNothing);
      await tester.tapAt(const Offset(20, 10));
      expect(taps, 1);
    }
    update(() => fraction = 1);
    await tester.pumpAndSettle();
    await tester.tap(find.text('搜索'));
    expect(taps, 2);
    semantics.dispose();
  });

  testWidgets(
    'native glass receives no Flutter rounded mask or extra shadow',
    (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('piliplus/liquid_glass'),
        (_) async => {'nativeGlass': true},
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform_views,
        (_) async => null,
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('piliplus/liquid_glass'),
          null,
        );
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform_views,
          null,
        );
      });
      await tester.pumpWidget(
        const MaterialApp(
          home: GlassPlatformScope(
            child: Center(
              child: GlassSurface(child: SizedBox(width: 96, height: 48)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final native = find.byType(UiKitView);
      expect(native, findsOneWidget);
      expect(
        find.ancestor(of: native, matching: find.byType(ClipRRect)),
        findsNothing,
      );
      expect(
        find.ancestor(
          of: native,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is DecoratedBox &&
                widget.decoration is BoxDecoration &&
                (widget.decoration as BoxDecoration).boxShadow != null,
          ),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
