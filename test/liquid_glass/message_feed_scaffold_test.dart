import 'package:PiliPlus/pages/msg_feed_top/message_feed_scaffold.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets(
    'message rows clear the toolbar once and scroll under it only on iOS',
    (tester) async {
      // A compact landscape viewport with a side camera and bottom home area.
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(568, 320);
      addTearDown(tester.view.reset);
      const safe = EdgeInsets.fromLTRB(44, 24, 0, 21);
      var actionTaps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(568, 320),
              padding: safe,
              viewPadding: safe,
            ),
            child: MessageFeedScaffold(
              appBar: AppBar(
                title: const Text('消息'),
                actions: [
                  IconButton(
                    tooltip: '设置',
                    onPressed: () => actionTaps++,
                    icon: const Icon(Icons.settings),
                  ),
                ],
              ),
              onRefresh: () async {},
              sliver: SliverFixedExtentList.builder(
                itemExtent: 56,
                itemCount: 40,
                itemBuilder: (_, index) => SizedBox.expand(
                  key: ValueKey(index),
                  child: Text('通知 $index'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final ios = defaultTargetPlatform == TargetPlatform.iOS;
      final action = find.byTooltip('设置');
      final button = tester.getRect(action);
      final toolbarBottom = tester.getBottomLeft(find.byType(AppBar)).dy;
      final viewport = tester.getRect(find.byType(CustomScrollView));
      expect(
        viewport.height,
        greaterThan(56),
        reason: "A complete row must fit beneath the toolbar: $viewport",
      );
      final first = tester.getRect(find.byKey(const ValueKey(0)));
      expect(button.left, greaterThanOrEqualTo(safe.left));
      expect(first.top, greaterThanOrEqualTo(toolbarBottom));
      if (ios) {
        expect(viewport.top, 0);
        // The capsule has a small bottom margin inside the header allocation.
        expect(first.top - toolbarBottom, lessThan(16));
      } else {
        expect(viewport.top, toolbarBottom);
        expect(first.top, toolbarBottom);
      }

      // Center the second row on the action if the viewport extends behind it.
      tester
          .state<ScrollableState>(find.byType(Scrollable))
          .position
          .jumpTo(first.top + 56 * 1.5 - button.center.dy);
      await tester.pump();
      expect(tester.getRect(action), button);
      if (ios) {
        final second = tester.getRect(find.byKey(const ValueKey(1)));
        expect(second.intersect(viewport).contains(button.center), isTrue);
      } else {
        expect(viewport.contains(button.center), isFalse);
      }
      await tester.tap(action);
      expect(actionTaps, 1);
      expect(tester.takeException(), isNull);
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
    }),
  );
}
