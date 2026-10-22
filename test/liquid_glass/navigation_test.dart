import 'package:PiliPlus/common/widgets/liquid_glass/glass_navigation_bar.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_platform.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_surface.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_tab_bar.dart';
import 'package:PiliPlus/utils/ios/ios_theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _destinations = [
  GlassDestination(
    label: '首页',
    symbol: 'house',
    icon: Icon(Icons.home_outlined),
  ),
  GlassDestination(
    label: '动态',
    symbol: 'rectangle.stack',
    icon: Icon(Icons.dynamic_feed),
    badge: '12',
  ),
  GlassDestination(
    label: '我的',
    symbol: 'person.crop.circle',
    icon: Icon(Icons.person_outline),
  ),
];

Widget _app(
  Widget child, {
  double textScale = 1,
  bool dark = false,
  bool highContrast = false,
}) => MaterialApp(
  theme: IosTheme.apply(
    ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFFB7299),
        brightness: dark ? Brightness.dark : Brightness.light,
      ),
    ),
  ),
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
        highContrast: highContrast,
        padding: const EdgeInsets.only(bottom: 34),
        viewPadding: const EdgeInsets.only(bottom: 34),
      ),
      child: Material(child: child),
    ),
  ),
);

void main() {
  testWidgets(
    'selection and re-selection both reach the existing router callback',
    (tester) async {
      final selections = <int>[];
      var selected = 0;
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) => Align(
              alignment: Alignment.bottomCenter,
              child: GlassNavigationBar(
                destinations: _destinations,
                selectedIndex: selected,
                onSelected: (index) {
                  selections.add(index);
                  setState(() => selected = index);
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('动态'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('动态'));
      await tester.pumpAndSettle();
      expect(selected, 1);
      expect(selections, [1, 1]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'VoiceOver exposes selection, unread count and a working tap action',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          Align(
            alignment: Alignment.bottomCenter,
            child: GlassNavigationBar(
              destinations: _destinations,
              selectedIndex: 0,
              onSelected: (_) {},
            ),
          ),
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('动态')),
        matchesSemantics(
          label: '动态',
          value: '12 条未读动态',
          isButton: true,
          hasSelectedState: true,
          hasTapAction: true,
          isFocusable: true,
          hasFocusAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('首页')),
        matchesSemantics(
          label: '首页',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
          isFocusable: true,
          hasFocusAction: true,
        ),
      );
      semantics.dispose();
    },
  );

  for (final width in [320.0, 390.0, 700.0]) {
    for (final scale in [1.0, 2.0, 3.0]) {
      testWidgets(
        'navigation fits ${width.toInt()}pt at ${scale}x text without covering the home indicator',
        (tester) async {
          await tester.binding.setSurfaceSize(Size(width, 844));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(
            _app(
              Align(
                alignment: Alignment.bottomCenter,
                child: GlassNavigationBar(
                  destinations: _destinations,
                  selectedIndex: 0,
                  onSelected: (_) {},
                ),
              ),
              textScale: scale,
              dark: scale == 2,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          for (final label in ['首页', '动态', '我的']) {
            final rect = tester.getRect(find.bySemanticsLabel(label));
            expect(rect.width, greaterThanOrEqualTo(44));
            expect(rect.height, greaterThanOrEqualTo(44));
            expect(rect.bottom, lessThanOrEqualTo(844 - 34));
          }
        },
      );
    }
  }

  testWidgets('increased contrast removes translucency', (tester) async {
    await tester.pumpWidget(
      _app(
        const Center(
          child: GlassSurface(child: SizedBox(width: 200, height: 44)),
        ),
        highContrast: true,
      ),
    );
    final filter = tester.widget<BackdropFilter>(find.byType(BackdropFilter));
    expect(filter.enabled, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'native accessibility changes are refreshed while the app remains open',
    (tester) async {
      const channel = MethodChannel('piliplus/liquid_glass');
      var reduceTransparency = false;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (call) async => {
          'nativeGlass': false,
          'reduceTransparency': reduceTransparency,
          'reduceMotion': true,
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.pumpWidget(
        _app(
          const GlassPlatformScope(
            child: Center(
              child: GlassSurface(child: SizedBox(width: 200, height: 44)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<BackdropFilter>(find.byType(BackdropFilter)).enabled,
        isTrue,
      );
      reduceTransparency = true;
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('accessibilityChanged'),
        ),
        (_) {},
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<BackdropFilter>(find.byType(BackdropFilter)).enabled,
        isFalse,
      );
      final context = tester.element(find.byType(GlassSurface));
      expect(GlassCapabilities.duration(context), Duration.zero);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'secondary tabs preserve their controller and scroll on narrow screens',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = TabController(length: 7, vsync: tester);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _app(
          Column(
            children: [
              GlassTabBar(
                controller: controller,
                labels: const ['推荐', '热门', '直播', '番剧', '影视', '排行榜', '稍后再看'],
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.text('热门'));
      await tester.pumpAndSettle();
      expect(controller.index, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
