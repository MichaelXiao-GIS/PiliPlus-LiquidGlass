import 'package:PiliPlus/common/widgets/liquid_glass/glass_scroll_chrome.dart';
import 'package:PiliPlus/common/widgets/sliver/sliver_pinned_header.dart';
import 'package:PiliPlus/pages/live/widgets/sliver_pinned_header.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final inset in [0.0, 160.0]) {
    for (final follows in [false, true]) {
      testWidgets('live categories stay below glass header ($inset/$follows)', (
        tester,
      ) async {
        final scroll = ScrollController();
        addTearDown(scroll.dispose);
        var taps = 0;
        final category = SizedBox(
          height: 40,
          child: GestureDetector(
            key: const ValueKey('category'),
            behavior: HitTestBehavior.opaque,
            onTap: () => taps++,
            child: const Text('直播分类'),
          ),
        );
        Widget page(double pinned) => Directionality(
          textDirection: TextDirection.ltr,
          child: GlassScrollInsets(
            top: inset,
            pinnedTop: pinned,
            child: CustomScrollView(
              controller: scroll,
              slivers: [
                const GlassScrollSpacer(pinned: true),
                SliverMainAxisGroup(
                  slivers: [
                    if (follows)
                      LiveSliverPinnedHeader(
                        areaHeight: 40,
                        callback: (_) {},
                        child: Column(
                          children: [
                            const SizedBox(height: 120),
                            category,
                          ],
                        ),
                      )
                    else
                      SliverPinnedHeader(child: category),
                    const SliverPinnedHeader(
                      child: SizedBox(height: 32, child: Text('分类标签')),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 2000)),
                  ],
                ),
              ],
            ),
          ),
        );
        await tester.pumpWidget(page(inset));
        expect(
          tester.getTopLeft(find.byKey(const ValueKey('category'))).dy,
          inset + (follows ? 120 : 0),
        );
        scroll.jumpTo(500);
        await tester.pump();
        expect(
          tester.getTopLeft(find.byKey(const ValueKey('category'))).dy,
          inset,
        );
        expect(tester.getTopLeft(find.text('分类标签')).dy, inset + 40);
        await tester.tap(find.byKey(const ValueKey('category')));
        expect(taps, 1);
        final collapsed = inset == 0 ? 0.0 : 100.0;
        await tester.pumpWidget(page(collapsed));
        expect(
          tester.getTopLeft(find.byKey(const ValueKey('category'))).dy,
          collapsed,
        );
        expect(tester.getTopLeft(find.text('分类标签')).dy, collapsed + 40);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
