// Offline UIKit glass-compositor fixture. Does not initialize app data/network.
// flutter run -t tool/preview_navigation_occlusion.dart -d <simulator>
// Add --dart-define=NAV_OCCLUSION_HORIZONTAL=true for the bottom navigation.
// Add --dart-define=NAV_OCCLUSION_AUTOSTART=true to run without pressing a button.
// Progress is the actual incoming PageRoute controller value (1 = fully open).
// ignore_for_file: invalid_use_of_protected_member
import 'dart:async';

import 'package:PiliPlus/common/widgets/liquid_glass/glass_navigation_bar.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_platform.dart';
import 'package:PiliPlus/utils/ios/ios_theme.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

const _horizontal = bool.fromEnvironment('NAV_OCCLUSION_HORIZONTAL');
const _autostart = bool.fromEnvironment('NAV_OCCLUSION_AUTOSTART');
const _destinations = [
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
];

void main() => runApp(
  GetMaterialApp(
    debugShowCheckedModeBanner: false,
    defaultTransition: Transition.native,
    theme: IosTheme.apply(ThemeData(platform: TargetPlatform.iOS)),
    builder: (_, child) => GlassPlatformScope(child: child!),
    getPages: [
      GetPage(name: '/', page: () => const _Home()),
      // This project's GetPageRoute is opaque by default, as in the video page.
      GetPage(name: '/detail', page: () => const _Detail()),
    ],
  ),
);

void _log(String phase) => debugPrint('[nav-occlusion] $phase');

class _Home extends StatefulWidget {
  const _Home();

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  Timer? _autoTimer;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _log('ready axis=${_horizontal ? 'horizontal' : 'vertical'}');
      if (_autostart) _autoTimer = Timer(const Duration(seconds: 2), _open);
    });
  }

  Future<void> _open() async {
    if (!mounted || _running) return;
    setState(() => _running = true);
    _log('start nativeGlass=${GlassCapabilities.of(context).nativeGlass}');
    await Get.toNamed<void>('/detail');
    if (!mounted) return;
    setState(() => _running = false);
    _log('home restored');
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      fit: StackFit.expand,
      children: [
        ListView.builder(
          padding: EdgeInsets.zero,
          itemExtent: 48,
          itemCount: 40,
          itemBuilder: (_, index) => ColoredBox(
            color: const [
              Color(0xFF20B5D8),
              Color(0xFFEC779F),
              Color(0xFFF2C95E),
              Color(0xFF72CEA5),
            ][index % 4],
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'HOME ${index.toString().padLeft(2, '0')}  ━━━  玻璃背景条纹  ━━━',
                maxLines: 1,
                style: const TextStyle(color: Colors.black87, fontSize: 18),
              ),
            ),
          ),
        ),
        Positioned(
          left: 20,
          top: MediaQuery.paddingOf(context).top + 20,
          child: FilledButton(
            onPressed: _running ? null : _open,
            child: const Text('开始导航遮挡检查'),
          ),
        ),
        if (_horizontal)
          Positioned(
            left: 0,
            right: 0,
            bottom: 8,
            child: GlassNavigationBar(
              destinations: _destinations,
              selectedIndex: 0,
              compact: true,
              onSelected: (_) {},
            ),
          )
        else
          Positioned(
            right: 12,
            bottom: 60,
            width: 60,
            height: 156,
            child: GlassNavigationBar(
              axis: Axis.vertical,
              destinations: _destinations,
              selectedIndex: 0,
              compact: true,
              onSelected: (_) {},
            ),
          ),
      ],
    ),
  );
}

class _Detail extends StatefulWidget {
  const _Detail();

  @override
  State<_Detail> createState() => _DetailState();
}

class _DetailState extends State<_Detail> {
  Timer? _timer;
  Completer<bool>? _waiting;
  NavigatorState? _navigator;
  bool _gesture = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<bool> _wait(int seconds) {
    if (!mounted) return Future.value(false);
    final waiting = _waiting = Completer<bool>();
    _timer = Timer(Duration(seconds: seconds), () {
      if (identical(_waiting, waiting)) _waiting = null;
      waiting.complete(mounted);
    });
    return waiting.future;
  }

  Future<bool> _hold(
    AnimationController controller,
    double progress,
    String phase,
  ) async {
    if (!mounted) return false;
    controller
      ..stop()
      ..value = progress;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return false;
    _log('$phase progress=$progress hold=3s');
    return _wait(3);
  }

  void _startGesture() {
    _navigator!.didStartUserGesture();
    _gesture = true;
  }

  void _stopGesture() {
    if (!_gesture) return;
    _gesture = false;
    if (_navigator?.mounted == true) _navigator!.didStopUserGesture();
  }

  Future<void> _run() async {
    if (!mounted) return;
    final route = ModalRoute.of(context)! as PageRoute;
    final controller = route.controller!;
    _navigator = route.navigator;
    _log('route=${route.runtimeType} opaque=${route.opaque}');
    try {
      for (final progress in [0.25, 0.5, 0.75]) {
        if (!await _hold(controller, progress, 'push')) return;
      }
      await controller
          .animateTo(1, duration: const Duration(milliseconds: 350))
          .orCancel;
      _log('push complete hold=2s');
      if (!await _wait(2)) return;

      _startGesture();
      if (!await _hold(controller, 0.65, 'pop before cancellation')) return;
      await controller
          .animateTo(1, duration: const Duration(milliseconds: 350))
          .orCancel;
      _stopGesture();
      _log('pop cancelled hold=2s');
      if (!await _wait(2)) return;

      _startGesture();
      if (!await _hold(controller, 0.65, 'pop before completion')) return;
      if (!await _hold(controller, 0.05, 'pop nearly revealed')) return;
      _log('pop completing');
      _navigator!.pop();
      await controller
          .animateBack(0, duration: const Duration(milliseconds: 500))
          .orCancel;
      _log('pop complete');
    } on TickerCanceled {
      // A completed or manually interrupted pop can dispose the route ticker.
    } finally {
      _stopGesture();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _waiting?.complete(false);
    _waiting = null;
    _stopGesture();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    child: ListView.builder(
      padding: EdgeInsets.zero,
      itemExtent: 48,
      itemCount: 40,
      itemBuilder: (_, index) => DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFD9D9E0))),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'DETAIL ${index.toString().padLeft(2, '0')}  白色页面应完整盖住后方导航条',
              maxLines: 1,
              style: const TextStyle(color: Color(0xFF1C1C1E), fontSize: 17),
            ),
          ),
        ),
      ),
    ),
  );
}
