import 'package:PiliPlus/common/widgets/liquid_glass/glass_navigation_bar.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_tab_scrubber.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _items = [
  GlassDestination(label: '首页', symbol: 'house', icon: Icon(Icons.home)),
  GlassDestination(
    label: '动态',
    symbol: 'rectangle.stack',
    icon: Icon(Icons.dynamic_feed),
    badge: '3',
  ),
  GlassDestination(label: '我的', symbol: 'person', icon: Icon(Icons.person)),
];
final _lens = find.byKey(const ValueKey('glass-tab-lens'));
Finder _item(int index) => find.bySemanticsLabel(_items[index].label);

Widget _app({
  required ValueChanged<int> onSelected,
  bool compact = false,
  bool rtl = false,
  bool accessible = false,
  Axis axis = Axis.horizontal,
}) {
  var selected = 0;
  return MaterialApp(
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: accessible,
          highContrast: accessible,
        ),
        child: Directionality(
          textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
          child: Material(
            child: StatefulBuilder(
              builder: (context, setState) => Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  width: axis == Axis.vertical ? 60 : null,
                  height: axis == Axis.vertical ? 156 : null,
                  child: GlassNavigationBar(
                    axis: axis,
                    destinations: _items,
                    selectedIndex: selected,
                    compact: compact,
                    onSelected: (index) {
                      onSelected(index);
                      setState(() => selected = index);
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<TestGesture> _dragTo(
  WidgetTester tester,
  Offset target,
) async {
  final start = tester.getCenter(_item(0));
  final gesture = await tester.startGesture(start);
  await gesture.moveTo(Offset.lerp(start, target, 0.4)!);
  await tester.pump();
  await gesture.moveTo(target);
  await tester.pump();
  return gesture;
}

void main() {
  for (final rtl in [false, true]) {
    testWidgets(
      'vertical rail previews, snaps, preserves badges and tap actions rtl=$rtl',
      (tester) async {
        final selections = <int>[];
        await tester.pumpWidget(
          _app(onSelected: selections.add, axis: Axis.vertical, rtl: rtl),
        );
        final target = tester.getCenter(_item(2));
        final bar = tester.getRect(find.byType(GlassTabScrubber));
        final gesture = await _dragTo(tester, target);
        expect(_lens, findsOneWidget);
        expect(tester.getRect(_lens).center.dy, closeTo(target.dy, 9));
        expect(tester.getRect(_lens).center.dx, bar.center.dx);
        expect(selections, isEmpty);
        expect(tester.getSemantics(_item(1)).value, '3 条未读动态');
        await gesture.up();
        await tester.pumpAndSettle();
        expect(selections, [2]);
        await tester.tap(_item(1));
        await tester.pumpAndSettle();
        expect(selections, [2, 1]);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final cancel in ['pointer', 'outside', 'return', 'horizontal']) {
    testWidgets('vertical rail $cancel cancels without selection', (
      tester,
    ) async {
      final selections = <int>[];
      await tester.pumpWidget(
        _app(onSelected: selections.add, axis: Axis.vertical),
      );
      final start = tester.getCenter(_item(0));
      final gesture = cancel == 'horizontal'
          ? await tester.startGesture(start)
          : await _dragTo(tester, tester.getCenter(_item(2)));
      if (cancel == 'pointer') {
        await gesture.cancel();
      } else {
        await gesture.moveTo(
          cancel == 'return' ? start : start - const Offset(120, 0),
        );
        await gesture.up();
      }
      await tester.pumpAndSettle();
      expect(selections, isEmpty);
      expect(_lens, findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'vertical rail lens clamps to the end and supports reduced motion',
    (tester) async {
      final selections = <int>[];
      await tester.pumpWidget(
        _app(onSelected: selections.add, axis: Axis.vertical, accessible: true),
      );
      final bar = tester.getRect(find.byType(GlassTabScrubber));
      final gesture = await _dragTo(
        tester,
        Offset(bar.center.dx, bar.bottom + 100),
      );
      expect(tester.getRect(_lens).bottom, lessThanOrEqualTo(bar.bottom));
      expect(tester.getRect(_lens).height, 48);
      await gesture.up();
      await tester.pump();
      expect(selections, [2]);
      expect(_lens, findsNothing);
    },
  );

  for (final compact in [false, true]) {
    for (final rtl in [false, true]) {
      testWidgets(
        'drag previews then commits once; compact=$compact rtl=$rtl',
        (
          tester,
        ) async {
          final selections = <int>[];
          await tester.pumpWidget(
            _app(onSelected: selections.add, compact: compact, rtl: rtl),
          );
          final target = tester.getCenter(_item(2));
          final gesture = await _dragTo(tester, target);
          expect(_lens, findsOneWidget);
          expect(selections, isEmpty);
          expect(tester.getRect(_lens).center.dx, closeTo(target.dx, 9));
          await gesture.up();
          await tester.pumpAndSettle();
          expect(selections, [2]);
          expect(_lens, findsNothing);
          // Ordinary taps, including the app's existing re-selection action, stay usable.
          await tester.tap(_item(2));
          await tester.pumpAndSettle();
          expect(selections, [2, 2]);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final cancel in ['pointer', 'outside', 'return']) {
    testWidgets('$cancel restores selection without refreshing the page', (
      tester,
    ) async {
      final selections = <int>[];
      await tester.pumpWidget(_app(onSelected: selections.add));
      final gesture = await _dragTo(tester, tester.getCenter(_item(2)));
      if (cancel == 'pointer') {
        await gesture.cancel();
      } else {
        await gesture.moveTo(
          cancel == 'outside'
              ? tester.getCenter(_item(2)) - const Offset(0, 120)
              : tester.getCenter(_item(0)),
        );
        await gesture.up();
      }
      await tester.pumpAndSettle();
      expect(selections, isEmpty);
      expect(_lens, findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('lens stays inside bar when dragging beyond its end', (
    tester,
  ) async {
    final selections = <int>[];
    await tester.pumpWidget(_app(onSelected: selections.add));
    final bar = tester.getRect(find.byType(GlassTabScrubber));
    final gesture = await _dragTo(
      tester,
      Offset(bar.right + 100, bar.center.dy),
    );
    expect(tester.getRect(_lens).right, lessThanOrEqualTo(bar.right));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(selections, [2]);
  });

  testWidgets('a second drag cancels an unfinished snap', (tester) async {
    final selections = <int>[];
    await tester.pumpWidget(_app(onSelected: selections.add));
    final first = await _dragTo(tester, tester.getCenter(_item(2)));
    await first.up();
    await tester.pump(const Duration(milliseconds: 80));
    final second = await _dragTo(tester, tester.getCenter(_item(1)));
    await second.up();
    await tester.pumpAndSettle();
    expect(selections, [1]);
  });

  testWidgets('accessibility removes stretch, blur and settling delay', (
    tester,
  ) async {
    final selections = <int>[];
    await tester.pumpWidget(
      _app(onSelected: selections.add, accessible: true),
    );
    final gesture = await _dragTo(tester, tester.getCenter(_item(1)));
    expect(
      tester.getRect(_lens).width,
      closeTo(tester.getRect(_item(1)).width, 0.001),
    );
    final filter = tester.widget<BackdropFilter>(
      find.ancestor(of: _lens, matching: find.byType(BackdropFilter)).first,
    );
    expect(filter.enabled, isFalse);
    await gesture.up();
    await tester.pump();
    expect(selections, [1]);
    expect(_lens, findsNothing);
  });

  testWidgets('vertical movement does not start the tab gesture', (
    tester,
  ) async {
    final selections = <int>[];
    await tester.pumpWidget(_app(onSelected: selections.add));
    final gesture = await tester.startGesture(tester.getCenter(_item(0)));
    await gesture.moveBy(const Offset(0, -80));
    await tester.pump();
    expect(_lens, findsNothing);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(selections, isEmpty);
  });

  testWidgets('removing the bar during a snap does not select a page', (
    tester,
  ) async {
    final selections = <int>[];
    await tester.pumpWidget(_app(onSelected: selections.add));
    final gesture = await _dragTo(tester, tester.getCenter(_item(2)));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(selections, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
