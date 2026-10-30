import 'dart:ui' as ui;

import 'package:PiliPlus/common/widgets/liquid_glass/glass_platform.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_scroll_chrome.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_tab_bar.dart';
import 'package:PiliPlus/pages/home/widgets/ios_home_header.dart';
import 'package:PiliPlus/pages/home/widgets/ios_home_header_motion.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const labels = ['直播', '推荐', '热门', '分区', '番剧', '影视'];

Widget app(Widget child, {double scale = 1}) => MaterialApp(
  theme: ThemeData(brightness: Brightness.dark),
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(scale),
        viewPadding: const EdgeInsets.only(top: 60),
      ),
      child: Material(color: Colors.black, child: child),
    ),
  ),
);

Widget header(
  BuildContext context,
  TabController tabs,
  double progress, {
  VoidCallback? search,
  VoidCallback? messages,
}) => IosHomeHeader(
  progress: progress,
  hint: '搜索视频、UP主和番剧',
  onSearch: search ?? () {},
  actions: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        width: 48,
        height: 48,
        child: IconButton(
          tooltip: '消息',
          onPressed: messages ?? () {},
          icon: const Badge(
            label: Text('1'),
            child: Icon(Icons.notifications_none),
          ),
        ),
      ),
      const SizedBox(width: 6),
      const SizedBox(width: 44, height: 44, child: Icon(Icons.person)),
    ],
  ),
  tabs: GlassTabBar(controller: tabs, labels: labels),
  tabsExtent: GlassTabBar.heightOf(context),
);

void main() {
  for (final width in [320.0, 402.0, 700.0]) {
    for (final scale in [1.0, 2.0, 3.0]) {
      testWidgets(
        'moving search avoids title, messages and categories at $width/$scale',
        (tester) async {
          await tester.binding.setSurfaceSize(Size(width, 900));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final tabs = TabController(
            length: labels.length,
            initialIndex: 1,
            vsync: tester,
          );
          addTearDown(tabs.dispose);
          var progress = 0.0;
          var searches = 0;
          var messages = 0;
          late StateSetter update;
          await tester.pumpWidget(
            app(
              StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return Align(
                    alignment: Alignment.topCenter,
                    child: header(
                      context,
                      tabs,
                      progress,
                      search: () => searches++,
                      messages: () => messages++,
                    ),
                  );
                },
              ),
              scale: scale,
            ),
          );
          await tester.pumpAndSettle();
          final expandedSearch = tester.getRect(
            find.byKey(IosHomeHeader.searchKey),
          );
          final expandedHeight = tester
              .getSize(find.byType(IosHomeHeader))
              .height;
          final frames = [for (var i = 0; i <= 40; i++) i / 40, 0.0];
          for (final value in frames) {
            update(() => progress = value);
            await tester.pumpAndSettle();
            final search = tester.getRect(find.byKey(IosHomeHeader.searchKey));
            final title = tester.getRect(find.byKey(IosHomeHeader.titleKey));
            final actions = tester.getRect(
              find.byKey(IosHomeHeader.actionsKey),
            );
            final categories = tester.getRect(
              find.byKey(IosHomeHeader.tabsKey),
            );
            expect(
              tester.getSize(find.byKey(IosHomeHeader.searchKey)).height,
              44,
            );
            expect(search.width, greaterThan(111.99));
            expect(
              search.overlaps(title),
              isFalse,
              reason: 'progress=$value search=$search title=$title',
            );
            expect(
              search.overlaps(actions),
              isFalse,
              reason: 'progress=$value search=$search actions=$actions',
            );
            final searchIcon = tester.getRect(
              find.descendant(
                of: find.byKey(IosHomeHeader.searchKey),
                matching: find.byIcon(Icons.search_rounded),
              ),
            );
            expect(searchIcon.center.dy, closeTo(search.center.dy, 0.01));
            final label = tester.getRect(
              find.byKey(IosHomeHeader.labelKey),
            );
            expect(label.center.dy, closeTo(search.center.dy, 0.01));
            expect(search.bottom + 1, lessThanOrEqualTo(categories.top));
            expect(
              categories.bottom,
              closeTo(tester.getRect(find.byType(IosHomeHeader)).bottom, 0.01),
            );
            if (value == 1) {
              expect(search.width, lessThan(expandedSearch.width));
              expect(
                (search.center.dy - actions.center.dy).abs(),
                lessThan(0.1),
              );
              expect(
                tester.getSize(find.byType(IosHomeHeader)).height,
                lessThan(expandedHeight),
              );
            }
            await tester.tap(find.byKey(IosHomeHeader.searchKey));
            await tester.tap(find.byTooltip('消息'));
            expect(tester.takeException(), isNull);
          }
          expect(searches, frames.length);
          expect(messages, frames.length);
          expect(
            tester.getRect(find.byKey(IosHomeHeader.searchKey)),
            expandedSearch,
          );
        },
      );
    }
  }

  testWidgets('search moves on both axes and reverses without a position jump', (
    tester,
  ) async {
    final tabs = TabController(length: labels.length, vsync: tester);
    addTearDown(tabs.dispose);
    var compact = false;
    var progress = 0.0;
    late StateSetter update;
    await tester.pumpWidget(
      app(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Align(
              alignment: Alignment.topCenter,
              child: IosHomeHeaderMotion(
                compact: compact,
                builder: (context, value, _) {
                  progress = value;
                  return header(context, tabs, value);
                },
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final expanded = tester.getRect(find.byKey(IosHomeHeader.searchKey));
    update(() => compact = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final moving = tester.getRect(find.byKey(IosHomeHeader.searchKey));
    expect(moving.width, lessThan(expanded.width));
    expect(moving.top, lessThan(expanded.top - 1));
    expect(progress, inExclusiveRange(0, 1));
    final beforeReversal = progress;
    update(() => compact = false);
    await tester.pump();
    expect(progress, closeTo(beforeReversal, 1e-10));
    // Momentum eases into the new direction instead of instantly changing sign.
    await tester.pump(const Duration(milliseconds: 8));
    expect(progress, greaterThan(beforeReversal));
    expect(progress - beforeReversal, lessThan(0.06));
    await tester.pump(const Duration(milliseconds: 180));
    expect(progress, lessThan(beforeReversal));
    await tester.pumpAndSettle();
    expect(progress, 0);
    expect(tester.getRect(find.byKey(IosHomeHeader.searchKey)), expanded);
    update(() => compact = true);
    await tester.pumpAndSettle();
    expect(progress, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'arc keeps narrowing through the lift and arrives without a bounce',
    (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(402, 874));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final tabs = TabController(length: labels.length, vsync: tester);
      addTearDown(tabs.dispose);
      var compact = false;
      late StateSetter update;
      await tester.pumpWidget(
        app(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return Align(
                alignment: Alignment.topCenter,
                child: IosHomeHeaderMotion(
                  compact: compact,
                  builder: (context, value, _) => header(context, tabs, value),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final search = find.byKey(IosHomeHeader.searchKey);
      final expanded = tester.getRect(search);
      update(() => compact = true);
      await tester.pump();
      final frames = <int, Rect>{0: expanded};
      for (var elapsed = 20; elapsed <= 600; elapsed += 20) {
        await tester.pump(const Duration(milliseconds: 20));
        final rect = tester.getRect(search);
        final previous = frames[elapsed - 20]!;
        expect(rect.width, lessThanOrEqualTo(previous.width + 0.001));
        expect(rect.top, lessThanOrEqualTo(previous.top + 0.001));
        frames[elapsed] = rect;
      }
      await tester.pumpAndSettle();
      final destination = tester.getRect(search);
      // In the old path width had already stopped changing at 120 ms, leaving
      // a second, visibly separate upward movement. Both now continue together.
      expect(frames[120]!.width - frames[240]!.width, greaterThan(2));
      expect(expanded.top - frames[120]!.top, inExclusiveRange(2, 25));
      expect(frames[240]!.top - destination.top, lessThan(15));
      expect(frames[400]!.top - destination.top, inInclusiveRange(0, 2));
      for (final rect in frames.values) {
        expect(rect.width, greaterThanOrEqualTo(destination.width - 0.001));
        expect(rect.top, greaterThanOrEqualTo(destination.top - 0.001));
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('reducing motion snaps an in-flight header to its destination', (
    tester,
  ) async {
    var compact = false;
    var reduced = false;
    var progress = 0.0;
    late StateSetter update;
    await tester.pumpWidget(
      app(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
              child: IosHomeHeaderMotion(
                compact: compact,
                builder: (_, value, _) {
                  progress = value;
                  return const SizedBox();
                },
              ),
            );
          },
        ),
      ),
    );
    update(() => compact = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(progress, inExclusiveRange(0, 1));
    update(() => reduced = true);
    await tester.pump();
    expect(progress, 1);
    update(() => compact = false);
    await tester.pump();
    expect(progress, 0);
    await tester.pumpAndSettle();
    expect(progress, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the category capsule has complete top and bottom edges', (
    tester,
  ) async {
    final tabs = TabController(
      length: labels.length,
      initialIndex: 1,
      vsync: tester,
    );
    addTearDown(tabs.dispose);
    const boundaryKey = Key('tab-pixels');
    await tester.pumpWidget(
      app(
        Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: boundaryKey,
            child: SizedBox(
              width: 402,
              child: ColoredBox(
                color: Colors.black,
                child: GlassTabBar(controller: tabs, labels: labels),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final outer = tester.getRect(find.byType(GlassTabBar));
    final inner = tester.getRect(find.byType(TabBar));
    expect(inner.top, greaterThanOrEqualTo(outer.top + 4));
    expect(inner.bottom, lessThanOrEqualTo(outer.bottom - 4));
    final selected = tester.getRect(find.byType(Tab).at(1));
    final pixels = await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(boundaryKey),
      );
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return bytes!;
    });
    final x = (selected.center.dx - outer.left).round();
    // Both outer edges stay black; the rounded selected fill fits between them.
    expect(pixels!.getUint32((1 * 402 + x) * 4), 0x000000FF);
    expect(
      pixels.getUint32(((outer.height.toInt() - 2) * 402 + x) * 4),
      0x000000FF,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('shrinking the pinned header never moves the content inset', (
    tester,
  ) async {
    final chrome = GlassScrollController();
    final scroll = ScrollController();
    addTearDown(chrome.dispose);
    addTearDown(scroll.dispose);
    var compact = false;
    late StateSetter update;
    await tester.pumpWidget(
      app(
        GlassScrollScope(
          controller: chrome,
          child: StatefulBuilder(
            builder: (_, setState) {
              update = setState;
              return GlassScrollPage(
                header: const SizedBox(),
                headerExtent: compact ? 116 : 168,
                contentHeaderExtent: 168,
                body: CustomScrollView(
                  controller: scroll,
                  slivers: [
                    const GlassScrollSpacer(),
                    SliverList.builder(
                      itemCount: 50,
                      itemBuilder: (_, i) =>
                          SizedBox(key: ValueKey('video$i'), height: 100),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    scroll.jumpTo(100);
    await tester.pumpAndSettle();
    final before = tester.getTopLeft(find.byKey(const ValueKey('video0')));
    update(() => compact = true);
    await tester.pumpAndSettle();
    expect(scroll.offset, 100);
    expect(tester.getTopLeft(find.byKey(const ValueKey('video0'))), before);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'one native search view survives resizing and has no header clipping mask',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final chrome = GlassScrollController();
      final tabs = TabController(
        length: labels.length,
        initialIndex: 1,
        vsync: tester,
      );
      addTearDown(chrome.dispose);
      addTearDown(tabs.dispose);
      var creates = 0;
      final messenger = tester.binding.defaultBinaryMessenger
        ..setMockMethodCallHandler(
          const MethodChannel('piliplus/liquid_glass'),
          (_) async => {'nativeGlass': true},
        )
        ..setMockMethodCallHandler(SystemChannels.platform_views, (call) async {
          if (call.method == 'create') creates++;
          return null;
        });
      addTearDown(() {
        messenger
          ..setMockMethodCallHandler(
            const MethodChannel('piliplus/liquid_glass'),
            null,
          )
          ..setMockMethodCallHandler(SystemChannels.platform_views, null);
      });
      var progress = 0.0;
      late StateSetter update;
      await tester.pumpWidget(
        app(
          GlassPlatformScope(
            child: GlassScrollScope(
              controller: chrome,
              child: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return GlassScrollPage(
                    header: header(context, tabs, progress),
                    headerExtent: IosHomeHeader.extentOf(
                      context,
                      progress,
                      GlassTabBar.heightOf(context),
                    ),
                    contentHeaderExtent: IosHomeHeader.extentOf(
                      context,
                      0,
                      GlassTabBar.heightOf(context),
                    ),
                    body: const SizedBox(),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final value in [0.225, 0.45, 0.725, 1.0, 0.0]) {
        update(() => progress = value);
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel('搜索视频、UP主和番剧'), findsOneWidget);
        expect(
          find.ancestor(
            of: find.byType(UiKitView),
            matching: find.byType(ClipRect),
          ),
          findsNothing,
        );
      }
      expect(creates, 1);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
