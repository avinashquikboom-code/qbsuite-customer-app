import 'package:material_ui/material_ui.dart';

extension SizeExtension on BuildContext {
  /// Returns the screen width.
  double get screenWidth => MediaQuery.of(this).size.width;

  /// Returns the screen height.
  double get screenHeight => MediaQuery.of(this).size.height;

  /// Returns a width value that is a percentage of the screen width.
  /// Example: 0.5 => 50% of screen width.
  double w(double percent) => screenWidth * percent;

  /// Returns a height value that is a percentage of the screen height.
  double h(double percent) => screenHeight * percent;
}

/// Convenience functions for responsive sizing.
double responsiveWidth(BuildContext context, double factor) =>
    context.screenWidth * factor;

double responsiveHeight(BuildContext context, double factor) =>
    context.screenHeight * factor;

/// A widget that adds consistent responsive padding based on screen size.
class ResponsivePadding extends StatelessWidget {
  final Widget child;
  final double horizontalFactor;
  final double verticalFactor;

  const ResponsivePadding({
    super.key,
    required this.child,
    this.horizontalFactor = 0.04,
    this.verticalFactor = 0.02,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: context.w(horizontalFactor),
        vertical: context.h(verticalFactor),
      ),
      child: child,
    );
  }
}
