import 'package:PiliPlus/common/widgets/liquid_glass/glass_navigation_bar.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_platform.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_surface.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/pages/dynamics_detail/widgets/detail_title.dart';
import 'package:PiliPlus/utils/ios/ios_theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

const _destinations = [
  GlassDestination(label: '首页', symbol: 'house', icon: Icon(Icons.home)),
  GlassDestination(
    label: '动态',
    symbol: 'rectangle.stack',
    icon: Icon(Icons.dynamic_feed),
  ),
];

class _Detail extends StatefulWidget {
  const _Detail();
  @override
  State<_Detail> createState() => _DetailState();
}

class _DetailState extends State<_Detail> {
  final scroll = ScrollController();
  int count = 0;

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SimpleScaffold(
    appBar: AppBar(title: const Text('动态详情')),
    body: ListView.builder(
      controller: scroll,
      itemExtent: 60,
      itemCount: 80,
      itemBuilder: (_, i) => Text('正文 $i'),
    ),
    fab: GlassSurface(
      child: TextButton(
        onPressed: () => setState(() => count++),
        child: Text('计数 $count'),
      ),
    ),
  );
}

void main() {
  for (final scale in [1.0, 2.0, 3.0]) {
    testWidgets(
      'detail header is labelled before and after scrolling at $scale',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(402, 874));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        bool showAuthor = false;
        int taps = 0;
        late StateSetter update;
        await tester.pumpWidget(
          MaterialApp(
            theme: IosTheme.apply(ThemeData()),
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(402, 874),
                textScaler: TextScaler.linear(scale),
              ),
              child: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return SimpleScaffold(
                    appBar: AppBar(
                      leading: const BackButton(),
                      title: DynamicDetailTitle(
                        showAuthor: showAuthor,
                        author: TextButton(
                          onPressed: () => taps++,
                          child: const Text('作者'),
                        ),
                      ),
                    ),
                    body: const SizedBox(),
                  );
                },
              ),
            ),
          ),
        );
        expect(find.text('动态详情'), findsOneWidget);
        expect(tester.getCenter(find.text('动态详情')).dx, closeTo(201, 0.5));
        expect(find.text('作者'), findsNothing);
        update(() => showAuthor = true);
        await tester.pumpAndSettle();
        expect(find.text('动态详情'), findsNothing);
        await tester.tap(find.text('作者'));
        expect(taps, 1);
        update(() => showAuthor = false);
        await tester.pumpAndSettle();
        expect(find.text('动态详情'), findsOneWidget);
        expect(find.text('作者'), findsNothing);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }

  for (final (dark, axis) in [
    for (final dark in [false, true])
      for (final axis in Axis.values) (dark, axis),
  ]) {
    testWidgets(
      'glass retains native view and freezes material while covered: $axis, dark=$dark',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(402, 874));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        var navigationCreates = 0;
        final coveredUpdates = <bool>[];
        final compact = ValueNotifier(axis == Axis.vertical);
        addTearDown(compact.dispose);
        MethodChannel? navigationChannel;
        final messenger = tester.binding.defaultBinaryMessenger
          ..setMockMethodCallHandler(
            const MethodChannel('piliplus/liquid_glass'),
            (_) async => {'nativeGlass': true},
          )
          ..setMockMethodCallHandler(
            SystemChannels.platform_views,
            (call) async {
              if (call.method == 'create' &&
                  (call.arguments as Map)['viewType'] ==
                      'piliplus/glass_navigation') {
                navigationCreates++;
                navigationChannel = MethodChannel(
                  'piliplus/glass_navigation/${(call.arguments as Map)['id']}',
                );
                tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
                  navigationChannel!,
                  (call) async {
                    if (call.method == 'update') {
                      coveredUpdates.add(
                        (call.arguments as Map)['routeCovered'] as bool,
                      );
                    }
                    return null;
                  },
                );
              }
              return null;
            },
          );
        addTearDown(() {
          messenger
            ..setMockMethodCallHandler(
              const MethodChannel('piliplus/liquid_glass'),
              null,
            )
            ..setMockMethodCallHandler(SystemChannels.platform_views, null);
          if (navigationChannel != null) {
            messenger.setMockMethodCallHandler(navigationChannel!, null);
          }
          Get.reset();
        });
        await tester.pumpWidget(
          GetMaterialApp(
            defaultTransition: Transition.native,
            theme: IosTheme.apply(
              ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
            ),
            builder: (_, child) => GlassPlatformScope(child: child!),
            getPages: [
              GetPage(
                name: '/',
                page: () => ValueListenableBuilder(
                  valueListenable: compact,
                  builder: (_, isCompact, _) => SimpleScaffold(
                    appBar: AppBar(title: const Text('动态列表')),
                    body: Center(
                      child: TextButton(
                        onPressed: () => Get.toNamed('/detail'),
                        child: const Text('打开'),
                      ),
                    ),
                    fab: SizedBox(
                      width: axis == Axis.vertical ? 60 : null,
                      height: axis == Axis.vertical ? 156 : null,
                      child: GlassNavigationBar(
                        axis: axis,
                        compact: isCompact,
                        destinations: _destinations,
                        selectedIndex: 1,
                        onSelected: (_) {},
                      ),
                    ),
                  ),
                ),
              ),
              GetPage(name: '/detail', page: () => const _Detail()),
            ],
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(UiKitView), findsNWidgets(2));
        final navigation = find.byWidgetPredicate(
          (widget) =>
              widget is UiKitView &&
              widget.viewType == 'piliplus/glass_navigation',
          skipOffstage: false,
        );
        final nativeState = tester.state(navigation);
        expect(coveredUpdates.last, isFalse);
        final expandedSize = tester.getSize(navigation);
        if (axis == Axis.horizontal) {
          compact.value = true;
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 80));
          expect(
            tester.getSize(navigation).width,
            lessThan(expandedSize.width),
          );
        }
        final capturedSize = tester.getSize(navigation);
        await tester.tap(find.text('打开'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(UiKitView), findsOneWidget);
        expect(coveredUpdates.last, isTrue);
        expect(identical(tester.state(navigation), nativeState), isTrue);
        expect(tester.getSize(navigation), capturedSize);
        // A newer scroll state may arrive under the detail page. Defer its
        // size animation so it cannot invalidate the native material snapshot.
        if (axis == Axis.horizontal) compact.value = false;
        await tester.pumpAndSettle();
        expect(find.byType(UiKitView), findsNWidgets(2));
        expect(coveredUpdates.last, isTrue);
        expect(tester.getSize(navigation), capturedSize);
        final detail = tester.state<_DetailState>(find.byType(_Detail));
        detail.scroll.jumpTo(180);
        await tester.tap(find.text('计数 0'));
        await tester.pump();
        final gesture = await tester.startGesture(const Offset(1, 300));
        await gesture.moveBy(const Offset(120, 0));
        await gesture.moveBy(const Offset(40, 0));
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(UiKitView), findsOneWidget);
        expect(coveredUpdates.last, isTrue);
        expect(identical(tester.state(navigation), nativeState), isTrue);
        expect(tester.getRect(find.byType(_Detail)).left, greaterThan(0));
        // A stationary finger must not bring native overlay surfaces back early.
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(UiKitView), findsOneWidget);
        expect(coveredUpdates.last, isTrue);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(identical(tester.state(find.byType(_Detail)), detail), isTrue);
        expect(detail.scroll.offset, 180);
        expect(find.text('计数 1'), findsOneWidget);
        expect(find.byType(UiKitView), findsNWidgets(2));
        expect(identical(tester.state(navigation), nativeState), isTrue);
        expect(navigationCreates, 1);
        expect(coveredUpdates.last, isTrue);
        await tester.timedDragFrom(
          const Offset(1, 300),
          const Offset(360, 0),
          const Duration(milliseconds: 500),
        );
        await tester.pumpAndSettle();
        expect(find.byType(_Detail), findsNothing);
        expect(coveredUpdates.last, isFalse);
        expect(navigationCreates, 1);
        expect(tester.getSize(navigation), expandedSize);
        expect(find.byType(UiKitView), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }
}
