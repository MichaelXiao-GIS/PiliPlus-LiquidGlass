import 'dart:io';

import 'package:PiliPlus/common/widgets/liquid_glass/glass_navigation_bar.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_navigation_rail.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_surface.dart';
import 'package:PiliPlus/common/widgets/main_layout.dart';
import 'package:PiliPlus/pages/setting/view.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/accounts/account.dart';
import 'package:PiliPlus/utils/ios/ios_theme.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoPageTransition;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive_ce/hive.dart';
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
    symbol: 'person',
    icon: Icon(Icons.person_outline),
  ),
];

const _homeKey = ValueKey('route-home');
const _detailKey = ValueKey('route-detail');

Widget _routes({
  bool reduced = false,
  Transition transition = Transition.native,
}) => GetMaterialApp(
  defaultTransition: transition,
  theme: IosTheme.apply(ThemeData()),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
    child: child!,
  ),
  getPages: [
    GetPage(
      name: '/',
      page: () => Material(
        key: _homeKey,
        child: Center(
          child: TextButton(
            onPressed: () => Get.toNamed('/detail'),
            child: const Text('打开'),
          ),
        ),
      ),
    ),
    GetPage(
      name: '/detail',
      page: () => const _StatefulDetail(),
    ),
  ],
);

class _StatefulDetail extends StatefulWidget {
  const _StatefulDetail();
  @override
  State<_StatefulDetail> createState() => _StatefulDetailState();
}

class _StatefulDetailState extends State<_StatefulDetail> {
  var count = 0;
  @override
  Widget build(BuildContext context) => Material(
    key: _detailKey,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('计数 $count'),
          TextButton(
            onPressed: () => setState(() => count++),
            child: const Text('增加'),
          ),
        ],
      ),
    ),
  );
}

void main() {
  late Directory temp;
  setUpAll(() async {
    temp = await Directory.systemTemp.createTemp('piliplus-ios-layout-');
    Hive.init(temp.path);
    GStorage.regAdapter();
    Accounts.account = await Hive.openBox<LoginAccount>('account');
    GStorage.setting = await Hive.openBox('setting');
  });
  tearDownAll(() async {
    await Hive.close();
    await temp.delete(recursive: true);
  });
  tearDown(Get.reset);

  for (final (size, safe) in [
    (const Size(844, 390), const EdgeInsets.only(left: 59, bottom: 21)),
    (const Size(932, 430), const EdgeInsets.only(right: 62, bottom: 21)),
    (const Size(700, 250), const EdgeInsets.only(left: 59, bottom: 21)),
  ]) {
    testWidgets(
      'landscape rail at $size keeps safe area outside its 72pt surface',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        var selection = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: const TextScaler.linear(3),
                padding: safe,
                viewPadding: safe,
              ),
              child: MainLayout(
                bottomNav: null,
                sideBar: GlassNavigationRail(
                  destinations: _destinations,
                  selectedIndex: 0,
                  onSelected: (index) => selection = index,
                  leading: const Column(
                    children: [
                      SizedBox(height: 44),
                      SizedBox(height: 44),
                      SizedBox(height: 44),
                    ],
                  ),
                ),
                body: const ColoredBox(
                  key: ValueKey('content'),
                  color: Colors.white,
                ),
              ),
            ),
          ),
        );
        expect(tester.getRect(find.byType(GlassSurface)).width, 72);
        expect(tester.getRect(find.byType(GlassSurface)).left, safe.left + 8);
        expect(
          tester.getRect(find.byKey(const ValueKey('content'))).left,
          safe.left + 8 + 72 + 8,
        );
        final bar = tester.getRect(find.byType(GlassSurface));
        for (final label in ['首页', '动态', '我的']) {
          expect(
            tester.getCenter(find.byTooltip(label)).dx,
            closeTo(bar.center.dx, 0.001),
          );
        }
        final mine = find.byTooltip('我的');
        await tester.ensureVisible(mine);
        await tester.tap(mine);
        expect(selection, 2);
        expect(tester.getRect(mine).shortestSide, greaterThanOrEqualTo(44));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('settings search has 28pt clear space below the glass title', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: IosTheme.apply(ThemeData()),
        home: const SettingPage(),
      ),
    );
    final bar = tester.getRect(find.byType(GlassSurface));
    final search = tester.getRect(
      find.byKey(const ValueKey('settings-search-entry')),
    );
    expect(search.top - bar.bottom, 28);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets(
    'iOS defaults to native and restores each supported saved choice',
    (tester) async {
      await tester.runAsync(
        () => GStorage.setting.delete(SettingBoxKey.pageTransition),
      );
      expect(Pref.pageTransition, Transition.native);
      for (final option in Transition.values) {
        await tester.runAsync(
          () => GStorage.setting.put(
            SettingBoxKey.pageTransition,
            option.index,
          ),
        );
        expect(Pref.pageTransition, option);
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'iOS pushes both pages horizontally and returns to the previous page',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_routes());
      await tester.tap(find.text('打开'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160));
      final detail = tester.getRect(find.byKey(_detailKey));
      final home = tester.getRect(find.byKey(_homeKey));
      expect(detail.left, inExclusiveRange(0, 390));
      expect(home.left, lessThan(0));
      expect(detail.top, 0);
      expect(
        (Get.rawRoute! as TransitionRoute).transitionDuration,
        const Duration(milliseconds: 500),
      );
      await tester.pumpAndSettle();
      Get.back(result: 'done');
      await tester.pumpAndSettle();
      expect(find.byKey(_homeKey), findsOneWidget);
      expect(find.byKey(_detailKey), findsNothing);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('edge swipe can be cancelled and then completed', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_routes());
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('增加'));
    await tester.pump();
    final gesture = await tester.startGesture(const Offset(1, 300));
    await gesture.moveBy(const Offset(100, 0));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getRect(find.byKey(_detailKey)).left, greaterThan(0));
    await tester.pump(const Duration(milliseconds: 500));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byKey(_detailKey), findsOneWidget);
    expect(tester.getRect(find.byKey(_detailKey)).left, 0);
    expect(find.text('计数 1'), findsOneWidget);
    await tester.timedDragFrom(
      const Offset(1, 300),
      const Offset(330, 0),
      const Duration(milliseconds: 500),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(_detailKey), findsNothing);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('reduced motion removes automatic horizontal travel', (
    tester,
  ) async {
    await tester.pumpWidget(_routes(reduced: true));
    await tester.tap(find.text('打开'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getRect(find.byKey(_detailKey)).left, 0);
    expect(tester.getRect(find.byKey(_homeKey)).left, 0);
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoPageTransition), findsWidgets);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('Android retains its selected animation and timing', (
    tester,
  ) async {
    await tester.pumpWidget(_routes(transition: Transition.zoom));
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    expect(
      (Get.rawRoute! as TransitionRoute).transitionDuration,
      const Duration(milliseconds: 300),
    );
    expect(find.byType(CupertinoPageTransition), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  for (final option in [
    Transition.fadeIn,
    Transition.rightToLeft,
    Transition.zoom,
    Transition.noTransition,
  ]) {
    testWidgets('original ${option.name} option keeps its original effect', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_routes(transition: option));
      await tester.tap(find.text('打开'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final rect = tester.getRect(find.byKey(_detailKey));
      expect(find.byType(CupertinoPageTransition), findsNothing);
      switch (option) {
        case Transition.rightToLeft:
          expect(rect.left, greaterThan(0));
        case Transition.zoom:
          // Material's zoom can animate a snapshot instead of transforming
          // the page's render box; verify its original route timing here.
          expect(
            (Get.rawRoute! as TransitionRoute).transitionDuration,
            const Duration(milliseconds: 300),
          );
        case Transition.fadeIn:
          expect(rect.left, 0);
          final fade = tester.widget<FadeTransition>(
            find
                .ancestor(
                  of: find.byKey(_detailKey),
                  matching: find.byType(FadeTransition),
                )
                .first,
          );
          expect(fade.opacity.value, inExclusiveRange(0, 1));
        case Transition.noTransition:
          expect(rect, const Rect.fromLTWH(0, 0, 390, 844));
        default:
          fail('Unexpected test option');
      }
      await tester.pumpAndSettle();
      Get.back();
      await tester.pumpAndSettle();
      expect(find.byKey(_homeKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  }
}
