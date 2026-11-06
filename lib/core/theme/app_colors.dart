import 'package:flutter/material.dart';

/// QB Suite brand specification: design-system/colors.json.
/// Identical in CRM, Customer and Production. Do not create module palettes.
abstract final class AppColors {
  static const primary = Color(0xFF5EC269);
  static const darkPrimary = Color(0xFF43A854);
  static const lightPrimary = Color(0xFFE8F5E9);
  static const background = Color(0xFFF8FAFC);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF1E293B);
  static const textSecondary = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);
  static const success = primary;
  static const danger = Color(0xFFE11D48);
}
