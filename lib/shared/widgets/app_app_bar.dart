import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';

/// Global standardized AppBar for the QuikBoom application.
///
/// Ensures unified typography, height, colors, actions, and
/// platform-independent back navigation across Android, iOS, Web, and Desktop.
class AppAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? titleWidget;
  final bool? showBackButton;
  final bool showDrawerButton;
  final bool automaticallyImplyLeading;
  final List<Widget>? actions;
  final VoidCallback? onBack;
  final PreferredSizeWidget? bottom;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? elevation;

  final Widget? leading;
  final bool? centerTitle;

  const AppAppBar({
    super.key,
    required this.title,
    this.titleWidget,
    this.leading,
    this.centerTitle,
    this.showBackButton,
    this.showDrawerButton = false,
    this.automaticallyImplyLeading = true,
    this.actions,
    this.onBack,
    this.bottom,
    this.backgroundColor,
    this.foregroundColor,
    this.elevation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appBarTheme = theme.appBarTheme;

    final effectiveBg =
        backgroundColor ??
        appBarTheme.backgroundColor ??
        theme.colorScheme.surface;
    final effectiveFg =
        foregroundColor ??
        appBarTheme.foregroundColor ??
        theme.colorScheme.onSurface;
    final effectiveElevation = elevation ?? appBarTheme.elevation ?? 0.0;
    final effectiveCenterTitle =
        centerTitle ?? appBarTheme.centerTitle ?? false;

    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final shouldShowBack =
        showBackButton ?? (automaticallyImplyLeading && canPop);

    Widget? leadingWidget = leading;
    if (leadingWidget == null && shouldShowBack) {
      leadingWidget = BackButton(
        color: effectiveFg,
        onPressed: () {
          if (onBack != null) {
            onBack!();
          } else if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        },
      );
    }

    final List<Widget> effectiveActions = [
      ...?actions,
      if (showDrawerButton)
        Builder(
          builder: (ctx) => Tooltip(
            message: 'Open Menu',
            child: IconButton(
              icon: const Icon(Remix.menu_2_line),
              iconSize: 22,
              color: effectiveFg,
              padding: const EdgeInsets.all(12),
              splashRadius: 22,
              onPressed: () {
                final rootScaffold = ctx
                    .findRootAncestorStateOfType<ScaffoldState>();
                if (rootScaffold != null && rootScaffold.hasDrawer) {
                  rootScaffold.openDrawer();
                  return;
                }
                Scaffold.maybeOf(ctx)?.openDrawer();
              },
            ),
          ),
        ),
      const SizedBox(width: 8),
    ];

    return AppBar(
      automaticallyImplyLeading: false,
      elevation: effectiveElevation,
      scrolledUnderElevation: 0,
      backgroundColor: effectiveBg,
      foregroundColor: effectiveFg,
      centerTitle: effectiveCenterTitle,
      leading: leadingWidget,
      title:
          titleWidget ??
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                appBarTheme.titleTextStyle ??
                GoogleFonts.outfit(
                  color: effectiveFg,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
          ),
      actions: (actions != null || showDrawerButton) ? effectiveActions : null,
      bottom: bottom,
    );
  }

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0.0));
}
