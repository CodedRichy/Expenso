import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  // Primary
  static Color primary(BuildContext context) =>
      _isDark(context) ? const Color(0xFFE5E5E5) : const Color(0xFF1A1A1A);
  static Color primaryVariant(BuildContext context) =>
      _isDark(context) ? const Color(0xFFB0B0B0) : const Color(0xFF3A3A3A);

  // Text
  static Color textPrimary(BuildContext context) =>
      _isDark(context) ? const Color(0xFFF5F5F5) : const Color(0xFF1A1A1A);
  static Color textSecondary(BuildContext context) =>
      _isDark(context) ? const Color(0xFFB0B0B0) : const Color(0xFF6B6B6B);
  static Color textTertiary(BuildContext context) =>
      _isDark(context) ? const Color(0xFF808080) : const Color(0xFF9B9B9B);
  static Color textDisabled(BuildContext context) =>
      _isDark(context) ? const Color(0xFF606060) : const Color(0xFFB0B0B0);

  // Backgrounds
  static Color background(BuildContext context) =>
      _isDark(context) ? const Color(0xFF121212) : const Color(0xFFF7F7F8);
  static Color surface(BuildContext context) =>
      _isDark(context) ? const Color(0xFF1E1E1E) : Colors.white;
  static Color surfaceVariant(BuildContext context) =>
      _isDark(context) ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0);

  // Borders & Dividers
  static Color border(BuildContext context) =>
      _isDark(context) ? const Color(0xFF3A3A3A) : const Color(0xFFE5E5E5);
  static Color borderInput(BuildContext context) =>
      _isDark(context) ? const Color(0xFF4A4A4A) : const Color(0xFFD0D0D0);
  static Color borderFocused(BuildContext context) =>
      _isDark(context) ? const Color(0xFFE5E5E5) : const Color(0xFF1A1A1A);

  // Semantic
  static Color accent(BuildContext context) =>
      _isDark(context) ? const Color(0xFF7BA3C4) : const Color(0xFF5B7C99);
  static Color accentBackground(BuildContext context) =>
      _isDark(context) ? const Color(0xFF1E2A35) : const Color(0xFFE8EEF3);
  static Color error(BuildContext context) =>
      _isDark(context) ? const Color(0xFFEF5350) : const Color(0xFFC62828);
  static Color errorBackground(BuildContext context) =>
      _isDark(context) ? const Color(0xFF2D1B1B) : const Color(0xFFFFEBEE);
  static Color warning(BuildContext context) =>
      _isDark(context) ? const Color(0xFFFFCA28) : const Color(0xFFF9A825);
  static Color warningBackground(BuildContext context) =>
      _isDark(context) ? const Color(0xFF2D2A1B) : const Color(0xFFFFF8E1);
  static Color destructive(BuildContext context) =>
      _isDark(context) ? const Color(0xFFEF5350) : const Color(0xFFD32F2F);
  static Color success(BuildContext context) =>
      _isDark(context) ? const Color(0xFF66BB6A) : const Color(0xFF2E7D32);
  static Color successLight(BuildContext context) =>
      _isDark(context) ? const Color(0xFF81C784) : const Color(0xFF66BB6A);
  static Color successBackground(BuildContext context) =>
      _isDark(context) ? const Color(0xFF1B2D1B) : const Color(0xFFE8F5E9);
  static Color debtRed(BuildContext context) =>
      _isDark(context) ? const Color(0xFFEF5350) : const Color(0xFFEF5350);

  // Disabled States
  static Color disabledBackground(BuildContext context) =>
      _isDark(context) ? const Color(0xFF2A2A2A) : const Color(0xFFE5E5E5);
  static Color disabledForeground(BuildContext context) =>
      _isDark(context) ? const Color(0xFF606060) : const Color(0xFFB0B0B0);

  // Gradients
  static Color gradientStart(BuildContext context) =>
      _isDark(context) ? const Color(0xFFE5E5E5) : const Color(0xFF1A1A1A);
  static Color gradientMid(BuildContext context) =>
      _isDark(context) ? const Color(0xFFB0B0B0) : const Color(0xFF555555);
  static Color gradientEnd(BuildContext context) =>
      _isDark(context) ? const Color(0xFF808080) : const Color(0xFF6B6B6B);

  // Static values for places without context (ThemeData construction, etc)
  static const primaryLight = Color(0xFF1A1A1A);
  static const primaryDark = Color(0xFFE5E5E5);
  static const backgroundLight = Color(0xFFF7F7F8);
  static const backgroundDark = Color(0xFF121212);
  static const surfaceLight = Colors.white;
  static const surfaceDark = Color(0xFF1E1E1E);
  static const errorLight = Color(0xFFC62828);
  static const errorDark = Color(0xFFEF5350);
}
