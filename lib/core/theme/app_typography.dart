import 'package:flutter/material.dart';

abstract final class AppTypography {
  static const regular = TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w400);
  static const medium = TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500);
  static const semiBold = TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600);
  static const bold = TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700);
}
