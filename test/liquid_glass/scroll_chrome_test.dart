import 'package:PiliPlus/common/widgets/liquid_glass/glass_navigation_bar.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_platform.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_scroll_chrome.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_surface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const destinations = [
  GlassDestination(label: '首页', symbol: 'house', icon: Icon(Icons.home)),
  GlassDestination(
    label: '动态',
    symbol: 'rectangle.stack',
    icon: Icon(Icons.dynamic_feed),
    badge: '12',
  ),
  GlassDestination(label: '我的', symbol: 'person', icon: Icon(Icons.person)),
];

Widget app(
  Widget child, {
  double textScale = 1,
  bool opaque = false,
  bool reduceMotion = false,
}) => MaterialApp(
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        padding: const EdgeInsets.only(top: 60, bottom: 34),
        viewPadding: const EdgeInsets.only(top: 60, bottom: 34),
        textScaler: TextScaler.linear(textScale),
        highContrast: opaque,
        disableAnimations: reduceMotion,
      ),
      child: Material(child: child),
    ),
  ),
);

void main() {
  test('top bounce stays expanded and small offset changes do not flicker', () {
    final chrome = GlassScrollController();
    addTearDown(chrome.dispose);
    for (final offset in [-90.0, 0.0, 40.0, 63.0]) {
      chrome.update(offset);
      expect(chrome.compact, isFalse);
    }
    chrome.update(64);
    expect(chrome.compact, isTrue);
    for (final offset in [65.0, 63.0, 35.0, 13.0]) {
      chrome.update(offset);
      expect(chrome.compact, isTrue);
    }
    chrome.update(12);
    expect(chrome.compact, isFalse);
    chrome.update(-40);
    expect(chrome.blur, 0);
  });

  testWidgets('content scrolls behind the status area and navigation shrinks', (
    tester,
  ) async {
    final chrome = GlassScrollController();
    final scroll = ScrollController();
    addTearDown(chrome.dispose);
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      app(
        GlassScrollScope(
          controller: chrome,
          child: Stack(
            children: [
              GlassScrollPage(
                header: const Center(child: Text('浏览')),
                headerExtent: 100,
                body: GlassScrollBody(
                  child: CustomScrollView(
                    controller: scroll,
                    slivers: [
                      const GlassScrollSpacer(),
                      SliverList.builder(
                        itemCount: 50,
                        itemBuilder: (_, i) => SizedBox(
                          key: ValueKey('item$i'),
                          height: 80,
                          child: Text('视频 $i'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: ListenableBuilder(
                  listenable: chrome,
                  builder: (_, _) => GlassNavigationBar(
                    destinations: destinations,
                    selectedIndex: 0,
                    onSelected: (_) {},
                    compact: chrome.compact,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final filters = find.byType(BackdropFilter);
    expect(tester.widget<BackdropFilter>(filters.first).enabled, isFalse);
    expect(tester.getTopLeft(find.byKey(const ValueKey('item0'))).dy, 160);
    final expanded = tester.getSize(find.byType(GlassSurface));
    // A programmatic scroll has no dragDetails and still updates the chrome.
    scroll.jumpTo(120);
    await tester.pumpAndSettle();
    expect(chrome.compact, isTrue);
    expect(tester.widget<BackdropFilter>(filters.first).enabled, isTrue);
    expect(tester.getTopLeft(find.byKey(const ValueKey('item0'))).dy, 40);
    final compact = tester.getSize(find.byType(GlassSurface));
    expect(compact.width, lessThan(expanded.width));
    expect(compact.height, 54);
    expect(compact.width, 202);
    // Returning upward in the middle of the feed keeps it compact.
    scroll.jumpTo(90);
    await tester.pumpAndSettle();
    expect(chrome.compact, isTrue);
    scroll.jumpTo(0);
    await tester.pumpAndSettle();
    expect(chrome.compact, isFalse);
    expect(tester.getSize(find.byType(GlassSurface)), expanded);
    expect(tester.widget<BackdropFilter>(filters.first).enabled, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'category changes restore their own offsets; horizontal carousels are ignored',
    (tester) async {
      final chrome = GlassScrollController();
      final first = ScrollController();
      final second = ScrollController();
      final horizontal = ScrollController();
      addTearDown(chrome.dispose);
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      addTearDown(horizontal.dispose);
      late StateSetter update;
      var active = 0;
      await tester.pumpWidget(
        app(
          GlassScrollScope(
            controller: chrome,
            child: StatefulBuilder(
              builder: (_, setState) {
                update = setState;
                return Column(
                  children: [
                    SizedBox(
                      height: 80,
                      child: GlassScrollBody(
                        child: ListView(
                          controller: horizontal,
                          scrollDirection: Axis.horizontal,
                          children: const [SizedBox(width: 1800)],
                        ),
                      ),
                    ),
                    Expanded(
                      child: IndexedStack(
                        index: active,
                        children: [
                          for (var i = 0; i < 2; i++)
                            GlassScrollBody(
                              active: active == i,
                              child: ListView(
                                controller: i == 0 ? first : second,
                                children: const [SizedBox(height: 2400)],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      horizontal.jumpTo(200);
      await tester.pumpAndSettle();
      expect(chrome.compact, isFalse);
      first.jumpTo(200);
      await tester.pumpAndSettle();
      expect(chrome.compact, isTrue);
      update(() => active = 1);
      await tester.pumpAndSettle();
      expect(chrome.compact, isFalse);
      first.jumpTo(300); // Off-screen retained feed must not affect this page.
      await tester.pumpAndSettle();
      expect(chrome.compact, isFalse);
      update(() => active = 0);
      await tester.pumpAndSettle();
      expect(chrome.compact, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [320.0, 390.0, 700.0]) {
    for (final scale in [1.0, 3.0]) {
      testWidgets(
        'compact bar keeps 44pt targets and labels for accessibility: $width/$scale',
        (tester) async {
          await tester.binding.setSurfaceSize(Size(width, 844));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final semantics = tester.ensureSemantics();
          var selected = -1;
          await tester.pumpWidget(
            app(
              Align(
                alignment: Alignment.bottomCenter,
                child: GlassNavigationBar(
                  destinations: destinations,
                  selectedIndex: 0,
                  compact: true,
                  onSelected: (i) => selected = i,
                ),
              ),
              textScale: scale,
            ),
          );
          await tester.pumpAndSettle();
          final bar = tester.getRect(find.byType(GlassSurface));
          expect(bar.center.dx, width / 2);
          expect(bar.width, 202);
          for (final label in ['首页', '动态', '我的']) {
            final rect = tester.getRect(find.bySemanticsLabel(label));
            expect(rect.width, greaterThanOrEqualTo(44));
            expect(rect.height, greaterThanOrEqualTo(44));
            expect(rect.bottom, lessThanOrEqualTo(844 - 34));
          }
          expect(
            tester.getSemantics(find.bySemanticsLabel('动态')).value,
            '12 条未读动态',
          );
          await tester.tap(find.bySemanticsLabel('我的'));
          expect(selected, 2);
          expect(tester.takeException(), isNull);
          semantics.dispose();
        },
      );
    }
  }

  testWidgets(
    'restored scroll positions compact the capsule before a new drag',
    (tester) async {
      final chrome = GlassScrollController();
      final scroll = ScrollController(initialScrollOffset: 200);
      addTearDown(chrome.dispose);
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        app(
          GlassScrollScope(
            controller: chrome,
            child: GlassScrollBody(
              child: ListView(
                controller: scroll,
                children: const [SizedBox(height: 2400)],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(chrome.compact, isTrue);
      expect(chrome.blur, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('bouncing a short page never collapses the capsule', (
    tester,
  ) async {
    final chrome = GlassScrollController();
    addTearDown(chrome.dispose);
    var everCompact = false;
    chrome.addListener(() {
      everCompact |= chrome.compact;
    });
    await tester.pumpWidget(
      app(
        GlassScrollScope(
          controller: chrome,
          child: GlassScrollBody(
            child: ListView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              children: const [SizedBox(height: 100)],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -250));
    await tester.pumpAndSettle();
    expect(everCompact, isFalse);
    expect(chrome.blur, 0);
  });

  testWidgets('increased contrast uses an opaque scroll-edge surface', (
    tester,
  ) async {
    final chrome = GlassScrollController()..update(150);
    addTearDown(chrome.dispose);
    await tester.pumpWidget(
      app(
        GlassScrollScope(
          controller: chrome,
          child: const GlassScrollPage(
            header: SizedBox(),
            headerExtent: 100,
            body: SizedBox(),
          ),
        ),
        opaque: true,
      ),
    );
    expect(
      tester.widget<BackdropFilter>(find.byType(BackdropFilter)).enabled,
      isFalse,
    );
    final colored = tester.widget<ColoredBox>(
      find
          .descendant(
            of: find.byType(BackdropFilter),
            matching: find.byType(ColoredBox),
          )
          .first,
    );
    expect(colored.color.a, 1);
  });

  testWidgets(
    'native capsule keeps the same view and receives icon-only progress',
    (tester) async {
      var creates = 0;
      final updates = <Map<Object?, Object?>>[];
      final messenger = tester.binding.defaultBinaryMessenger;
      final channels = <MethodChannel>[];
      messenger
        ..setMockMethodCallHandler(
          const MethodChannel('piliplus/liquid_glass'),
          (_) async => {'nativeGlass': true},
        )
        ..setMockMethodCallHandler(SystemChannels.platform_views, (
          call,
        ) async {
          if (call.method == 'create') {
            creates++;
            final args = call.arguments as Map;
            final channel = MethodChannel(
              'piliplus/glass_navigation/${args['id']}',
            );
            channels.add(channel);
            messenger.setMockMethodCallHandler(channel, (call) async {
              updates.add(Map<Object?, Object?>.from(call.arguments as Map));
              return null;
            });
          }
          return null;
        });
      addTearDown(() {
        messenger
          ..setMockMethodCallHandler(
            const MethodChannel('piliplus/liquid_glass'),
            null,
          )
          ..setMockMethodCallHandler(SystemChannels.platform_views, null);
        for (final channel in channels) {
          messenger.setMockMethodCallHandler(channel, null);
        }
      });
      late StateSetter update;
      var compact = false;
      await tester.pumpWidget(
        app(
          GlassPlatformScope(
            child: StatefulBuilder(
              builder: (_, setState) {
                update = setState;
                return Align(
                  alignment: Alignment.bottomCenter,
                  child: GlassNavigationBar(
                    destinations: destinations,
                    selectedIndex: 0,
                    compact: compact,
                    onSelected: (_) {},
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      update(() => compact = true);
      await tester.pumpAndSettle();
      expect(creates, 1);
      expect(updates.last['compactProgress'], 1);
      expect(tester.getSize(find.byType(UiKitView)), const Size(202, 54));
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('reduced motion switches size without an animation', (
    tester,
  ) async {
    late StateSetter update;
    var compact = false;
    await tester.pumpWidget(
      app(
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return Align(
              alignment: Alignment.bottomCenter,
              child: GlassNavigationBar(
                destinations: destinations,
                selectedIndex: 0,
                onSelected: (_) {},
                compact: compact,
              ),
            );
          },
        ),
        reduceMotion: true,
      ),
    );
    await tester.pumpAndSettle();
    update(() => compact = true);
    await tester.pump();
    expect(tester.getSize(find.byType(GlassSurface)), const Size(202, 54));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
