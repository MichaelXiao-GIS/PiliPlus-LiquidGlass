// Offline native-compositor regression fixture. Run on an iOS simulator with:
// flutter run -t tool/preview_dynamic_detail.dart
// The pause control holds a real route controller mid-pop for screenshots.
// ignore_for_file: invalid_use_of_protected_member
import 'dart:async';

import 'package:PiliPlus/common/widgets/liquid_glass/glass_navigation_bar.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_platform.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/pages/dynamics_detail/widgets/detail_title.dart';
import 'package:PiliPlus/utils/ios/ios_theme.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

void main() => runApp(
  GetMaterialApp(
    defaultTransition: Transition.native,
    theme: IosTheme.apply(ThemeData()),
    darkTheme: IosTheme.apply(ThemeData(brightness: Brightness.dark)),
    builder: (_, child) => GlassPlatformScope(child: child!),
    getPages: [
      GetPage(name: '/', page: () => const _Preview(detail: false)),
      GetPage(name: '/detail', page: () => const _Preview(detail: true)),
    ],
  ),
);

class _Preview extends StatefulWidget {
  const _Preview({required this.detail});
  final bool detail;
  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  final scroll = ScrollController();
  bool showAuthor = false;
  bool paused = false;
  Timer? resumeTimer;

  @override
  void initState() {
    super.initState();
    scroll.addListener(() {
      final next = scroll.offset > 55;
      if (next != showAuthor) setState(() => showAuthor = next);
    });
  }

  @override
  void dispose() {
    resumeTimer?.cancel();
    scroll.dispose();
    super.dispose();
  }

  void pause() {
    final route = ModalRoute.of(context)! as PageRoute;
    if (paused) {
      route.controller!.forward().whenComplete(
        route.navigator!.didStopUserGesture,
      );
    } else {
      route.navigator!.didStartUserGesture();
      route.controller!.value = 0.65;
      // Route input is disabled at intermediate animation values, so restore
      // automatically instead of relying on a button inside the moving page.
      resumeTimer = Timer(const Duration(seconds: 8), () {
        if (mounted) pause();
      });
    }
    setState(() => paused = !paused);
  }

  @override
  Widget build(BuildContext context) => SimpleScaffold(
    appBar: AppBar(
      title: widget.detail
          ? DynamicDetailTitle(
              showAuthor: showAuthor,
              author: const Row(
                children: [
                  CircleAvatar(child: Icon(Icons.person)),
                  SizedBox(width: 10),
                  Text('测试作者'),
                ],
              ),
            )
          : const Text('动态列表'),
    ),
    body: ListView.builder(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 120),
      itemCount: 30,
      itemBuilder: (context, i) => Container(
        color: i.isEven
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surfaceContainerHigh,
        padding: const EdgeInsets.all(12),
        child: Text(
          '第 $i 段：动态正文、图片及评论在滑动返回时应连续显示，不能出现遮挡。',
          style: const TextStyle(fontSize: 18),
        ),
      ),
    ),
    fab: widget.detail
        ? SafeArea(
            child: SizedBox(
              width: MediaQuery.sizeOf(context).width,
              child: Align(
                alignment: Alignment.centerLeft,
                heightFactor: 1,
                child: TextButton(
                  onPressed: pause,
                  child: Text(paused ? '取消返回' : '暂停返回动画'),
                ),
              ),
            ),
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () => Get.toNamed('/detail'),
                child: const Text('打开动态详情'),
              ),
              GlassNavigationBar(
                destinations: const [
                  GlassDestination(
                    label: '首页',
                    symbol: 'house',
                    icon: Icon(Icons.home),
                  ),
                  GlassDestination(
                    label: '动态',
                    symbol: 'rectangle.stack',
                    icon: Icon(Icons.dynamic_feed),
                  ),
                  GlassDestination(
                    label: '我的',
                    symbol: 'person',
                    icon: Icon(Icons.person),
                  ),
                ],
                selectedIndex: 1,
                onSelected: (_) {},
              ),
            ],
          ),
  );
}
