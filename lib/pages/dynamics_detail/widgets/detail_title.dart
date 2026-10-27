import 'package:PiliPlus/common/widgets/liquid_glass/glass_platform.dart';
import 'package:material_ui/material_ui.dart';

/// Keep the navigation bar useful before the in-content author scrolls away.
class DynamicDetailTitle extends StatelessWidget {
  const DynamicDetailTitle({
    super.key,
    required this.showAuthor,
    required this.author,
  });

  final bool showAuthor;
  final Widget author;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: GlassCapabilities.duration(context, 200),
    layoutBuilder: (current, previous) => Stack(
      alignment: Alignment.center,
      children: [
        for (final child in previous)
          ExcludeSemantics(child: IgnorePointer(child: child)),
        ?current,
      ],
    ),
    child: showAuthor
        ? Padding(
            key: const ValueKey('author'),
            padding: const EdgeInsets.only(right: 12),
            child: author,
          )
        : const Text('动态详情', key: ValueKey('title')),
  );
}
