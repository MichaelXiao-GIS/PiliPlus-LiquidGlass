import 'dart:io';
import 'dart:ui' show DisplayFeature, DisplayFeatureType, DisplayFeatureState;

import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/video_card/video_card_h.dart';
import 'package:PiliPlus/models/model_hot_video_item.dart';
import 'package:PiliPlus/pages/video/widgets/video_detail_layout.dart';
import 'package:PiliPlus/pages/video/widgets/video_detail_tabs.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/accounts/account.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:material_ui/material_ui.dart';

const _labels = ['相关视频', '评论 12.3万', '播放列表'];
const _title = '【经典回顾】细腻的台内控制，线路的绝对压制';
const _actionsKey = ValueKey('danmaku-actions');

Widget _actions() => Row(
  key: _actionsKey,
  mainAxisSize: MainAxisSize.min,
  mainAxisAlignment: MainAxisAlignment.end,
  children: [
    TextButton(
      style: TextButton.styleFrom(
        minimumSize: const Size(64, 44),
        padding: EdgeInsets.zero,
      ),
      onPressed: () {},
      child: const Text('发弹幕', style: TextStyle(fontSize: 12)),
    ),
    IconButton(onPressed: () {}, icon: const Icon(Icons.subtitles)),
  ],
);

HotVideoItemModel _video() => HotVideoItemModel.fromJson({
  'aid': 1,
  'bvid': 'BV1yeJQ6zECa',
  'title': _title,
  'pic': '',
  'pubdate': 1792100000,
  'duration': 96,
  'owner': {'mid': 1, 'name': '劳模秀昕'},
  'stat': {'view': 1234567, 'danmaku': 12345},
});

void main() {
  late Directory temp;
  setUpAll(() async {
    temp = await Directory.systemTemp.createTemp('piliplus-video-layout-');
    Hive.init(temp.path);
    GStorage.regAdapter();
    Accounts.account = await Hive.openBox<LoginAccount>('account');
    GStorage.setting = await Hive.openBox('setting');
  });
  tearDownAll(() async {
    await Hive.close();
    await temp.delete(recursive: true);
  });

  testWidgets(
    'fold replaces animated tabs without reusing a disposed animation',
    (tester) async {
      var controller = TabController(length: 3, vsync: tester);
      Widget page() => MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: VideoDetailTabs(
            controller: controller,
            labels: _labels.take(controller.length).toList(),
            actions: _actions(),
            onTap: (_) {},
          ),
        ),
      );
      await tester.pumpWidget(page());
      controller.animateTo(2);
      await tester.pump(const Duration(milliseconds: 80));
      controller.dispose();
      controller = TabController(length: 2, vsync: tester);
      addTearDown(controller.dispose);
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('评论 12.3万'));
      await tester.pumpAndSettle();
      expect(controller.index, 1);
    },
  );

  for (final cameraOnLeft in [true, false]) {
    testWidgets(
      'corner camera does not reserve a full-height content strip: $cameraOnLeft',
      (tester) async {
        const size = Size(951, 669);
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final safe = EdgeInsets.only(
          left: cameraOnLeft ? 92 : 0,
          right: cameraOnLeft ? 0 : 92,
        );
        late Size viewport;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                viewPadding: safe,
                padding: safe,
                displayFeatures: [
                  DisplayFeature(
                    bounds: Rect.fromLTWH(
                      cameraOnLeft ? 16 : 887,
                      cameraOnLeft ? 12 : 595,
                      48,
                      54,
                    ),
                    type: DisplayFeatureType.cutout,
                    state: DisplayFeatureState.unknown,
                  ),
                ],
              ),
              child: VideoDetailViewport(
                insets: safe,
                origin: Offset.zero,
                builder: (_, value) {
                  viewport = value;
                  return const SizedBox.expand(
                    key: ValueKey('edge-to-edge-video'),
                  );
                },
              ),
            ),
          ),
        );
        expect(viewport, size);
        expect(
          tester.getRect(find.byKey(const ValueKey('edge-to-edge-video'))),
          Offset.zero & size,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final (size, safe) in [
    (const Size(844, 390), const EdgeInsets.only(left: 59, bottom: 21)),
    (const Size(951, 669), const EdgeInsets.only(right: 92, bottom: 20)),
    (
      const Size(1280, 900),
      const EdgeInsets.only(right: 100, top: 40, bottom: 20),
    ),
    (const Size(600, 320), const EdgeInsets.only(left: 50, right: 12)),
  ]) {
    testWidgets('video and related panels fit the inset viewport at $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final tabs = TabController(length: 3, vsync: tester);
      addTearDown(tabs.dispose);
      late MediaQueryData local;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: size, padding: safe, viewPadding: safe),
            child: Column(
              children: [
                SizedBox(height: safe.top),
                Expanded(
                  child: VideoDetailViewport(
                    insets: safe.copyWith(top: 0, bottom: 0),
                    origin: Offset(0, safe.top),
                    builder: (context, viewport) {
                      local = MediaQuery.of(context);
                      final width = VideoPaneWidth.landscape(viewport);
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            key: const ValueKey('player-pane'),
                            width: width,
                            height: width / (16 / 9),
                            child: const ColoredBox(color: Colors.black),
                          ),
                          SizedBox(
                            key: const ValueKey('related-pane'),
                            width: viewport.width - width,
                            child: Column(
                              children: [
                                VideoDetailTabs(
                                  controller: tabs,
                                  labels: _labels,
                                  actions: _actions(),
                                  onTap: (_) {},
                                ),
                                Expanded(
                                  child: ListView(
                                    children: [
                                      SizedBox(
                                        height: 110,
                                        child: VideoCardH(
                                          videoItem: _video(),
                                          adaptive: true,
                                        ),
                                      ),
                                    ],
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
              ],
            ),
          ),
        ),
      );
      final player = tester.getRect(find.byKey(const ValueKey('player-pane')));
      final related = tester.getRect(
        find.byKey(const ValueKey('related-pane')),
      );
      expect(player.left, safe.left);
      expect(player.right, related.left);
      expect(related.right, size.width - safe.right);
      expect(
        related.width,
        greaterThanOrEqualTo(VideoPaneWidth.minimumPanel(local.size.width)),
      );
      expect(local.viewPadding.left, 0);
      expect(local.viewPadding.right, 0);
      expect(local.viewPadding.top, 0);
      expect(local.viewPadding.bottom, safe.bottom);
      final cover = tester.getRect(find.byType(NetworkImgLayer));
      final title = tester.getRect(find.text(_title));
      expect(title.left, greaterThan(cover.right));
      expect(title.width, greaterThan(75));
      expect(title.right, lessThanOrEqualTo(related.right));
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [200.0, 280.0, 320.0, 425.0, 900.0]) {
    for (final scale in [1.0, 2.0, 3.0]) {
      testWidgets('tabs stay separate and selectable at $width / $scale', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(Size(width, 400));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final controller = TabController(length: 3, vsync: tester);
        addTearDown(controller.dispose);
        var selected = -1;
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 400),
                textScaler: TextScaler.linear(scale),
              ),
              child: Align(
                alignment: Alignment.topLeft,
                child: VideoDetailTabs(
                  controller: controller,
                  labels: _labels,
                  actions: _actions(),
                  onTap: (i) => selected = i,
                ),
              ),
            ),
          ),
        );
        if (width <= 320) {
          final label = tester.getRect(find.text('相关视频'));
          final actions = tester.getRect(find.byKey(_actionsKey));
          expect(actions.top, greaterThanOrEqualTo(label.bottom));
        }
        await tester.ensureVisible(find.text('播放列表'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('播放列表'));
        await tester.pumpAndSettle();
        expect(controller.index, 2);
        expect(selected, 2);
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final width in [200.0, 240.0, 280.0, 320.0, 425.0]) {
    testWidgets('related card keeps its cover and text inside $width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 300));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              height: 110,
              child: VideoCardH(videoItem: _video(), adaptive: true),
            ),
          ),
        ),
      );
      final cover = tester.getRect(find.byType(NetworkImgLayer));
      final title = tester.getRect(find.text(_title));
      expect(cover.right, lessThan(title.left));
      expect(title.width, greaterThan(75));
      expect(title.right, lessThanOrEqualTo(width));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('full-screen player retains the full viewport width', (
    tester,
  ) async {
    const size = Size(951, 669);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    late Size viewport;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: size,
            viewPadding: EdgeInsets.only(right: 92),
          ),
          child: VideoDetailViewport(
            insets: EdgeInsets.zero,
            origin: Offset.zero,
            builder: (_, size) {
              viewport = size;
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );
    expect(viewport, size);
    expect(
      VideoPaneWidth.heightFitted(const Size(840, 530), 9 / 16),
      lessThanOrEqualTo(520),
    );
    expect(tester.takeException(), isNull);
  });
}
