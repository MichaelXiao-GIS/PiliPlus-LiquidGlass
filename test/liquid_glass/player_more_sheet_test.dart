import 'package:PiliPlus/common/widgets/fractionally_sized_box.dart';
import 'package:PiliPlus/pages/video/introduction/ugc/widgets/action_item.dart';
import 'package:PiliPlus/plugin/pl_player/widgets/player_more_sheet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const labels = ['点赞', '投币', '收藏', '缓存', '分享'];

void main() {
  for (final size in [
    const Size(874, 402),
    const Size(678, 466),
    const Size(466, 678),
  ]) {
    for (final scale in [1.0, 2.0, 3.0]) {
      testWidgets('player menu remains usable at $size / ${scale}x', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        var closed = false;
        var taps = 0;
        var starts = 0;
        var ends = 0;
        var longPresses = 0;
        var fit = '自动';
        final portrait = size.height > size.width;
        final safe = EdgeInsets.only(
          right: size.width == 678 ? 92 : 0,
          bottom: 21,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                padding: safe,
                viewPadding: safe,
                textScaler: TextScaler.linear(scale),
              ),
              child: SafeArea(
                child: CustomFractionallySizedBox(
                  maxWidth: 512,
                  widthFactor: portrait ? 1 : 0.5,
                  heightFactor: portrait ? 0.7 : 1,
                  alignment: portrait
                      ? Alignment.bottomCenter
                      : Alignment.centerRight,
                  child: StatefulBuilder(
                    builder: (context, setState) => PlayerMoreSheet(
                      onClose: () => closed = true,
                      children: [
                        PlayerMenuSection(
                          title: '播放',
                          child: PlayerMenuControl(
                            label: '画面比例',
                            control: PopupMenuButton<String>(
                              key: const ValueKey('fit-popup'),
                              initialValue: fit,
                              onSelected: (value) =>
                                  setState(() => fit = value),
                              itemBuilder: (_) => [
                                for (final value in ['自动', '16:9'])
                                  PopupMenuItem(
                                    value: value,
                                    child: Text(value),
                                  ),
                              ],
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(
                                  fit,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ),
                          ),
                        ),
                        PlayerMenuSection(
                          title: '互动',
                          child: PlayerMenuActionGrid(
                            actions: [
                              for (final label in labels)
                                (
                                  label,
                                  ActionItem(
                                    key: ValueKey('action-$label'),
                                    expand: false,
                                    icon: const Icon(Icons.favorite),
                                    semanticsLabel: label,
                                    onTap: () => taps++,
                                    onLongPress: () => longPresses++,
                                    onStartTriple: label == '点赞'
                                        ? () => starts++
                                        : null,
                                    onCancelTriple: label == '点赞'
                                        ? ([bool _ = false]) => ends++
                                        : null,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        for (final label in [
                          '返回主页',
                          '截图',
                          '画中画',
                          '稍后再看',
                          '选择画质',
                          '弹幕设置',
                          '字幕设置',
                          '播放信息',
                        ])
                          ListTile(
                            title: Text(label),
                            leading: const Icon(Icons.settings),
                            onTap: () => taps++,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        final panel = tester.getRect(
          find.byKey(const ValueKey('player-more-panel')),
        );
        expect(panel.right, lessThanOrEqualTo(size.width - safe.right));
        final popup = find.byKey(const ValueKey('fit-popup'));
        await tester.ensureVisible(popup);
        await tester.tap(popup);
        await tester.pumpAndSettle();
        await tester.tap(find.text('16:9').last);
        await tester.pumpAndSettle();
        expect(fit, '16:9');
        // Captions must remain centered on equal-width, 44pt-high controls.
        final widths = <double>[];
        for (final label in labels) {
          final action = find.byKey(ValueKey('action-$label'));
          await tester.ensureVisible(action);
          await tester.pumpAndSettle();
          final rect = tester.getRect(action);
          widths.add(rect.width);
          expect(rect.height, greaterThanOrEqualTo(44));
          expect(rect.width, greaterThanOrEqualTo(44));
          expect(rect.left, greaterThanOrEqualTo(panel.left));
          expect(rect.right, lessThanOrEqualTo(panel.right));
          expect(
            tester.getCenter(find.text(label)).dx,
            closeTo(rect.center.dx, 0.01),
          );
          // Tap near the edge, beyond the original 28pt icon bounds.
          await tester.tapAt(Offset(rect.left + 3, rect.center.dy));
          await tester.pump();
        }
        expect(widths.every((w) => (w - widths.first).abs() < 0.01), isTrue);
        expect(taps, 4);
        expect(starts, 1);
        expect(ends, 1);
        await tester.ensureVisible(find.byKey(const ValueKey('action-收藏')));
        await tester.pumpAndSettle();
        await tester.longPress(find.byKey(const ValueKey('action-收藏')));
        expect(longPresses, 1);
        await tester.scrollUntilVisible(
          find.text('字幕设置'),
          100,
          scrollable: find.descendant(
            of: find.byKey(const ValueKey('player-more-list')),
            matching: find.byType(Scrollable),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('字幕设置'));
        await tester.pump();
        expect(taps, 5);
        await tester.tap(find.byTooltip('关闭播放选项'));
        expect(closed, isTrue);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
