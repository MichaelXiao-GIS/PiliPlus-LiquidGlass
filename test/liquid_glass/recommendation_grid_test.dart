import 'package:PiliPlus/utils/grid.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('recommendations follow the current viewport on $platform', (
      tester,
    ) async {
      addTearDown(tester.view.reset);
      tester.view.devicePixelRatio = 1;
      final ios = platform == TargetPlatform.iOS;
      double preferredWidth = 240;
      Widget feed() => Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery.fromView(
          view: tester.view,
          child: Builder(
            builder: (context) => Padding(
              // The navigation rail and feed margins share the window width.
              padding: const EdgeInsets.only(right: 100),
              child: GridView.builder(
                gridDelegate: Grid.recommendationDelegate(
                  context,
                  preferredWidth: preferredWidth,
                ),
                itemCount: 40,
                itemBuilder: (_, index) => SizedBox(key: ValueKey(index)),
              ),
            ),
          ),
        ),
      );
      tester.view.physicalSize = const Size(1376, 1032);
      await tester.pumpWidget(feed());
      Future<void> layout(Size size, int columns, double gap) async {
        tester.view.physicalSize = size;
        await tester.pump();
        Rect tile(int i) => tester.getRect(find.byKey(ValueKey(i)));
        expect(tile(columns - 1).top, tile(0).top);
        expect(tile(columns).top - tile(0).bottom, closeTo(gap, 0.01));
        expect(tile(1).left - tile(0).right, closeTo(gap, 0.01));
        expect(
          tile(0).width,
          closeTo((size.width - 100 - (columns - 1) * gap) / columns, 0.01),
        );
      }

      await layout(const Size(1376, 1032), ios ? 3 : 6, ios ? 14 : 8);
      await layout(const Size(951, 669), ios ? 2 : 4, ios ? 14 : 8);
      await layout(const Size(669, 951), 3, 8);
      await layout(const Size(678, 466), 3, 8);
      await layout(const Size(1376, 1032), ios ? 3 : 6, ios ? 14 : 8);
      preferredWidth = 160;
      await tester.pumpWidget(feed());
      await layout(const Size(1376, 1032), ios ? 5 : 8, ios ? 14 : 8);
    }, variant: TargetPlatformVariant.only(platform));
  }
}
