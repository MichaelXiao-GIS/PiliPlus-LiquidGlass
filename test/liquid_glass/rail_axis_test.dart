import 'package:PiliPlus/common/widgets/liquid_glass/glass_navigation_bar.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_navigation_rail.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_platform.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_surface.dart';
import 'package:PiliPlus/common/widgets/main_layout.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _channel = MethodChannel('piliplus/liquid_glass');
const _items = [
  GlassDestination(label: '首页', symbol: 'house', icon: Icon(Icons.home)),
  GlassDestination(
    label: '动态',
    symbol: 'rectangle.stack',
    icon: Icon(Icons.feed),
  ),
  GlassDestination(label: '我的', symbol: 'person', icon: Icon(Icons.person)),
];

Widget _host(MediaQueryData data, TextDirection direction) => MaterialApp(
  home: MediaQuery(
    data: data,
    child: GlassPlatformScope(
      child: Directionality(
        textDirection: direction,
        child: MainLayout(
          floatingSideBar: true,
          bottomNav: null,
          sideBar: GlassNavigationRail(
            destinations: _items,
            selectedIndex: 0,
            onSelected: (_) {},
            actions: const [
              SizedBox.square(
                key: ValueKey('avatar'),
                dimension: 44,
                child: Icon(Icons.person),
              ),
              SizedBox.square(
                key: ValueKey('search'),
                dimension: 44,
                child: Icon(Icons.search),
              ),
            ],
            compactLeading: const Icon(Icons.more_horiz),
          ),
          body: Builder(
            builder: (context) => Padding(
              padding: GlassNavigationRail.contentInsetsOf(context),
              child: const ColoredBox(
                key: ValueKey('content'),
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  for (final edge in ['left', 'right']) {
    for (final direction in TextDirection.values) {
      for (final factor in [1.0, 1.25]) {
        for (final cameraAnchor in [false, true]) {
          testWidgets(
            'rail follows the offset system axis: $edge / $direction / $factor / camera=$cameraAnchor',
            (tester) async {
              final size = const Size(466, 678) * factor;
              await tester.binding.setSurfaceSize(size);
              addTearDown(() => tester.binding.setSurfaceSize(null));
              final left = edge == 'left';
              // Exercise both an offset status frame and the actual Duo
              // camera metrics, whose axis is about 6pt inward from the lane.
              var center = cameraAnchor
                  ? (left ? 47.833333 : 418.166667)
                  : (left ? 54.0 : 412.0);
              Map<String, Object> window() => {
                'width': 466,
                'height': 678,
                'scale': 3,
                'verticalBarEdge': edge,
                'safeArea': {
                  'left': left ? (cameraAnchor ? 84 : 90) : 0,
                  'right': left ? 0 : (cameraAnchor ? 84 : 90),
                },
                'statusBarFrame': {
                  'x': cameraAnchor ? 0 : center - 38,
                  'y': 0,
                  'width': cameraAnchor ? 466 : 76,
                  'height': cameraAnchor ? 2 : 180,
                },
                'regions': [
                  if (cameraAnchor) ...[
                    {
                      'kind': 'occlusion',
                      'x': left ? 0 : 382,
                      'y': 0,
                      'width': 84,
                      'height': 174,
                    },
                    {
                      'kind': 'occlusion',
                      'x': center - 18.5,
                      'y': 29.333333,
                      'width': 37,
                      'height': 37,
                    },
                  ],
                ],
              };
              final messenger = tester.binding.defaultBinaryMessenger
                ..setMockMethodCallHandler(
                  _channel,
                  (_) async => {'window': window()},
                );
              addTearDown(
                () => messenger.setMockMethodCallHandler(_channel, null),
              );
              await tester.pumpWidget(
                _host(
                  MediaQueryData(size: size, devicePixelRatio: 3 / factor),
                  direction,
                ),
              );
              await tester.pumpAndSettle();
              void checkAxis() {
                final content = tester.getRect(
                  find.byKey(const ValueKey('content')),
                );
                for (final element in find.byType(GlassSurface).evaluate()) {
                  final rect = tester.getRect(find.byWidget(element.widget));
                  expect(rect.center.dx, closeTo(center * factor, 0.001));
                  expect(rect.width, closeTo(60, 0.001));
                  expect(
                    rect.top,
                    greaterThanOrEqualTo(
                      cameraAnchor ? 174 * factor : 180 * factor + 12,
                    ),
                  );
                  if (left) {
                    expect(content.left, greaterThanOrEqualTo(rect.right + 8));
                  } else {
                    expect(content.right, lessThanOrEqualTo(rect.left - 8));
                  }
                }
                for (final key in ['avatar', 'search']) {
                  expect(
                    tester.getCenter(find.byKey(ValueKey(key))).dx,
                    closeTo(center * factor, 0.001),
                  );
                }
                for (final item in _items) {
                  expect(
                    tester.getCenter(find.byTooltip(item.label)).dx,
                    closeTo(center * factor, 0.001),
                  );
                }
                expect(content.bottom, size.height);
                expect(tester.takeException(), isNull);
              }

              checkAxis();
              // A scene update must move the two groups and the content gutter
              // together, without needing to recreate the navigation page.
              center += left ? 12 : -12;
              await messenger.handlePlatformMessage(
                _channel.name,
                const StandardMethodCodec().encodeMethodCall(
                  MethodCall('layoutChanged', window()),
                ),
                (_) {},
              );
              await tester.pumpAndSettle();
              checkAxis();
            },
            variant: TargetPlatformVariant.only(TargetPlatform.iOS),
          );
        }
      }
    }
  }

  for (final (name, status, nativeSize) in [
    ('hidden', Rect.zero, const Size(466, 678)),
    ('horizontal', const Rect.fromLTWH(0, 0, 466, 30), const Size(466, 678)),
    ('opposite edge', const Rect.fromLTWH(0, 0, 76, 180), const Size(466, 678)),
    (
      'outside window',
      const Rect.fromLTWH(500, 0, 76, 180),
      const Size(466, 678),
    ),
    (
      'stale rotation',
      const Rect.fromLTWH(374, 0, 76, 180),
      const Size(678, 466),
    ),
  ]) {
    testWidgets('invalid $name status frame preserves safe-area fallback', (
      tester,
    ) async {
      const size = Size(466, 678);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final messenger = tester.binding.defaultBinaryMessenger
        ..setMockMethodCallHandler(
          _channel,
          (_) async => {
            'window': {
              'width': nativeSize.width,
              'height': nativeSize.height,
              'scale': 3,
              'verticalBarEdge': 'right',
              'statusBarFrame': {
                'x': status.left,
                'y': status.top,
                'width': status.width,
                'height': status.height,
              },
            },
          },
        );
      addTearDown(() => messenger.setMockMethodCallHandler(_channel, null));
      await tester.pumpWidget(
        _host(
          const MediaQueryData(
            size: size,
            devicePixelRatio: 3,
            viewPadding: EdgeInsets.only(right: 90),
          ),
          TextDirection.ltr,
        ),
      );
      await tester.pumpAndSettle();
      for (final element in find.byType(GlassSurface).evaluate()) {
        expect(tester.getRect(find.byWidget(element.widget)).center.dx, 421);
      }
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  }
}
