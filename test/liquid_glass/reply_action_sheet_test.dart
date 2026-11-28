import 'dart:collection';
import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:PiliPlus/grpc/bilibili/main/community/reply/v1.pb.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/pages/save_panel/view.dart';
import 'package:PiliPlus/pages/video/reply/widgets/reply_action_sheet.dart';
import 'package:PiliPlus/pages/video/reply/widgets/reply_item_grpc.dart';
import 'package:PiliPlus/pages/video/reply/widgets/reply_threaded_indent_box.dart';
import 'package:PiliPlus/pages/video/reply_reply/controller.dart';
import 'package:PiliPlus/pages/video/reply_reply/tree.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/ios/ios_theme.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive_ce/hive.dart';
import 'package:material_ui/material_ui.dart';

ReplyInfo _reply(String message, int id) => ReplyInfo(
  id: Int64(id),
  mid: Int64(99),
  member: Member(mid: Int64(99), name: '测试评论作者'),
  content: Content(message: message),
);

MediaQueryData _metrics(Size size, {String? camera, double textScale = 1}) {
  final left = camera?.contains('left') ?? false;
  final bottom = camera?.contains('bottom') ?? false;
  final side = camera != null;
  final padding = EdgeInsets.fromLTRB(
    side && left ? 84 : 0,
    side ? 0 : 59,
    side && !left ? 84 : 0,
    34,
  );
  return MediaQueryData(
    size: size,
    viewPadding: padding,
    padding: padding,
    textScaler: TextScaler.linear(textScale),
    displayFeatures: side
        ? [
            DisplayFeature(
              bounds: Rect.fromLTWH(
                left ? 29.333 : size.width - 66.333,
                bottom ? size.height - 66.333 : 29.333,
                37,
                37,
              ),
              type: DisplayFeatureType.cutout,
              state: DisplayFeatureState.unknown,
            ),
            DisplayFeature(
              bounds: Rect.fromLTWH(
                left ? 0 : size.width - 84,
                bottom ? size.height - 82 : 0,
                84,
                bottom ? 82 : 174,
              ),
              type: DisplayFeatureType.cutout,
              state: DisplayFeatureState.unknown,
            ),
          ]
        : [],
  );
}

Widget _app(
  MediaQueryData data,
  Brightness brightness, {
  bool actualRow = false,
}) {
  final item = _reply('主评论测试内容', 100)
    ..count = Int64(1)
    ..replies.add(_reply('子评论测试内容', 101));
  final row = ReplyItemGrpc(replyItem: item, replyLevel: 1, upMid: Int64(1));
  return GetMaterialApp(
    theme: IosTheme.apply(ThemeData(brightness: brightness)),
    builder: (_, child) => MediaQuery(data: data, child: child!),
    home: Scaffold(
      body: Builder(
        builder: (context) => actualRow
            ? ListView(children: [row])
            : Center(
                child: TextButton(
                  onPressed: () => showReplyActionSheet(
                    context: context,
                    builder: (context) => row.morePanel(
                      context: context,
                      item: item,
                      onDelete: () {},
                      isSubReply: false,
                    ),
                  ),
                  child: const Text('评论菜单'),
                ),
              ),
      ),
    ),
  );
}

class _MemorySettings extends Fake implements Box<dynamic> {
  final _values = <dynamic, dynamic>{
    SettingBoxKey.buvid: 'test-reply-sheet-device',
  };

  @override
  dynamic get(dynamic key, {dynamic defaultValue}) =>
      _values[key] ?? defaultValue;

  @override
  Future<void> put(dynamic key, dynamic value) async {
    _values[key] = value;
  }
}

void main() {
  setUpAll(() {
    GStorage.setting = _MemorySettings();
    GStorage.localCache = _MemorySettings();
    GStorage.reply = null;
    expect(Accounts.main.mid, 0);
    Get.testMode = true;
  });
  tearDownAll(Get.reset);

  for (final (size, camera) in [
    (const Size(320, 568), null),
    (const Size(402, 874), null),
    (const Size(466, 678), 'top-right'),
    (const Size(466, 678), 'top-left'),
    (const Size(678, 466), 'bottom-right'),
    (const Size(678, 466), 'bottom-left'),
  ]) {
    for (final brightness in Brightness.values) {
      for (final scale in [1.0, 2.5]) {
        testWidgets(
          'centered single-handle reply menu: $size $camera $brightness $scale',
          (tester) async {
            await tester.binding.setSurfaceSize(size);
            addTearDown(() async {
              await tester.pumpWidget(const SizedBox.shrink());
              await tester.pump();
              await tester.binding.setSurfaceSize(null);
            });
            final data = _metrics(size, camera: camera, textScale: scale);
            await tester.pumpWidget(_app(data, brightness));
            await tester.tap(find.text('评论菜单'));
            await tester.pumpAndSettle();
            final sheet = tester.getRect(
              find.byKey(const ValueKey('reply-action-sheet')),
            );
            expect(sheet.center.dx, closeTo(size.width / 2, 0.01));
            expect(sheet.left, greaterThanOrEqualTo(12));
            expect(sheet.right, lessThanOrEqualTo(size.width - 12));
            expect(sheet.top, greaterThanOrEqualTo(data.viewPadding.top + 12));
            expect(sheet.bottom, lessThanOrEqualTo(size.height - 34));
            for (final feature in data.displayFeatures) {
              expect(sheet.overlaps(feature.bounds), isFalse);
            }
            expect(
              find.byKey(const ValueKey('reply-action-drag-handle')),
              findsOneWidget,
            );
            expect(
              tester
                  .widget<BottomSheet>(find.byType(BottomSheet))
                  .showDragHandle,
              isFalse,
            );
            await tester.ensureVisible(find.text('保存评论'));
            await tester.pumpAndSettle();
            expect(find.text('保存评论').hitTestable(), findsOneWidget);
            expect(tester.takeException(), isNull);
            await tester.tapAt(const Offset(5, 5));
            await tester.pumpAndSettle();
            expect(
              find.byKey(const ValueKey('reply-action-sheet')),
              findsNothing,
            );
          },
          variant: TargetPlatformVariant.only(TargetPlatform.iOS),
        );
      }
    }
  }

  for (final message in ['主评论测试内容', '子评论测试内容']) {
    testWidgets('real long press opens the shared menu: $message', (
      tester,
    ) async {
      const size = Size(466, 678);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.binding.setSurfaceSize(null);
      });
      await tester.pumpWidget(
        _app(
          _metrics(size, camera: 'top-right'),
          Brightness.dark,
          actualRow: true,
        ),
      );
      await tester.longPress(
        find.textContaining(message, findRichText: true).first,
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('reply-action-sheet')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('reply-action-drag-handle')),
        findsOneWidget,
      );
      await tester.tap(find.text('自由复制'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('reply-action-sheet')), findsNothing);
      expect(find.byType(SelectionArea), findsOneWidget);
      expect(find.text(message), findsWidgets);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  }

  testWidgets(
    'thread line collapses descendants and long press opens iOS actions',
    (
      tester,
    ) async {
      final root = _reply('根评论', 100);
      final rootId = root.id;
      final parent = _reply('父级楼中楼', 101)
        ..root = rootId
        ..parent = rootId
        ..dialog = Int64(101);
      final child = _reply('嵌套楼中楼', 102)
        ..root = rootId
        ..parent = parent.id
        ..dialog = parent.id;
      final controller = VideoReplyReplyController(
        hasRoot: true,
        id: null,
        oid: 1,
        rpid: rootId.toInt(),
        dialog: null,
        replyType: 1,
      )..loadingState.value = Success([child, parent]);
      final tree = ReplyTree.build(
        data: [parent, child],
        seen: HashSet.of([parent.id, child.id]),
        rootId: rootId,
        removed: {},
      );
      await tester.pumpWidget(
        GetMaterialApp(
          theme: IosTheme.apply(ThemeData.light()),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => ListView(
                children: [
                  for (var index = 0; index < tree.length; index++)
                    ReplyItemGrpc(
                      key: ValueKey(tree[index].reply.id),
                      replyItem: tree[index].reply,
                      replyLevel: 2,
                      needDivider: false,
                      getReplyChain: () =>
                          controller.getParentChain(tree[index].reply, root),
                      depth: tree[index].depth,
                      collapsed: tree[index].collapsed,
                      toggleCollapse: tree[index].isLeaf
                          ? null
                          : () => setState(() => tree.toggleCollapse(index)),
                    ),
                ],
              ),
            ),
          ),
        ),
      );

      final childMessage = find.textContaining('嵌套楼中楼', findRichText: true);
      expect(childMessage, findsOneWidget);
      final indent = find.byType(ReplyThreadedIndentBox).first;
      final lineRect = tester.getRect(indent);
      final lineX =
          RenderReplyThreadedIndentBox.indentWidthOf(tree[0].depth) -
          RenderReplyThreadedIndentBox.lineW / 2;
      await tester.tapAt(Offset(lineRect.left + lineX, lineRect.center.dy));
      await tester.pumpAndSettle();
      expect(childMessage, findsNothing);
      await tester.tap(find.text('展开 1 条评论'));
      await tester.pumpAndSettle();
      await tester.longPress(childMessage);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('reply-action-sheet')), findsOneWidget);
      final saveChain = find.text('保存评论链');
      expect(saveChain, findsOneWidget);
      await tester.ensureVisible(saveChain);
      await tester.tap(saveChain);
      await tester.pumpAndSettle();
      final panel = tester.widget<SavePanel>(find.byType(SavePanel));
      expect(panel.item, orderedEquals([root, parent, child]));
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('single handle still dismisses with a downward drag', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(_metrics(const Size(800, 600)), Brightness.light),
    );
    await tester.tap(find.text('评论菜单'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('reply-action-drag-handle')),
      const Offset(0, 400),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('reply-action-sheet')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
