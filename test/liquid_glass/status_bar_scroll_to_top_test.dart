import 'package:PiliPlus/common/widgets/liquid_glass/glass_scroll_chrome.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_status_bar_scroll_to_top.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Widget _feed(ScrollController scroll, {Future<void> Function()? onRefresh}) {
  final list = ListView(
    controller: scroll,
    physics: const AlwaysScrollableScrollPhysics(),
    children: const [SizedBox(height: 3000)],
  );
  return onRefresh == null
      ? list
      : RefreshIndicator(onRefresh: onRefresh, child: list);
}

Widget _app({
  required ScrollPosition? Function() position,
  required Widget child,
  GlobalKey<NavigatorState>? navigatorKey,
  bool sideStatusBar = false,
  bool reduceMotion = false,
}) => MaterialApp(
  navigatorKey: navigatorKey,
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        padding: sideStatusBar
            ? const EdgeInsets.only(right: 62)
            : const EdgeInsets.only(top: 60, bottom: 34),
        viewPadding: sideStatusBar
            ? const EdgeInsets.only(right: 62)
            : const EdgeInsets.only(top: 60, bottom: 34),
        disableAnimations: reduceMotion,
      ),
      child: GlassStatusBarScrollToTop(
        position: position,
        child: Material(child: child),
      ),
    ),
  ),
);

void main() {
  for (final sideStatusBar in [false, true]) {
    testWidgets(
      'native tap restores feed and chrome without refreshing (side: $sideStatusBar)',
      (tester) async {
        final chrome = GlassScrollController();
        final scroll = ScrollController();
        addTearDown(chrome.dispose);
        addTearDown(scroll.dispose);
        var refreshes = 0;
        await tester.pumpWidget(
          _app(
            position: () => chrome.position,
            sideStatusBar: sideStatusBar,
            child: GlassScrollScope(
              controller: chrome,
              child: GlassScrollBody(
                child: _feed(
                  scroll,
                  onRefresh: () async {
                    refreshes++;
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        scroll.jumpTo(700);
        await tester.pumpAndSettle();
        expect(chrome.compact, isTrue);
        tester.simulateStatusBarTap();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        expect(scroll.offset, inExclusiveRange(0, 700));
        await tester.pumpAndSettle();
        expect(scroll.offset, 0);
        expect(chrome.compact, isFalse);
        expect(chrome.blur, 0);
        tester.simulateStatusBarTap();
        await tester.pumpAndSettle();
        expect(refreshes, 0);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }

  testWidgets(
    'only the current destination scrolls; horizontal UP list is preserved',
    (tester) async {
      final chrome = [GlassScrollController(), GlassScrollController()];
      final feeds = [ScrollController(), ScrollController()];
      final ups = ScrollController();
      for (final item in [...chrome, ...feeds, ups]) {
        addTearDown(item.dispose);
      }
      var destination = 0;
      late StateSetter update;
      await tester.pumpWidget(
        _app(
          position: () => chrome[destination].position,
          child: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return IndexedStack(
                index: destination,
                children: [
                  for (var i = 0; i < 2; i++)
                    GlassScrollScope(
                      controller: chrome[i],
                      child: Column(
                        children: [
                          if (i == 1)
                            SizedBox(
                              height: 76,
                              child: GlassScrollBody(
                                child: ListView(
                                  controller: ups,
                                  scrollDirection: Axis.horizontal,
                                  children: const [SizedBox(width: 2400)],
                                ),
                              ),
                            ),
                          Expanded(
                            child: GlassScrollBody(child: _feed(feeds[i])),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      feeds[0].jumpTo(400);
      feeds[1].jumpTo(600);
      ups.jumpTo(250);
      await tester.pumpAndSettle();
      tester.simulateStatusBarTap();
      await tester.pumpAndSettle();
      expect(feeds[0].offset, 0);
      expect(feeds[1].offset, 600);
      update(() => destination = 1);
      await tester.pumpAndSettle();
      tester.simulateStatusBarTap();
      await tester.pumpAndSettle();
      expect(feeds[1].offset, 0);
      expect(ups.offset, 250);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'category changes resolve the retained active feed without rebuilding the handler',
    (tester) async {
      final chrome = GlassScrollController();
      final tabs = TabController(length: 2, vsync: tester);
      final feeds = [ScrollController(), ScrollController()];
      addTearDown(chrome.dispose);
      addTearDown(tabs.dispose);
      for (final scroll in feeds) {
        addTearDown(scroll.dispose);
      }
      await tester.pumpWidget(
        _app(
          position: () => chrome.position,
          child: GlassScrollScope(
            controller: chrome,
            child: TabBarView(
              controller: tabs,
              children: [
                for (var i = 0; i < 2; i++)
                  GlassScrollBody.tab(
                    controller: tabs,
                    index: i,
                    child: _KeptFeed(controller: feeds[i]),
                  ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      feeds[0].jumpTo(400);
      tabs.animateTo(1);
      await tester.pumpAndSettle();
      feeds[1].jumpTo(600);
      await tester.pumpAndSettle();
      tester.simulateStatusBarTap();
      await tester.pumpAndSettle();
      expect(feeds[0].offset, 400);
      expect(feeds[1].offset, 0);
      tabs.animateTo(0);
      await tester.pumpAndSettle();
      tester.simulateStatusBarTap();
      await tester.pumpAndSettle();
      expect(feeds[0].offset, 0);
      expect(chrome.compact, isFalse);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'details, dialogs and paused return gestures do not scroll the covered feed',
    (tester) async {
      final chrome = GlassScrollController();
      final scroll = ScrollController();
      final navigator = GlobalKey<NavigatorState>();
      addTearDown(chrome.dispose);
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        _app(
          navigatorKey: navigator,
          position: () => chrome.position,
          child: GlassScrollScope(
            controller: chrome,
            child: GlassScrollBody(child: _feed(scroll)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      scroll.jumpTo(500);
      await tester.pumpAndSettle();
      navigator.currentState!.push<void>(
        MaterialPageRoute(
          builder: (_) => const Material(child: Center(child: Text('详情'))),
        ),
      );
      await tester.pumpAndSettle();
      tester.simulateStatusBarTap();
      await tester.pumpAndSettle();
      expect(scroll.offset, 500);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();

      showDialog<void>(
        context: navigator.currentState!.overlay!.context,
        builder: (_) => const AlertDialog(content: Text('操作菜单')),
      );
      await tester.pumpAndSettle();
      tester.simulateStatusBarTap();
      await tester.pumpAndSettle();
      expect(scroll.offset, 500);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();

      // Persistent drawers/sheets use local history rather than a new route.
      final entry = LocalHistoryEntry();
      ModalRoute.of(
        tester.element(find.byType(GlassStatusBarScrollToTop)),
      )!.addLocalHistoryEntry(entry);
      tester.simulateStatusBarTap();
      await tester.pumpAndSettle();
      expect(scroll.offset, 500);
      entry.remove();
      await tester.pumpAndSettle();

      navigator.currentState!.didStartUserGesture();
      tester.simulateStatusBarTap();
      await tester.pump();
      expect(scroll.offset, 500);
      navigator.currentState!.didStopUserGesture();
      tester.simulateStatusBarTap();
      await tester.pumpAndSettle();
      expect(scroll.offset, 0);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'reduced motion jumps to top and removed feeds leave no native target',
    (tester) async {
      final chrome = GlassScrollController();
      final scroll = ScrollController();
      addTearDown(chrome.dispose);
      addTearDown(scroll.dispose);
      var showFeed = true;
      late StateSetter update;
      await tester.pumpWidget(
        _app(
          reduceMotion: true,
          position: () => chrome.position,
          child: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return GlassScrollScope(
                controller: chrome,
                child: showFeed
                    ? GlassScrollBody(child: _feed(scroll))
                    : const SizedBox.expand(),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      scroll.jumpTo(500);
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.simulateStatusBarTap();
      await tester.pump();
      expect(scroll.offset, 500);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      tester.simulateStatusBarTap();
      await tester.pump();
      expect(scroll.offset, 0);
      update(() => showFeed = false);
      await tester.pumpAndSettle();
      expect(chrome.position, isNull);
      tester.simulateStatusBarTap();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      tester.simulateStatusBarTap();
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}

class _KeptFeed extends StatefulWidget {
  const _KeptFeed({required this.controller});
  final ScrollController controller;

  @override
  State<_KeptFeed> createState() => _KeptFeedState();
}

class _KeptFeedState extends State<_KeptFeed>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _feed(widget.controller);
  }
}
