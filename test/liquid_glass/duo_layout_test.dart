import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:PiliPlus/common/widgets/liquid_glass/glass_navigation_bar.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_navigation_rail.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_platform.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_surface.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_window_geometry.dart';
import 'package:PiliPlus/common/widgets/main_layout.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _items = [
  GlassDestination(label: '首页', symbol: 'house', icon: Icon(Icons.home)),
  GlassDestination(
    label: '动态',
    symbol: 'rectangle.stack',
    icon: Icon(Icons.dynamic_feed),
  ),
  GlassDestination(label: '我的', symbol: 'person', icon: Icon(Icons.person)),
];

DisplayFeature _fold(Rect bounds) => DisplayFeature(
  bounds: bounds,
  type: DisplayFeatureType.hinge,
  state: DisplayFeatureState.postureHalfOpened,
);

void main() {
  // The inner display is regular even below the old 700pt breakpoint.
  for (final (size, horizontal, vertical, bottom) in [
    (const Size(626, 890), 2, 2, false),
    (const Size(890, 626), 2, 2, false),
    (const Size(466, 678), 1, 2, true),
    (const Size(678, 466), 1, 1, false),
    (const Size(360, 626), 1, 2, true),
  ]) {
    test(
      'native size classes select navigation for $size ($horizontal/$vertical)',
      () {
        final geometry = GlassWindowGeometry(
          size: size,
          scale: 3,
          horizontalSizeClass: horizontal,
          verticalSizeClass: vertical,
        );
        expect(
          geometry.bottomNavigation(
            MediaQueryData(size: size, devicePixelRatio: 3),
          ),
          bottom,
        );
      },
    );
  }

  for (final (size, edge, bottom) in [
    (const Size(466, 678), 'right', false),
    (const Size(626, 890), 'none', true),
    (const Size(890, 626), 'right', false),
    (const Size(890, 626), 'left', false),
  ]) {
    test('system vertical edge overrides size classes at $size / $edge', () {
      final geometry = GlassWindowGeometry.fromMap({
        'width': size.width,
        'height': size.height,
        'scale': 3,
        'horizontalSizeClass': 2,
        'verticalSizeClass': 2,
        'verticalBarEdge': edge,
        'statusBarFrame': const {'x': 800, 'y': 0, 'width': 90, 'height': 140},
      });
      final data = MediaQueryData(size: size, devicePixelRatio: 3);
      expect(geometry.bottomNavigation(data), bottom);
      expect(geometry.railOnLeft(data), edge == 'left');
      expect(
        geometry.statusBarBounds(data),
        const Rect.fromLTWH(800, 0, 90, 140),
      );
    });
  }

  test('stale inner-screen traits cannot override the new outer window', () {
    const geometry = GlassWindowGeometry(
      size: Size(626, 890),
      scale: 3,
      horizontalSizeClass: 2,
      verticalSizeClass: 2,
      safeArea: EdgeInsets.all(80),
    );
    const outer = MediaQueryData(size: Size(466, 678), devicePixelRatio: 3);
    expect(geometry.matches(outer), isFalse);
    expect(geometry.bottomNavigation(outer), isTrue);
    expect(identical(geometry.apply(outer), outer), isTrue);
  });

  test(
    'native safe areas and camera/fold bounds follow the application UI scale',
    () {
      final geometry = GlassWindowGeometry.fromMap(const {
        'width': 626,
        'height': 890,
        'scale': 3,
        'horizontalSizeClass': 2,
        'verticalSizeClass': 2,
        'safeArea': {'left': 8, 'top': 40, 'right': 12, 'bottom': 20},
        'regions': [
          {'kind': 'division', 'x': 300, 'y': 0, 'width': 26, 'height': 890},
          {'kind': 'occlusion', 'x': 600, 'y': 20, 'width': 10, 'height': 10},
          {'kind': 'division', 'x': 313, 'y': 0, 'width': 0, 'height': 890},
        ],
      });
      final data = geometry.apply(
        const MediaQueryData(
          size: Size(313, 445),
          devicePixelRatio: 6,
          viewPadding: EdgeInsets.only(left: 7),
          viewInsets: EdgeInsets.only(bottom: 150),
        ),
      );
      expect(data.viewPadding, const EdgeInsets.fromLTRB(7, 20, 6, 10));
      expect(data.padding, const EdgeInsets.fromLTRB(7, 20, 6, 0));
      expect(data.viewInsets.bottom, 150);
      expect(data.displayFeatures.length, 2);
      expect(
        data.displayFeatures.first.bounds,
        const Rect.fromLTWH(150, 0, 13, 445),
      );
      expect(data.displayFeatures.last.type, DisplayFeatureType.cutout);
      expect(geometry.bottomNavigation(data), isFalse);
    },
  );

  test(
    'a vertical fold displaces controls without reducing the feed viewport',
    () {
      final data = MediaQueryData(
        size: const Size(890, 626),
        displayFeatures: [
          _fold(const Rect.fromLTWH(435, 0, 20, 626)),
        ],
      );
      expect(
        glassControlRegion(
          data,
          const Rect.fromLTWH(16, 520, 858, 64),
          Axis.horizontal,
        ),
        const Rect.fromLTRB(455, 520, 874, 584),
      );
      expect(data.size, const Size(890, 626));
    },
  );

  test('a horizontal fold selects the lower portion of the rail', () {
    final data = MediaQueryData(
      displayFeatures: [
        _fold(const Rect.fromLTWH(0, 435, 626, 20)),
      ],
    );
    expect(
      glassControlRegion(
        data,
        const Rect.fromLTWH(8, 40, 72, 810),
        Axis.vertical,
      ),
      const Rect.fromLTRB(8, 455, 80, 850),
    );
  });

  testWidgets(
    'padded content receives local feature coordinates and safe areas',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(890, 626));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      late MediaQueryData local;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(890, 626),
              padding: const EdgeInsets.fromLTRB(10, 40, 12, 20),
              viewPadding: const EdgeInsets.fromLTRB(10, 40, 12, 20),
              displayFeatures: [_fold(const Rect.fromLTWH(435, 0, 20, 626))],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(98, 40, 12, 0),
              child: GlassContentViewport(
                origin: const Offset(98, 40),
                child: Builder(
                  builder: (context) {
                    local = MediaQuery.of(context);
                    return const SizedBox.expand();
                  },
                ),
              ),
            ),
          ),
        ),
      );
      expect(local.size, const Size(780, 586));
      expect(local.padding, const EdgeInsets.only(bottom: 20));
      expect(
        local.displayFeatures.single.bounds,
        const Rect.fromLTWH(337, 0, 20, 586),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('bottom capsule stays in one region and remains tappable', (
    tester,
  ) async {
    const size = Size(626, 890);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            displayFeatures: [
              _fold(const Rect.fromLTWH(300, 0, 26, 890)),
            ],
          ),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: GlassNavigationBar(
              destinations: _items,
              selectedIndex: 0,
              onSelected: (i) => selected = i,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final rect = tester.getRect(find.byType(GlassSurface));
    expect(rect.left, greaterThanOrEqualTo(326));
    expect(rect.right, lessThanOrEqualTo(610));
    await tester.tap(find.text('我的'));
    expect(selected, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rail fits below a horizontal fold with asymmetric safe areas', (
    tester,
  ) async {
    const size = Size(626, 890);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            viewPadding: const EdgeInsets.fromLTRB(10, 40, 12, 20),
            displayFeatures: [_fold(const Rect.fromLTWH(0, 435, 626, 20))],
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: GlassNavigationRail(
              destinations: _items,
              selectedIndex: 0,
              onSelected: (_) {},
              actions: const [
                SizedBox.square(dimension: 44),
                SizedBox.square(dimension: 44),
              ],
              compactLeading: const SizedBox(height: 48),
            ),
          ),
        ),
      ),
    );
    final rect = tester.getRect(find.byType(GlassSurface).last);
    expect(rect.left, 546);
    expect(rect.top, greaterThanOrEqualTo(455));
    expect(rect.bottom, 858);
    expect(rect.width, 60);
    expect(rect.height, 156);
    expect(tester.takeException(), isNull);
  });

  for (final edge in ['left', 'right']) {
    for (final direction in TextDirection.values) {
      for (final folded in [false, true]) {
        testWidgets(
          '$edge gutter keeps content edge-to-edge at $direction / folded=$folded',
          (tester) async {
            const channel = MethodChannel('piliplus/liquid_glass');
            const size = Size(890, 626);
            await tester.binding.setSurfaceSize(size);
            addTearDown(() => tester.binding.setSurfaceSize(null));
            tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
              channel,
              (_) async => {
                'window': {
                  'width': 890,
                  'height': 626,
                  'scale': 1,
                  'verticalBarEdge': edge,
                  'safeArea': {
                    'left': edge == 'left' ? 90 : 20,
                    'top': 10,
                    'right': edge == 'right' ? 90 : 20,
                    'bottom': 20,
                  },
                  'statusBarFrame': {
                    'x': edge == 'left' ? 0 : 800,
                    'y': 0,
                    'width': 90,
                    'height': 150,
                  },
                  'regions': [
                    if (folded)
                      {
                        'kind': 'division',
                        'x': 0,
                        'y': 300,
                        'width': 890,
                        'height': 20,
                      },
                  ],
                },
              },
            );
            addTearDown(
              () => tester.binding.defaultBinaryMessenger
                  .setMockMethodCallHandler(channel, null),
            );
            var selected = 0;
            late MediaQueryData local;
            await tester.pumpWidget(
              MaterialApp(
                home: MediaQuery(
                  data: const MediaQueryData(size: size),
                  child: GlassPlatformScope(
                    child: Builder(
                      builder: (context) => Directionality(
                        textDirection: direction,
                        child: MainLayout(
                          floatingSideBar: true,
                          bottomNav: null,
                          sideBar: GlassNavigationRail(
                            destinations: _items,
                            selectedIndex: 0,
                            onSelected: (value) => selected = value,
                            actions: const [
                              Icon(Icons.account_circle),
                              Icon(Icons.search),
                            ],
                            compactLeading: const Center(
                              child: Icon(Icons.more_horiz),
                            ),
                          ),
                          body: Builder(
                            builder: (context) {
                              final insets =
                                  GlassNavigationRail.contentInsetsOf(context);
                              return Padding(
                                padding: insets,
                                child: GlassContentViewport(
                                  origin: Offset(insets.left, insets.top),
                                  child: Builder(
                                    builder: (context) {
                                      local = MediaQuery.of(context);
                                      return const ColoredBox(
                                        key: ValueKey('edge-content'),
                                        color: Colors.white,
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            final content = tester.getRect(
              find.byKey(const ValueKey('edge-content')),
            );
            expect(content.left, edge == 'left' ? 90 : 20);
            expect(
              content.right,
              edge == 'right' ? 800 : 870,
            ); // Reuse the existing system edge gutter.
            expect(
              content.bottom,
              size.height,
            ); // No fixed strip clips the feed.
            expect(
              local.viewPadding.bottom,
              20,
            ); // Safe-area metrics remain for content controls.
            expect(local.padding.bottom, 20);
            for (final surface in find.byType(GlassSurface).evaluate()) {
              final rect = tester.getRect(find.byWidget(surface.widget));
              expect(rect.center.dx, edge == 'right' ? 845 : 45);
              expect(rect.top, greaterThanOrEqualTo(folded ? 320 : 162));
              expect(rect.bottom, lessThanOrEqualTo(594));
            }
            await tester.tap(find.byTooltip('我的'));
            expect(selected, 2);
            expect(tester.takeException(), isNull);
          },
          variant: TargetPlatformVariant.only(TargetPlatform.iOS),
        );
      }
    }
  }

  testWidgets(
    'native layout events update same-size posture without remounting content',
    (tester) async {
      const channel = MethodChannel('piliplus/liquid_glass');
      const size = Size(626, 890);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final window = <String, dynamic>{
        'width': 626,
        'height': 890,
        'scale': 3,
        'horizontalSizeClass': 2,
        'verticalSizeClass': 2,
      };
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (_) async => {'window': window},
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      late MediaQueryData data;
      late bool bottom;
      final contentKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: size, devicePixelRatio: 3),
            child: GlassPlatformScope(
              child: Builder(
                key: contentKey,
                builder: (context) {
                  data = MediaQuery.of(context);
                  bottom = GlassCapabilities.bottomNavigation(context);
                  return const SizedBox.expand();
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final original = contentKey.currentContext;
      expect(bottom, isFalse);
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          MethodCall('layoutChanged', {
            ...window,
            'regions': const [
              {
                'kind': 'division',
                'x': 300,
                'y': 0,
                'width': 26,
                'height': 890,
              },
            ],
          }),
        ),
        (_) {},
      );
      await tester.pumpAndSettle();
      expect(
        data.displayFeatures.single.bounds,
        const Rect.fromLTWH(300, 0, 26, 890),
      );
      expect(identical(contentKey.currentContext, original), isTrue);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
