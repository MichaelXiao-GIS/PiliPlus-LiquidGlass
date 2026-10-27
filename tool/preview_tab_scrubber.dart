// Offline native gesture preview:
// flutter run -t tool/preview_tab_scrubber.dart
import 'package:PiliPlus/common/widgets/liquid_glass/glass_navigation_bar.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_platform.dart';
import 'package:PiliPlus/utils/ios/ios_theme.dart';
import 'package:material_ui/material_ui.dart';

void main() => runApp(const _Preview());

class _Preview extends StatefulWidget {
  const _Preview();
  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  int selected = 0;
  int changes = 0;
  bool compact = false;
  bool dark = false;
  bool rtl = false;

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: IosTheme.apply(
      ThemeData(
        brightness: dark ? Brightness.dark : Brightness.light,
        colorSchemeSeed: Colors.blue,
      ),
    ),
    builder: (_, child) => GlassPlatformScope(
      child: Directionality(
        textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
        child: child!,
      ),
    ),
    home: Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: ListView.builder(
              itemCount: 30,
              padding: const EdgeInsets.only(top: 300, bottom: 120),
              itemBuilder: (_, index) => Container(
                height: 110,
                color: [
                  Colors.pink.shade200,
                  Colors.teal.shade200,
                  Colors.blue.shade200,
                ][index % 3],
                padding: const EdgeInsets.all(20),
                child: Text('测试内容 ${index + 1}'),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('拖动底栏，松手后切换', style: TextStyle(fontSize: 23)),
                Text('当前：${['首页', '动态', '我的'][selected]}；切换：$changes 次'),
                SwitchListTile(
                  title: const Text('仅图标'),
                  value: compact,
                  onChanged: (value) => setState(() => compact = value),
                ),
                SwitchListTile(
                  title: const Text('深色'),
                  value: dark,
                  onChanged: (value) => setState(() => dark = value),
                ),
                SwitchListTile(
                  title: const Text('从右到左'),
                  value: rtl,
                  onChanged: (value) => setState(() => rtl = value),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: GlassNavigationBar(
              compact: compact,
              destinations: const [
                GlassDestination(
                  label: '首页',
                  symbol: 'house',
                  icon: Icon(Icons.home_outlined),
                ),
                GlassDestination(
                  label: '动态',
                  symbol: 'rectangle.stack',
                  icon: Icon(Icons.dynamic_feed),
                  badge: '3',
                ),
                GlassDestination(
                  label: '我的',
                  symbol: 'person.crop.circle',
                  icon: Icon(Icons.person_outline),
                ),
              ],
              selectedIndex: selected,
              onSelected: (index) => setState(() {
                selected = index;
                changes++;
              }),
            ),
          ),
        ],
      ),
    ),
  );
}
