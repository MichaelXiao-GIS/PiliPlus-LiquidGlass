import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:PiliPlus/common/widgets/liquid_glass/glass_page_bar.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_platform.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_surface.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_window_geometry.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _window = GlassWindowGeometry(
  size: Size(669, 951),
  scale: 3,
  horizontalSizeClass: 2,
  verticalSizeClass: 2,
  verticalBarEdge: 'none',
  safeArea: EdgeInsets.only(top: 82, bottom: 34),
  statusBarFrame: Rect.fromLTWH(0, 0, 669, 2),
  features: [
    DisplayFeature(
      bounds: Rect.fromLTWH(525, 0, 144, 82),
      type: DisplayFeatureType.cutout,
      state: DisplayFeatureState.unknown,
    ),
  ],
);

void main() {
  for (final scale in [1.0, 1.25]) {
    test(
      'Duo portrait toolbar fits beside system region at UI scale $scale',
      () {
        final media = _window.apply(
          MediaQueryData(
            size: const Size(669, 951) * scale,
            devicePixelRatio: 3 / scale,
          ),
        );
        final rect = _window.topToolbarRect(media, height: 56)!;
        expect(rect.height, 56);
        expect(rect.center.dy, media.padding.top / 2);
        expect(rect.right, 525 * scale - 12);
        expect(rect.left, 24);
        expect(rect.overlaps(media.displayFeatures.single.bounds), isFalse);
      },
    );
  }
  test(
    'incomplete, stale, tall and accessibility layouts keep normal safe area',
    () {
      final media = _window.apply(
        const MediaQueryData(
          size: Size(669, 951),
          devicePixelRatio: 3,
        ),
      );
      expect(
        _window.topToolbarRect(media.copyWith(displayFeatures: []), height: 56),
        isNull,
      );
      expect(
        _window.topToolbarRect(
          media.copyWith(size: const Size(466, 678)),
          height: 56,
        ),
        isNull,
      );
      expect(
        _window.topToolbarRect(
          media.copyWith(size: const Size(951, 669)),
          height: 56,
        ),
        isNull,
      );
      expect(_window.topToolbarRect(media, height: 100), isNull);
      expect(
        _window.topToolbarRect(
          media.copyWith(textScaler: const TextScaler.linear(3)),
          height: 56,
        ),
        isNull,
      );
    },
  );
  testWidgets(
    'page bar and body inset share the free status lane; back stays tappable',
    (tester) async {
      tester.view.devicePixelRatio = 3;
      tester.view.physicalSize = const Size(2007, 2853);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      const channel = MethodChannel('piliplus/liquid_glass');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (_) async => {
          'window': {
            'width': 669,
            'height': 951,
            'scale': 3,
            'horizontalSizeClass': 2,
            'verticalSizeClass': 2,
            'verticalBarEdge': 'none',
            'safeArea': {'top': 82, 'bottom': 34},
            'statusBarFrame': {'x': 0, 'y': 0, 'width': 669, 'height': 2},
            'regions': [
              {
                'kind': 'occlusion',
                'x': 525,
                'y': 0,
                'width': 144,
                'height': 82,
              },
            ],
          },
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      var taps = 0;
      double? inset;
      await tester.pumpWidget(
        MaterialApp(
          home: GlassPlatformScope(
            child: Builder(
              builder: (context) {
                inset = GlassPageBar.topInset(context);
                return SimpleScaffold(
                  overlayAppBar: true,
                  appBar: AppBar(
                    title: const Text('设置'),
                    leading: IconButton(
                      onPressed: () => taps++,
                      icon: const Icon(Icons.arrow_back),
                    ),
                  ),
                  body: const SizedBox.expand(),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byType(GlassSurface)),
        const Rect.fromLTRB(24, 13, 513, 69),
      );
      expect(inset, 82);
      expect(
        Theme.of(tester.element(find.byType(AppBar)))
            .appBarTheme
            .systemOverlayStyle
            ?.statusBarBrightness,
        Brightness.light,
      );
      await tester.tap(find.byIcon(Icons.arrow_back));
      expect(taps, 1);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
