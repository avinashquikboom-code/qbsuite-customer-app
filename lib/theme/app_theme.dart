import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Apply using MaterialApp(theme: AppTheme.light).
/// Register Inter 400/500/600/700 in the application's pubspec.yaml.
/// UI icons must come from remixicon; do not use Icons.* glyphs.
abstract final class AppTheme {
  static const buttonRadius = 8.0;
  static const controlPadding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 12,
  );

  static ThemeData get light {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.primary,
          onPrimary: AppColors.textPrimary,
          primaryContainer: AppColors.lightPrimary,
          onPrimaryContainer: AppColors.textPrimary,
          secondary: AppColors.primary,
          onSecondary: AppColors.textPrimary,
          secondaryContainer: AppColors.lightPrimary,
          onSecondaryContainer: AppColors.textPrimary,
          tertiary: AppColors.darkPrimary,
          onTertiary: AppColors.surface,
          surface: AppColors.surface,
          onSurface: AppColors.textPrimary,
          onSurfaceVariant: AppColors.textSecondary,
          outline: AppColors.border,
          outlineVariant: AppColors.border,
          surfaceTint: Colors.transparent,
          error: AppColors.danger,
        );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(buttonRadius),
    );
    final buttonStyle = ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return AppColors.border;
        if (states.contains(WidgetState.pressed) ||
            states.contains(WidgetState.hovered))
          return AppColors.darkPrimary;
        return AppColors.primary;
      }),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? AppColors.textSecondary
            : AppColors.textPrimary,
      ),
      padding: const WidgetStatePropertyAll(controlPadding),
      shape: WidgetStatePropertyAll(shape),
      minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
      ),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Inter',
      textTheme: const TextTheme(
        bodyMedium: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w400,
        ),
        bodySmall: TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w400,
        ),
        labelLarge: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        headlineSmall: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: buttonStyle),
      filledButtonTheme: FilledButtonThemeData(style: buttonStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.darkPrimary,
          side: const BorderSide(color: AppColors.border),
          shape: shape,
          padding: controlPadding,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.darkPrimary,
          shape: shape,
          padding: controlPadding,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: shape,
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: controlPadding,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primary
              : Colors.transparent,
        ),
        checkColor: const WidgetStatePropertyAll(AppColors.textPrimary),
        side: const BorderSide(color: AppColors.border),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.textSecondary,
        ),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.border,
        ),
        thumbColor: const WidgetStatePropertyAll(AppColors.surface),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.lightPrimary,
        circularTrackColor: AppColors.lightPrimary,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.darkPrimary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.primary,
        labelStyle: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.lightPrimary,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.textSecondary,
          ),
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.lightPrimary,
        selectedIconTheme: IconThemeData(color: AppColors.primary),
        unselectedIconTheme: IconThemeData(color: AppColors.textSecondary),
        selectedLabelTextStyle: TextStyle(
          color: AppColors.darkPrimary,
          fontFamily: 'Inter',
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
      ),
      listTileTheme: const ListTileThemeData(
        selectedColor: AppColors.darkPrimary,
        selectedTileColor: AppColors.lightPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}
