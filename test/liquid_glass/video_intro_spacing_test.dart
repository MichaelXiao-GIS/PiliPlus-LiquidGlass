import 'package:PiliPlus/pages/video/introduction/ugc/widgets/balanced_intro_column.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  for (final available in [0.0, 180.0, 250.0, 400.0]) {
    testWidgets('action spacing uses only spare panel height: $available', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: BalancedIntroColumn(
                availableHeight: available,
                children: [
                  const SizedBox(key: ValueKey('info'), height: 140),
                  const IntroActionGap(),
                  SizedBox(
                    height: 48,
                    child: TextButton(
                      key: const ValueKey('actions'),
                      onPressed: () => taps++,
                      child: const Text('点赞'),
                    ),
                  ),
                  const SizedBox(key: ValueKey('extra'), height: 20),
                ],
              ),
            ),
          ),
        ),
      );
      final info = tester.getRect(find.byKey(const ValueKey('info')));
      final actions = tester.getRect(find.byKey(const ValueKey('actions')));
      final gap = ((available - 216) / 2).clamp(0.0, 48.0);
      expect(actions.top - info.bottom, 8 + gap);
      expect(
        tester.getRect(find.byKey(const ValueKey('extra'))).top,
        actions.bottom,
      );
      await tester.tap(find.byKey(const ValueKey('actions')));
      expect(taps, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
