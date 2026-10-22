import 'package:PiliPlus/pages/common/multi_select/base.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_page_bar.dart';
import 'package:PiliPlus/common/widgets/liquid_glass/glass_platform.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class MultiSelectAppBarWidget extends StatelessWidget
    implements PreferredSizeWidget {
  final MultiSelectBase ctr;
  final bool? visible;
  final AppBar child;
  final List<Widget>? actions;

  const MultiSelectAppBarWidget({
    super.key,
    required this.ctr,
    this.visible,
    this.actions,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (visible ?? ctr.enableMultiSelect.value) {
      final style = TextButton.styleFrom(visualDensity: VisualDensity.compact);
      final colorScheme = ColorScheme.of(context);
      return _wrap(
        AppBar(
          bottom: child.bottom,
          leading: IconButton(
            tooltip: '取消',
            onPressed: ctr.handleSelect,
            icon: const Icon(Icons.close_outlined),
          ),
          title: Obx(() => Text('已选: ${ctr.checkedCount}')),
          actions: [
            TextButton(
              style: style,
              onPressed: () => ctr.handleSelect(checked: true),
              child: const Text('全选'),
            ),
            ...?actions,
            TextButton(
              style: style,
              onPressed: () {
                if (ctr.checkedCount == 0) return;
                ctr.onRemove();
              },
              child: Text(
                '移除',
                style: TextStyle(color: colorScheme.error),
              ),
            ),
            const SizedBox(width: 6),
          ],
        ),
      );
    }
    return _wrap(child);
  }

  Widget _wrap(AppBar bar) =>
      GlassCapabilities.isIOS ? GlassPageBar(child: bar) : bar;

  @override
  Size get preferredSize => Size.fromHeight(
    child.preferredSize.height + (GlassCapabilities.isIOS ? 14 : 0),
  );
}
