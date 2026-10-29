import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:PiliPlus/plugin/pl_player/widgets/glass_player_controls.dart';
import 'package:PiliPlus/plugin/pl_player/widgets/app_bar_ani.dart';
import 'package:PiliPlus/plugin/pl_player/widgets/player_control_metrics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Widget button(String name) => SizedBox.square(
  dimension: 44,
  child: IconButton(
    tooltip: name,
    onPressed: () {},
    icon: const Icon(Icons.more_horiz),
  ),
);

void main() {
  for (final isTop in [true, false]) {
    testWidgets('inline controls keep their full width: top=$isTop', (
      tester,
    ) async {
      final controller = AnimationController(vsync: tester, value: 1);
      addTearDown(controller.dispose);
      const size = Size(360, 203);
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: MediaQuery(
                data: const MediaQueryData(
                  size: size,
                  viewPadding: EdgeInsets.only(left: 92, right: 64),
                  displayFeatures: [
                    DisplayFeature(
                      bounds: Rect.fromLTWH(12, 8, 48, 54),
                      type: DisplayFeatureType.cutout,
                      state: DisplayFeatureState.unknown,
                    ),
                  ],
                ),
                child: AppBarAni(
                  controller: controller,
                  isTop: isTop,
                  isFullScreen: false,
                  removeSafeArea: false,
                  child: const SizedBox(key: ValueKey('inline-control-area')),
                ),
              ),
            ),
          ),
        ),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('inline-control-area'))).width,
        size.width,
      );
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  }

  for (final cameraAtTopLeft in [true, false]) {
    testWidgets(
      'inline back moves below only a top-left camera: $cameraAtTopLeft',
      (tester) async {
        var backs = 0;
        final animation = AnimationController(vsync: tester, value: 1);
        addTearDown(animation.dispose);
        final camera = cameraAtTopLeft
            ? const Rect.fromLTWH(20, 12, 48, 54)
            : const Rect.fromLTWH(608, 400, 48, 54);
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(678, 466),
                displayFeatures: [
                  DisplayFeature(
                    bounds: camera,
                    type: DisplayFeatureType.cutout,
                    state: DisplayFeatureState.unknown,
                  ),
                ],
              ),
              child: Center(
                child: SizedBox(
                  width: 360,
                  height: 203,
                  child: InlinePlayerBackControl(
                    animation: animation,
                    onBack: () => backs++,
                    child: SizedBox(
                      key: const ValueKey('inline-viewport'),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: InlinePlayerBackSlot(
                          child: SizedBox(
                            width: 42,
                            height: 34,
                            child: IconButton(
                              key: const ValueKey('original-back'),
                              tooltip: '返回',
                              onPressed: () => backs++,
                              icon: const Icon(Icons.arrow_back),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final viewport = tester.getRect(
          find.byKey(const ValueKey('inline-viewport')),
        );
        expect(viewport.size, const Size(360, 203));
        final moved = find.byKey(const ValueKey('inline-back-below-camera'));
        if (cameraAtTopLeft) {
          final button = tester.getRect(moved).shift(-viewport.topLeft);
          expect(button.top, camera.bottom + 8);
          expect(
            button.center.dx,
            playerControlHorizontalPadding + playerPlayButtonWidth / 2,
          );
          expect(button.size, const Size(44, 44));
          expect(
            find.byKey(const ValueKey('original-back')).hitTestable(),
            findsNothing,
          );
          expect(moved.hitTestable(), findsOneWidget);
          await tester.tap(moved);
          expect(backs, 1);
          animation.value = 0;
          await tester.pump();
          await tester.tapAt(viewport.topLeft + button.center);
          expect(backs, 1);
        } else {
          expect(moved, findsNothing);
          await tester.tap(find.byKey(const ValueKey('original-back')));
          expect(backs, 1);
        }
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }

  for (final width in [240.0, 360.0, 600.0]) {
    testWidgets(
      'inline back aligns with play even when other controls shrink: $width',
      (tester) async {
        var taps = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(678, 466),
                displayFeatures: [
                  DisplayFeature(
                    bounds: Rect.fromLTWH(20, 12, 48, 54),
                    type: DisplayFeatureType.cutout,
                    state: DisplayFeatureState.unknown,
                  ),
                ],
              ),
              child: Center(
                child: SizedBox(
                  width: width,
                  height: 203,
                  child: InlinePlayerBackControl(
                    onBack: () => taps++,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: playerControlHorizontalPadding,
                        ),
                        child: InlinePlayerTransport(
                          play: SizedBox(
                            height: 34,
                            child: IconButton(
                              key: const ValueKey('play-axis'),
                              onPressed: () => taps++,
                              icon: const Icon(Icons.play_arrow),
                            ),
                          ),
                          leading: const SizedBox(width: 100, height: 34),
                          trailing: const SizedBox(
                            key: ValueKey('secondary-controls'),
                            width: 400,
                            height: 34,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final back = find.byKey(const ValueKey('inline-back-below-camera'));
        final play = find.byKey(const ValueKey('play-axis'));
        expect(tester.getCenter(back).dx, tester.getCenter(play).dx);
        expect(tester.getSize(back), const Size(44, 44));
        expect(tester.getSize(play).width, playerPlayButtonWidth);
        final scale =
            ((width -
                        2 * playerControlHorizontalPadding -
                        playerPlayButtonWidth) /
                    500)
                .clamp(0.0, 1.0);
        expect(
          tester
              .getRect(find.byKey(const ValueKey('secondary-controls')))
              .width,
          closeTo(400 * scale, 0.01),
        );
        await tester.tap(back);
        await tester.tap(play);
        expect(taps, 2);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }

  for (final left in [true, false]) {
    testWidgets(
      'fullscreen dock stays centered with asymmetric iPhone safe area: $left',
      (tester) async {
        const size = Size(874, 402);
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final safe = EdgeInsets.only(
          left: left ? 62 : 0,
          right: left ? 0 : 62,
          bottom: 21,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(size: size, viewPadding: safe),
              child: const GlassPlayerChrome(
                animation: AlwaysStoppedAnimation(1),
                header: SizedBox(height: 56),
                footer: SizedBox(height: 82),
              ),
            ),
          ),
        );
        final dock = tester.getRect(
          find.byKey(const ValueKey('player-glass-dock')),
        );
        expect(dock.center.dx, size.width / 2);
        expect(dock.left, greaterThanOrEqualTo(safe.left));
        expect(dock.right, lessThanOrEqualTo(size.width - safe.right));
        expect(tester.takeException(), isNull);
      },
    );
  }

  test('corner camera reserves only the control band it intersects', () {
    const size = Size(678, 466);
    for (final cameraAtTop in [false, true]) {
      final data = MediaQueryData(
        size: size,
        viewPadding: const EdgeInsets.only(right: 92),
        displayFeatures: [
          DisplayFeature(
            bounds: Rect.fromLTWH(608, cameraAtTop ? 12 : 400, 48, 54),
            type: DisplayFeatureType.cutout,
            state: DisplayFeatureState.unknown,
          ),
        ],
      );
      expect(
        playerControlBand(data, size, true).right,
        cameraAtTop ? 570 : 662,
      );
      expect(
        playerControlBand(data, size, false).right,
        cameraAtTop ? 662 : 570,
      );
    }
    // No precise camera geometry: retain the system's safe inset.
    expect(
      playerControlBand(
        const MediaQueryData(
          size: size,
          viewPadding: EdgeInsets.only(right: 92),
        ),
        size,
        true,
      ).right,
      570,
    );
  });

  for (final cameraInCenter in [false, true]) {
    testWidgets(
      'dock stays centered unless its actual bounds hit the camera: $cameraInCenter',
      (tester) async {
        const size = Size(678, 466);
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final camera = Rect.fromLTWH(cameraInCenter ? 315 : 608, 400, 48, 54);
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                viewPadding: const EdgeInsets.only(right: 92),
                displayFeatures: [
                  DisplayFeature(
                    bounds: camera,
                    type: DisplayFeatureType.cutout,
                    state: DisplayFeatureState.unknown,
                  ),
                ],
              ),
              child: const Material(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: GlassPlayerChrome(
                        animation: AlwaysStoppedAnimation(1),
                        header: SizedBox(height: 56),
                        footer: SizedBox(height: 100),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        final dock = tester.getRect(
          find.byKey(const ValueKey('player-glass-dock')),
        );
        // A center camera is outside the right safe inset: keep that unknown inset.
        if (!cameraInCenter) expect(dock.center.dx, size.width / 2);
        expect(dock.overlaps(camera.inflate(7)), isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }

  final cases = [
    (
      const Size(951, 669),
      const EdgeInsets.only(left: 128, bottom: 20),
      <DisplayFeature>[],
    ),
    (
      const Size(951, 669),
      const EdgeInsets.only(right: 92, bottom: 20),
      <DisplayFeature>[],
    ),
    (
      const Size(844, 390),
      const EdgeInsets.only(left: 59, bottom: 21),
      <DisplayFeature>[],
    ),
    (
      const Size(402, 874),
      const EdgeInsets.only(top: 62, bottom: 34),
      <DisplayFeature>[],
    ),
    (
      const Size(466, 678),
      const EdgeInsets.only(right: 64),
      <DisplayFeature>[],
    ),
    (
      const Size(900, 660),
      EdgeInsets.zero,
      [
        const DisplayFeature(
          bounds: Rect.fromLTWH(438, 0, 24, 660),
          type: DisplayFeatureType.hinge,
          state: DisplayFeatureState.postureHalfOpened,
        ),
      ],
    ),
    (
      const Size(951, 669),
      EdgeInsets.zero,
      [
        const DisplayFeature(
          bounds: Rect.fromLTWH(874, 12, 61, 54),
          type: DisplayFeatureType.cutout,
          state: DisplayFeatureState.unknown,
        ),
      ],
    ),
    (
      const Size(951, 669),
      EdgeInsets.zero,
      [
        const DisplayFeature(
          bounds: Rect.fromLTWH(0, 500, 951, 24),
          type: DisplayFeatureType.hinge,
          state: DisplayFeatureState.postureHalfOpened,
        ),
      ],
    ),
  ];

  for (var i = 0; i < cases.length; i++) {
    for (final scale in [1.0, 2.0, 3.0]) {
      testWidgets(
        'floating controls clear safe areas and CC stays usable: $i / $scale',
        (tester) async {
          final (size, safe, features) = cases[i];
          await tester.binding.setSurfaceSize(size);
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final data = MediaQueryData(
            size: size,
            viewPadding: safe,
            padding: safe,
            textScaler: TextScaler.linear(scale),
            displayFeatures: features,
          );
          await tester.pumpWidget(
            MaterialApp(
              builder: (_, child) => Material(child: child),
              home: MediaQuery(
                data: data,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: GlassPlayerChrome(
                        animation: const AlwaysStoppedAnimation(1),
                        header: GlassPlayerHeader(
                          back: button('返回'),
                          title: const Text(
                            '这是一个很长的视频标题用于检查缩短和摄像头避让',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          actions: [button('发弹幕'), button('弹幕'), button('更多')],
                        ),
                        footer: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: 20, child: Divider()),
                              GlassPlayerTransportRow(
                                play: button('播放'),
                                time: const Text(
                                  '04:18 / 07:11',
                                  style: TextStyle(fontSize: 13),
                                ),
                                actions: [
                                  PlayerSubtitleButton(
                                    labels: const ['中文', 'English'],
                                    selectedIndex: 0,
                                    onSelected: (_) {},
                                  ),
                                  button('倍速'),
                                  button('画质'),
                                  button('退出全屏'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          for (final key in [
            'player-glass-title',
            'player-glass-actions',
            'player-glass-dock',
          ]) {
            final rect = tester.getRect(find.byKey(ValueKey(key)));
            expect(rect.left, greaterThanOrEqualTo(safe.left));
            expect(rect.right, lessThanOrEqualTo(size.width - safe.right));
            expect(rect.top, greaterThanOrEqualTo(safe.top));
            expect(rect.bottom, lessThanOrEqualTo(size.height - safe.bottom));
            for (final feature in features) {
              expect(rect.overlaps(feature.bounds), isFalse);
            }
          }
          final dock = tester.getRect(
            find.byKey(const ValueKey('player-glass-dock')),
          );
          final band = playerControlBand(data, size, false);
          expect(
            dock.center.dx,
            closeTo(
              features.any((f) => f.type == DisplayFeatureType.hinge)
                  ? band.center.dx
                  : size.width / 2,
              0.01,
            ),
          );
          final title = tester.getRect(
            find.byKey(const ValueKey('player-glass-title')),
          );
          final actions = tester.getRect(
            find.byKey(const ValueKey('player-glass-actions')),
          );
          expect(actions.left - title.right, greaterThanOrEqualTo(15.9));
          final cc = find.byKey(const ValueKey('player-cc-button'));
          expect(tester.getSize(cc).width, greaterThanOrEqualTo(44));
          expect(tester.getSize(cc).height, greaterThanOrEqualTo(44));
          await tester.tap(cc);
          await tester.pumpAndSettle();
          expect(find.text('English'), findsOneWidget);
          expect(find.text('关闭字幕'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('CC changes language and can turn captions off', (tester) async {
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) => Material(child: child),
        home: StatefulBuilder(
          builder: (context, update) => Center(
            child: PlayerSubtitleButton(
              labels: const ['中文', 'English'],
              selectedIndex: selected,
              onSelected: (index) => update(() => selected = index),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('player-cc-button')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.ancestor(
        of: find.text('English'),
        matching: find.byType(CheckedPopupMenuItem<int>),
      ),
    );
    await tester.pumpAndSettle();
    expect(selected, 2);
    expect(find.byTooltip('CC 字幕：已开启'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('player-cc-button')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.ancestor(
        of: find.text('关闭字幕'),
        matching: find.byType(CheckedPopupMenuItem<int>),
      ),
    );
    await tester.pumpAndSettle();
    expect(selected, 0);
    expect(find.byTooltip('CC 字幕：已关闭'), findsOneWidget);
  });

  testWidgets('CC remains visible and disabled without subtitle tracks', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) => Material(child: child),
        home: Center(
          child: PlayerSubtitleButton(
            labels: const [],
            selectedIndex: 0,
            onSelected: (_) => fail('No track can be selected'),
          ),
        ),
      ),
    );
    expect(find.byTooltip('CC 字幕：暂无可用字幕'), findsOneWidget);
    expect(
      tester.widget<IconButton>(find.byType(IconButton)).onPressed,
      isNull,
    );
  });
}
