# qbsuite-customer-app

## Unified QB Suite green theme

`lib/theme/app_colors.dart` and `app_theme.dart` match the shared `../design-system/colors.json` specification. This checkout contains no Flutter project, screens, API clients, or pubspec.yaml yet, so these configurations are prepared for integration, not a runnable mobile app.

When app source is available, apply `AppTheme.light` to `MaterialApp`, bundle Inter fonts at weights 400/500/600/700 in pubspec.yaml, and use the `remixicon` package for UI icons. Theme configuration uses Flutter Material widgets but does not add Material Icons. Primary buttons (including Save Settings, login and punch actions), focused inputs, navigation, tabs, progress and selection controls inherit the shared colors. Use `AppColors.success` for custom success indicators. Keep padding 16px horizontally/12px vertically and button radius 8px.
