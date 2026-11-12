import 'dart:ui' as ui;

import 'package:flutter/material.dart';

abstract final class AppTypography {
  static const regular = TextStyle(
    fontFamily: 'Inter',
    fontWeight: FontWeight.w400,
  );
  static const medium = TextStyle(
    fontFamily: 'Inter',
    fontWeight: FontWeight.w500,
  );
  static const semiBold = TextStyle(
    fontFamily: 'Inter',
    fontWeight: FontWeight.w600,
  );
  static const bold = TextStyle(
    fontFamily: 'Inter',
    fontWeight: FontWeight.w700,
  );
  static TextStyle inter({
    TextStyle? textStyle,
    Color? color,
    Color? backgroundColor,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    double? height,
    Locale? locale,
    Paint? foreground,
    Paint? background,
    List<ui.Shadow>? shadows,
    List<ui.FontFeature>? fontFeatures,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
  }) => (textStyle ?? const TextStyle()).copyWith(
    fontFamily: 'Inter',
    color: color,
    backgroundColor: backgroundColor,
    fontSize: fontSize,
    fontWeight: fontWeight,
    fontStyle: fontStyle,
    letterSpacing: letterSpacing,
    wordSpacing: wordSpacing,
    textBaseline: textBaseline,
    height: height,
    locale: locale,
    foreground: foreground,
    background: background,
    shadows: shadows,
    fontFeatures: fontFeatures,
    decoration: decoration,
    decorationColor: decorationColor,
    decorationStyle: decorationStyle,
    decorationThickness: decorationThickness,
  );
  static TextTheme interTextTheme([TextTheme? theme]) =>
      (theme ?? ThemeData.light().textTheme).apply(fontFamily: 'Inter');
}
