import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Fullscreen menus share one scrolling column, rather than toolbar alignment.
class PlayerMoreSheet extends StatelessWidget {
  const PlayerMoreSheet({
    super.key,
    required this.children,
    required this.onClose,
  });

  final List<Widget> children;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(12),
    child: Material(
      key: const ValueKey('player-more-panel'),
      color: const Color(0xFF1C1C1E),
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: ListTileTheme(
        data: const ListTileThemeData(
          dense: true,
          minTileHeight: 48,
          minLeadingWidth: 24,
          horizontalTitleGap: 12,
          contentPadding: EdgeInsets.symmetric(horizontal: 16),
          iconColor: Colors.white70,
          textColor: Colors.white,
          titleTextStyle: TextStyle(fontSize: 14, color: Colors.white),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '播放选项',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox.square(
                    dimension: 44,
                    child: IconButton(
                      tooltip: '关闭播放选项',
                      onPressed: onClose,
                      icon: const Icon(Icons.close, size: 22),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.white12),
            Expanded(
              child: ListView(
                key: const ValueKey('player-more-list'),
                padding: const EdgeInsets.only(bottom: 16),
                children: children,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class PlayerMenuSection extends StatelessWidget {
  const PlayerMenuSection({
    super.key,
    required this.title,
    required this.child,
  });
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 12, color: Colors.white60),
        ),
        const SizedBox(height: 8),
        child,
      ],
    ),
  );
}

/// A settings label and its existing popup/toggle, with room for larger text.
class PlayerMenuControl extends StatelessWidget {
  const PlayerMenuControl({
    super.key,
    required this.label,
    required this.control,
  });
  final String label;
  final Widget control;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final title = Text(label, style: const TextStyle(fontSize: 14));
      final value = SizedBox(
        height: math.max(44, MediaQuery.textScalerOf(context).scale(16) + 8),
        child: Center(child: control),
      );
      return Container(
        constraints: const BoxConstraints(minHeight: 52),
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.white10)),
        ),
        child:
            MediaQuery.textScalerOf(context).scale(14) > 24 ||
                constraints.maxWidth < 240
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [title, const SizedBox(height: 4), value],
              )
            : Row(
                children: [
                  Expanded(child: title),
                  const SizedBox(width: 12),
                  SizedBox(width: 112, child: value),
                ],
              ),
      );
    },
  );
}

/// Equal cells with captions; wraps as a group instead of squeezing icons.
class PlayerMenuActionGrid extends StatelessWidget {
  const PlayerMenuActionGrid({super.key, required this.actions});
  final List<(String, Widget)> actions;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final minWidth = math.max(
        48.0,
        MediaQuery.textScalerOf(context).scale(24) + 16,
      );
      final capacity = math.max(
        1,
        ((constraints.maxWidth + 8) / (minWidth + 8)).floor(),
      );
      final rows = (actions.length / capacity).ceil();
      final columns = (actions.length / math.max(1, rows)).ceil();
      final width =
          (constraints.maxWidth - 8 * (columns - 1)) / math.max(1, columns);
      return Wrap(
        spacing: 8,
        runSpacing: 12,
        children: [
          for (final (label, control) in actions)
            SizedBox(
              key: ValueKey('player-menu-action-$label'),
              width: width,
              child: Column(
                children: [
                  SizedBox(width: double.infinity, height: 44, child: control),
                  const SizedBox(height: 4),
                  ExcludeSemantics(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );
}
