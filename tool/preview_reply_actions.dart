// Offline visual fixture using the production comment menu. Release builds
// continue to use lib/main.dart; this preview never loads account or video data.
import 'dart:io';

import 'package:PiliPlus/common/widgets/liquid_glass/glass_platform.dart';
import 'package:PiliPlus/grpc/bilibili/main/community/reply/v1.pb.dart';
import 'package:PiliPlus/pages/video/reply/widgets/reply_action_sheet.dart';
import 'package:PiliPlus/pages/video/reply/widgets/reply_item_grpc.dart';
import 'package:PiliPlus/utils/ios/ios_theme.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hive_ce/hive.dart';
import 'package:material_ui/material_ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final temp = await Directory.systemTemp.createTemp('reply-menu-preview-');
  Hive.init(temp.path);
  GStorage.setting = await Hive.openBox('setting');
  GStorage.localCache = await Hive.openBox('localCache');
  GStorage.reply = null;
  runApp(
    GetMaterialApp(
      theme: IosTheme.apply(ThemeData(brightness: Brightness.dark)),
      builder: (_, child) => GlassPlatformScope(child: child!),
      home: const _Preview(),
    ),
  );
}

class _Preview extends StatefulWidget {
  const _Preview();
  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  final item = ReplyInfo(
    id: Int64(100),
    mid: Int64(99),
    member: Member(mid: Int64(99), name: '本地预览作者'),
    content: Content(message: '长按评论可以复制文字、保存评论或使用其他操作。'),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _show());
  }

  void _show() => showReplyActionSheet(
    context: context,
    builder: (context) =>
        ReplyItemGrpc(
          replyItem: item,
          replyLevel: 1,
          upMid: Int64(1),
        ).morePanel(
          context: context,
          item: item,
          onDelete: () {},
          isSubReply: false,
        ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        const AspectRatio(
          aspectRatio: 16 / 9,
          child: ColoredBox(
            color: Color(0xFF202B36),
            child: Center(
              child: Icon(Icons.play_circle_outline, size: 64),
            ),
          ),
        ),
        const ListTile(title: Text('评论 · 本地界面预览')),
        Expanded(
          child: ListView(
            children: [
              for (var i = 0; i < 5; i++)
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: const Text('长按评论打开操作菜单'),
                  subtitle: const Text('检查左右留白与单条拖动横杠'),
                  onLongPress: _show,
                  onTap: _show,
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
