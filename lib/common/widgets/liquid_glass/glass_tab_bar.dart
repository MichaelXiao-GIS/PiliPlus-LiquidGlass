import 'package:material_ui/material_ui.dart';

/// Secondary navigation uses a quiet segmented treatment, without stacked glass.
class GlassTabBar extends StatelessWidget {
  const GlassTabBar({
    super.key,
    required this.controller,
    required this.labels,
    this.onTap,
  });

  final TabController controller;
  final List<String> labels;
  final ValueChanged<int>? onTap;

  static double heightOf(BuildContext context) =>
      (MediaQuery.textScalerOf(context).scale(15) * 1.4 + 12).clamp(
        56.0,
        double.infinity,
      );

  @override
  Widget build(BuildContext context) {
    final colors = ColorScheme.of(context);
    return SizedBox(
      height: heightOf(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: TabBar(
          controller: controller,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          dividerHeight: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          labelPadding: const EdgeInsets.symmetric(horizontal: 17),
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorPadding: const EdgeInsets.symmetric(vertical: 2),
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: colors.onSurface.withValues(alpha: 0.07),
          ),
          splashBorderRadius: BorderRadius.circular(24),
          labelColor: colors.primary,
          unselectedLabelColor: colors.onSurfaceVariant,
          labelStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          tabs: [
            for (final label in labels)
              Tab(height: heightOf(context) - 8, text: label),
          ],
          onTap: onTap,
        ),
      ),
    );
  }
}
