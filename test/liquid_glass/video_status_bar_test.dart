import 'package:PiliPlus/common/widgets/liquid_glass/glass_platform.dart';
import 'package:PiliPlus/pages/video/widgets/video_status_bar_scope.dart';
import 'package:PiliPlus/plugin/pl_player/utils/fullscreen.dart';
import 'package:PiliPlus/plugin/pl_player/utils/system_bar_visibility.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUp(() {
    calls.clear();
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method.startsWith('SystemChrome.setEnabledSystemUI')) {
        calls.add(call);
      }
      return null;
    });
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  void expectStatusOnlyHidden() {
    expect(calls.last.method, 'SystemChrome.setEnabledSystemUIOverlays');
    expect(calls.last.arguments, ['SystemUiOverlay.bottom']);
  }

  test(
    'ordinary playback and legacy Android retain their system UI modes',
    () async {
      final modern = SystemBarVisibility();
      await modern.setBarsVisible(false);
      expect(calls.last.arguments, 'SystemUiMode.immersiveSticky');
      await modern.setBarsVisible(true);
      expect(calls.last.arguments, 'SystemUiMode.edgeToEdge');
      final legacy = SystemBarVisibility(visibleMode: SystemUiMode.manual);
      await legacy.setBarsVisible(false);
      await legacy.setBarsVisible(true);
      expect(calls.last.arguments, [
        'SystemUiOverlay.top',
        'SystemUiOverlay.bottom',
      ]);
    },
  );

  test('overlapping playback scopes restore the status bar only after the last owner', () async {
    final controller = SystemBarVisibility();
    final first = Object(), second = Object();
    await controller.suppressStatusBar(first, true);
    expectStatusOnlyHidden();
    await controller.suppressStatusBar(second, true);
    await controller.suppressStatusBar(first, false);
    expect(calls.length, 1);
    await controller.suppressStatusBar(second, false);
    expect(calls.last.arguments, 'SystemUiMode.edgeToEdge');
  });

  test(
    'exiting full screen reapplies Duo status hiding without a visible flash',
    () async {
      final controller = SystemBarVisibility();
      final owner = Object();
      await controller.suppressStatusBar(owner, true);
      await controller.setBarsVisible(false);
      expect(calls.last.arguments, 'SystemUiMode.immersiveSticky');
      await controller.setBarsVisible(true);
      expectStatusOnlyHidden();
      expect(
        calls.where((c) => c.arguments == 'SystemUiMode.edgeToEdge'),
        isEmpty,
      );
      await controller.suppressStatusBar(owner, false);
      expect(calls.last.arguments, 'SystemUiMode.edgeToEdge');
    },
  );

  test(
    'removing a route does not override an active full-screen request',
    () async {
      final controller = SystemBarVisibility();
      final owner = Object();
      await controller.suppressStatusBar(owner, true);
      await controller.setBarsVisible(false);
      await controller.suppressStatusBar(owner, false);
      expect(calls.length, 2);
      expect(calls.last.arguments, 'SystemUiMode.immersiveSticky');
      await controller.setBarsVisible(true);
      expect(calls.last.arguments, 'SystemUiMode.edgeToEdge');
    },
  );

  testWidgets(
    'menus keep the playback status preference; page changes restore it',
    (tester) async {
      tester.view.devicePixelRatio = 3;
      tester.view.physicalSize = const Size(1398, 2034);
      addTearDown(tester.view.reset);
      const channel = MethodChannel('piliplus/liquid_glass');
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => {
          'window': {
            'width': 466,
            'height': 678,
            'scale': 3,
            'verticalBarEdge': 'right',
          },
        },
      );
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      var active = true;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => GlassPlatformScope(child: child!),
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return VideoStatusBarScope(
                active: active,
                child: Scaffold(
                  body: Center(
                    child: TextButton(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                          content: TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('关闭'),
                          ),
                        ),
                      ),
                      child: const Text('菜单'),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expectStatusOnlyHidden();
      calls.clear();
      await tester.tap(find.text('菜单'));
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      update(() => active = false);
      await tester.pump();
      expect(calls.last.arguments, 'SystemUiMode.edgeToEdge');
      update(() => active = true);
      await tester.pump();
      expectStatusOnlyHidden();
      tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.paused,
      );
      tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      await tester.pumpAndSettle();
      expectStatusOnlyHidden();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(calls.last.arguments, 'SystemUiMode.edgeToEdge');
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  for (final initialEdge in ['right', 'left', 'none', null]) {
    testWidgets('playback route follows side status geometry: $initialEdge', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 3;
      tester.view.physicalSize = const Size(1398, 2034);
      addTearDown(tester.view.reset);
      var edge = initialEdge;
      var width = 466.0;
      const channel = MethodChannel('piliplus/liquid_glass');
      messenger.setMockMethodCallHandler(
        channel,
        (_) async => {
          'nativeGlass': false,
          'window': {
            'width': width,
            'height': 678,
            'scale': 3,
            'verticalBarEdge': edge,
          },
        },
      );
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          builder: (_, child) => GlassPlatformScope(child: child!),
          home: const Scaffold(body: Text('首页')),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) =>
              const VideoStatusBarScope(child: Scaffold(body: Text('播放页'))),
        ),
      );
      await tester.pumpAndSettle();
      final side = initialEdge == 'left' || initialEdge == 'right';
      if (side) {
        expectStatusOnlyHidden();
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('作者页')),
          ),
        );
        await tester.pumpAndSettle();
        expect(calls.last.arguments, 'SystemUiMode.edgeToEdge');
        navigator.currentState!.pop();
        await tester.pumpAndSettle();
        expectStatusOnlyHidden();

        // A stale size during folding must not expose the side status panel.
        width = 600;
        edge = 'none';
        await messenger.handlePlatformMessage(
          channel.name,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('accessibilityChanged'),
          ),
          (_) {},
        );
        await tester.pumpAndSettle();
        expectStatusOnlyHidden();
        width = 466;
        await messenger.handlePlatformMessage(
          channel.name,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('accessibilityChanged'),
          ),
          (_) {},
        );
        await tester.pumpAndSettle();
        expect(calls.last.arguments, 'SystemUiMode.edgeToEdge');
        edge = initialEdge;
        await messenger.handlePlatformMessage(
          channel.name,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('accessibilityChanged'),
          ),
          (_) {},
        );
        await tester.pumpAndSettle();
        expectStatusOnlyHidden();
      } else {
        expect(calls, isEmpty);
      }
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      if (side) expect(calls.last.arguments, 'SystemUiMode.edgeToEdge');
      expect(systemBarVisibility.barsVisible, isTrue);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  }
}
