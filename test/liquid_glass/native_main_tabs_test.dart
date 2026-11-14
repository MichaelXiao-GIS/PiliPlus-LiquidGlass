import 'package:PiliPlus/common/widgets/liquid_glass/glass_platform.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/native_main_tabs.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets(
    'syncs selected feed metrics and excludes dialogs and local overlays',
    (tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(GlassCapabilities.channel, (
        call,
      ) async {
        calls.add(call);
        return call.method == 'setNativeTabs' ? true : null;
      });
      addTearDown(
        () =>
            messenger.setMockMethodCallHandler(GlassCapabilities.channel, null),
      );
      final navigator = GlobalKey<NavigatorState>();
      final scroll = ScrollController();
      var overlayVisible = false;
      var installed = false;
      final selections = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          navigatorObservers: [nativeTabRoutes],
          home: Scaffold(
            body: Stack(
              children: [
                ListView(
                  controller: scroll,
                  children: const [SizedBox(height: 4000)],
                ),
                NativeMainTabs(
                  enabled: true,
                  selectedIndex: 1,
                  destinations: const [
                    {'id': 'mine', 'title': '我的'},
                    {'id': 'dynamics', 'title': '动态', 'badge': '99+'},
                  ],
                  axis: Axis.vertical,
                  tint: 0xff55aa00,
                  dark: true,
                  onSelected: selections.add,
                  position: () => scroll.hasClients ? scroll.position : null,
                  modalOverlayVisible: () => overlayVisible,
                  onInstalled: (value) => installed = value,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump();
      Map latestConfig() =>
          calls.lastWhere((c) => c.method == 'setNativeTabs').arguments as Map;
      expect(installed, isTrue);
      expect(latestConfig(), containsPair('selectedIndex', 1));
      expect(latestConfig(), containsPair('axis', 'vertical'));
      expect(latestConfig()['destinations'][1]['badge'], '99+');
      expect(latestConfig()['visible'], isTrue);
      GlassCapabilities.onNativeTabSelected!(1);
      GlassCapabilities.onNativeTabSelected!(3);
      expect(selections, [1]);
      scroll.jumpTo(820);
      await tester.pump();
      final metrics =
          calls.lastWhere((c) => c.method == 'nativeTabScroll').arguments
              as Map;
      expect(metrics['destinationId'], 'dynamics');
      expect(metrics['offset'], 820.0);
      expect(metrics['max'], scroll.position.maxScrollExtent);
      expect(metrics['viewport'], scroll.position.viewportDimension);
      final context = navigator.currentContext!;
      showDialog<void>(
        context: context,
        builder: (_) => const AlertDialog(content: Text('dialog')),
      );
      await tester.pumpAndSettle();
      expect(latestConfig()['visible'], isFalse);
      GlassCapabilities.onNativeTabSelected!(0);
      expect(selections, [1]);
      navigator.currentState!.pop();
      await tester.pump(const Duration(milliseconds: 40));
      expect(latestConfig()['visible'], isFalse);
      await tester.pumpAndSettle();
      expect(latestConfig()['visible'], isTrue);
      overlayVisible = true;
      tester.binding.scheduleFrame();
      await tester.pump();
      expect(latestConfig()['visible'], isFalse);
      overlayVisible = false;
      tester.binding.scheduleFrame();
      await tester.pump();
      expect(latestConfig()['visible'], isTrue);
      expect(scroll.offset, 820);
      await tester.pumpWidget(const SizedBox());
      expect(latestConfig()['visible'], isFalse);
      expect(GlassCapabilities.onNativeTabSelected, isNull);
      scroll.dispose();
    },
  );

  testWidgets('keeps Flutter navigation until a visible install succeeds', (
    tester,
  ) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var attempts = 0;
    var installed = false;
    var modal = true;
    messenger.setMockMethodCallHandler(GlassCapabilities.channel, (call) async {
      if (call.method == 'setNativeTabs' && call.arguments['visible'] == true) {
        attempts++;
        return attempts >= 2;
      }
      return true;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(GlassCapabilities.channel, null),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: NativeMainTabs(
          enabled: true,
          selectedIndex: 0,
          destinations: const [
            {'id': 'home'},
            {'id': 'mine'},
          ],
          axis: Axis.horizontal,
          tint: 0xff55aa00,
          dark: false,
          onSelected: (_) {},
          position: () => null,
          modalOverlayVisible: () => modal,
          onInstalled: (value) => installed = value,
        ),
      ),
    );
    expect(installed, isFalse);
    expect(attempts, 0);
    modal = false;
    tester.binding.scheduleFrame();
    await tester.pump();
    expect(attempts, 1);
    expect(installed, isFalse);
    await tester.pump(const Duration(milliseconds: 100));
    expect(attempts, 1);
    await tester.pump(const Duration(milliseconds: 200));
    expect(attempts, 2);
    expect(installed, isTrue);
    await tester.pumpWidget(const SizedBox());
  });
}
