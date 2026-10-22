import 'package:material_ui/material_ui.dart';

/// Neutral content surfaces keep Bilibili's accent on actions and selection.
abstract final class IosTheme {
  static ThemeData apply(ThemeData theme) {
    final dark = theme.brightness == Brightness.dark;
    final colors = theme.colorScheme.copyWith(
      surface: dark ? const Color(0xFF1C1C1E) : Colors.white,
      onSurface: dark ? const Color(0xFFF5F5F7) : const Color(0xFF1C1C1E),
      onSurfaceVariant: dark
          ? const Color(0xFFAEAEB2)
          : const Color(0xFF636366),
      surfaceContainer: dark ? const Color(0xFF1C1C1E) : Colors.white,
      surfaceContainerLow: dark
          ? const Color(0xFF161618)
          : const Color(0xFFF2F2F7),
      surfaceContainerHigh: dark
          ? const Color(0xFF2C2C2E)
          : const Color(0xFFE5E5EA),
      surfaceContainerHighest: dark
          ? const Color(0xFF3A3A3C)
          : const Color(0xFFD1D1D6),
    );
    return theme.copyWith(
      colorScheme: colors,
      scaffoldBackgroundColor: dark ? Colors.black : const Color(0xFFF7F7FA),
      canvasColor: dark ? Colors.black : const Color(0xFFF7F7FA),
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: theme.textTheme.titleMedium?.copyWith(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: colors.onSurface,
        ),
      ),
      cardTheme: theme.cardTheme.copyWith(
        color: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      bottomSheetTheme: theme.bottomSheetTheme.copyWith(
        backgroundColor: colors.surface,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
      ),
      dialogTheme: theme.dialogTheme.copyWith(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44),
          foregroundColor: colors.onSurface,
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
      navigationRailTheme: theme.navigationRailTheme.copyWith(
        backgroundColor: Colors.transparent,
        indicatorColor: colors.onSurface.withValues(alpha: 0.08),
        selectedIconTheme: IconThemeData(color: colors.primary),
      ),
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        hintStyle: TextStyle(color: colors.onSurfaceVariant),
      ),
    );
  }
}
