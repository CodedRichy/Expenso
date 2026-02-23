import 'package:flutter/material.dart';

abstract final class AppColors {
  // Primary
  static const primary = Color(0xFF1A1A1A);
  static const primaryVariant = Color(0xFF3A3A3A);

  // Text
  static const textPrimary = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF6B6B6B);
  static const textTertiary = Color(0xFF9B9B9B);
  static const textDisabled = Color(0xFFB0B0B0);

  // Backgrounds
  static const background = Color(0xFFF7F7F8);
  static const surface = Colors.white;
  static const surfaceVariant = Color(0xFFF0F0F0);

  // Borders & Dividers
  static const border = Color(0xFFE5E5E5);
  static const borderInput = Color(0xFFD0D0D0);
  static const borderFocused = Color(0xFF1A1A1A);

  // Semantic
  static const accent = Color(0xFF5B7C99);
  static const error = Color(0xFFC62828);
  static const errorBackground = Color(0xFFFFEBEE);
  static const warning = Color(0xFFF9A825);
  static const warningBackground = Color(0xFFFFF8E1);
  static const destructive = Color(0xFFD32F2F);

  // Disabled States
  static const disabledBackground = Color(0xFFE5E5E5);
  static const disabledForeground = Color(0xFFB0B0B0);

  // Gradients
  static const gradientStart = Color(0xFF1A1A1A);
  static const gradientMid = Color(0xFF555555);
  static const gradientEnd = Color(0xFF6B6B6B);
}
