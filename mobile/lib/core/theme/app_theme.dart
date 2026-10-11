import 'package:flutter/material.dart';

abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

abstract final class AppRadii {
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
}

abstract final class AppColors {
  static const accentLight = Color(0xFF1B6B53);
  static const accentDark = Color(0xFF7FD3B4);
}

/// Minimum interactive size required by Material and WCAG target-size guidance.
const minTouchTarget = Size(48, 48);

ThemeData buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: AppColors.accentLight,
        brightness: brightness,
        dynamicSchemeVariant: DynamicSchemeVariant.neutral,
      ).copyWith(
        primary: isDark ? AppColors.accentDark : AppColors.accentLight,
        onPrimary: isDark ? const Color(0xFF00382A) : Colors.white,
        surface: isDark ? const Color(0xFF121415) : Colors.white,
        onSurface: isDark ? const Color(0xFFE3E5E6) : const Color(0xFF1A1C1E),
        onSurfaceVariant: isDark
            ? const Color(0xFFBFC5C8)
            : const Color(0xFF4A5054),
        surfaceContainerLowest: isDark ? const Color(0xFF0D0F10) : Colors.white,
        surfaceContainerLow: isDark
            ? const Color(0xFF1A1C1D)
            : const Color(0xFFF6F7F7),
        surfaceContainer: isDark
            ? const Color(0xFF1E2122)
            : const Color(0xFFF0F2F2),
        surfaceContainerHigh: isDark
            ? const Color(0xFF282B2C)
            : const Color(0xFFE9ECEC),
        outline: isDark ? const Color(0xFF8A9194) : const Color(0xFF74797D),
        outlineVariant: isDark
            ? const Color(0xFF3F4446)
            : const Color(0xFFD5DADB),
      );

  final shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadii.md),
  );
  final base = ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    brightness: brightness,
  );

  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: minTouchTarget, shape: shape),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: minTouchTarget,
        shape: shape,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: minTouchTarget, shape: shape),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        borderSide: BorderSide(color: scheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    listTileTheme: ListTileThemeData(
      minVerticalPadding: AppSpacing.sm,
      shape: shape,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      space: AppSpacing.lg,
    ),
  );
}
