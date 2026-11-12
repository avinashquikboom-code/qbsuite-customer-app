import 'package:flutter/material.dart';

/// Shared responsive layout system for QB Suite apps.
/// Breakpoints are guidance only — all logic derives from the live
/// [MediaQuery] width, never from fixed device assumptions.
abstract final class AppBreakpoints {
  /// Compact phones ≈ 320–360 logical pixels.
  static const double compact = 360;

  /// Standard phones ≈ 361–400.
  static const double standard = 400;

  /// Large phones ≈ 401–480.
  static const double large = 480;

  /// Tablets start ≈ 600.
  static const double tablet = 600;

  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < compact;
  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tablet;
  static bool isLandscape(BuildContext context) =>
      MediaQuery.orientationOf(context) == Orientation.landscape;

  /// Symmetric horizontal padding that grows with the viewport.
  static double horizontalPadding(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < compact) return 12;
    if (width < standard) return 16;
    if (width < tablet) return 24;
    return 32;
  }

  /// Maximum readable content width for the current viewport.
  static double maxContentWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < compact) return width;
    if (width < tablet) return 480;
    if (width < 1024) return 560;
    if (width < 1440) return 720;
    return 900;
  }

  /// Column count for adaptive grids; callers may raise with [min].
  static int gridColumns(
    BuildContext context, {
    int min = 1,
    double minItemWidth = 240,
  }) {
    final width = MediaQuery.sizeOf(context).width;
    final byWidth = (width / minItemWidth).floor().clamp(1, 4);
    return byWidth < min ? min : byWidth;
  }
}

/// Centers content, clamps it to a readable width and applies responsive
/// horizontal padding. Safe to nest inside scroll views.
class ResponsiveContainer extends StatelessWidget {
  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
    this.center = true,
  });

  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry? padding;

  /// Center horizontally; set false for left-aligned document flows.
  final bool center;

  @override
  Widget build(BuildContext context) {
    final resolvedMax = maxWidth ?? AppBreakpoints.maxContentWidth(context);
    final resolvedPadding =
        padding ??
        EdgeInsets.symmetric(
          horizontal: AppBreakpoints.horizontalPadding(context),
        );
    return Padding(
      padding: resolvedPadding,
      child: center
          ? Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: resolvedMax),
                child: child,
              ),
            )
          : ConstrainedBox(
              constraints: BoxConstraints(maxWidth: resolvedMax),
              child: child,
            ),
    );
  }
}

/// Scaffold with SafeArea, keyboard-safe body and consistent app-wide padding.
class ResponsiveScaffold extends StatelessWidget {
  const ResponsiveScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.drawer,
    this.backgroundColor,
    this.resizeToAvoidBottomInset = true,
    this.scrollable = true,
    this.maxWidth,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final Widget? drawer;
  final Color? backgroundColor;
  final bool resizeToAvoidBottomInset;

  /// Wraps the body in a keyboard-aware [SingleChildScrollView].
  /// Set false when the body manages its own scrolling (ListView etc.).
  final bool scrollable;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    Widget content = ResponsiveContainer(maxWidth: maxWidth, child: body);
    if (scrollable) {
      content = LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.only(bottom: bottomInset + 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: content,
          ),
        ),
      );
    }
    return Scaffold(
      appBar: appBar,
      backgroundColor: backgroundColor,
      drawer: drawer,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: SafeArea(child: content),
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
    );
  }
}

/// Adaptive card grid that never overflows: items wrap at a computed width
/// instead of using fixed cross-axis counts on phones.
class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.children,
    this.minItemWidth = 240,
    this.spacing = 12,
    this.runSpacing = 12,
    this.maxColumns = 4,
  });

  final List<Widget> children;
  final double minItemWidth;
  final double spacing;
  final double runSpacing;
  final int maxColumns;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth.isFinite
          ? constraints.maxWidth
          : MediaQuery.sizeOf(context).width;
      final columns = (width / minItemWidth).floor().clamp(1, maxColumns);
      final itemWidth = (width - (columns - 1) * spacing) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: runSpacing,
        children: [
          for (final child in children)
            SizedBox(width: itemWidth, child: child),
        ],
      );
    },
  );
}

/// Consistent card styling with responsive padding.
class ResponsiveCard extends StatelessWidget {
  const ResponsiveCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding:
          padding ??
          EdgeInsets.all(AppBreakpoints.isCompact(context) ? 12 : 16),
      child: child,
    ),
  );
}

/// Full-width button with an accessible minimum tap target.
class ResponsiveButton extends StatelessWidget {
  const ResponsiveButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.outlined = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final bool loading;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final height = AppBreakpoints.isCompact(context) ? 46.0 : 50.0;
    final child = loading
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              semanticsLabel: 'Loading',
            ),
          )
        : Text(label, maxLines: 1, overflow: TextOverflow.ellipsis);
    if (outlined) {
      return SizedBox(
        width: double.infinity,
        height: height,
        child: icon == null
            ? OutlinedButton(onPressed: loading ? null : onPressed, child: child)
            : OutlinedButton.icon(
                onPressed: loading ? null : onPressed,
                icon: icon!,
                label: child,
              ),
      );
    }
    return SizedBox(
      width: double.infinity,
      height: height,
      child: icon == null
          ? FilledButton(onPressed: loading ? null : onPressed, child: child)
          : FilledButton.icon(
              onPressed: loading ? null : onPressed,
              icon: icon!,
              label: child,
            ),
    );
  }
}

/// Keyboard-safe, scrollable form host: fields never hide under the keyboard
/// and content stays centered on tablets.
class ResponsiveFormLayout extends StatelessWidget {
  const ResponsiveFormLayout({
    super.key,
    required this.children,
    this.maxWidth = 440,
    this.spacing = 16,
    this.padding,
  });

  final List<Widget> children;
  final double maxWidth;
  final double spacing;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final horizontal = AppBreakpoints.horizontalPadding(context);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding:
            padding?.add(EdgeInsets.only(bottom: bottomInset + 16)) ??
            EdgeInsets.fromLTRB(horizontal, 16, horizontal, bottomInset + 16),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              minHeight: (constraints.maxHeight - 32 - bottomInset).clamp(
                0.0,
                double.infinity,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) SizedBox(height: spacing),
                  children[i],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Scrollable, centered login host that stays usable in landscape and with
/// large text scaling. Renders [logo], [title], [subtitle] and the form card.
class ResponsiveLoginLayout extends StatelessWidget {
  const ResponsiveLoginLayout({
    super.key,
    required this.logo,
    required this.title,
    this.subtitle,
    required this.form,
    this.footer,
    this.cardMaxWidth = 440,
  });

  final Widget logo;
  final String title;
  final String? subtitle;
  final Widget form;
  final Widget? footer;
  final double cardMaxWidth;

  @override
  Widget build(BuildContext context) {
    final compact = AppBreakpoints.isCompact(context);
    final landscape = AppBreakpoints.isLandscape(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final horizontal = AppBreakpoints.horizontalPadding(context);
    final topPadding = landscape ? 8.0 : (compact ? 16.0 : 28.0);
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            horizontal,
            topPadding,
            horizontal,
            bottomInset + 16,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - topPadding - bottomInset - 16)
                  .clamp(0.0, double.infinity),
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: cardMaxWidth),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: logo),
                    SizedBox(height: compact ? 12 : 20),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    SizedBox(height: compact ? 16 : 24),
                    ResponsiveCard(child: form),
                    if (footer != null) ...[
                      const SizedBox(height: 16),
                      footer!,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Title/description header that wraps instead of clipping on small screens.
class ResponsivePageHeader extends StatelessWidget {
  const ResponsivePageHeader({
    super.key,
    required this.title,
    this.description,
    this.actions,
  });

  final String title;
  final String? description;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 12,
    runSpacing: 8,
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          if (description != null)
            Text(description!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      if (actions != null && actions!.isNotEmpty)
        Wrap(spacing: 8, runSpacing: 8, children: actions!),
    ],
  );
}

/// NavigationBar with safe-area positioning and destination sizing that stays
/// legible with large text scaling.
class ResponsiveBottomNavigation extends StatelessWidget {
  const ResponsiveBottomNavigation({
    super.key,
    required this.index,
    required this.onSelected,
    required this.destinations,
  });

  final int index;
  final ValueChanged<int> onSelected;
  final List<NavigationDestination> destinations;

  @override
  Widget build(BuildContext context) => NavigationBar(
    selectedIndex: index.clamp(0, destinations.length - 1),
    onDestinationSelected: onSelected,
    labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    destinations: destinations,
  );
}
