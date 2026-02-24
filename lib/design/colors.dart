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
  static const accentBackground = Color(0xFFE8EEF3);
  static const error = Color(0xFFC62828);
  static const errorBackground = Color(0xFFFFEBEE);
  static const warning = Color(0xFFF9A825);
  static const warningBackground = Color(0xFFFFF8E1);
  static const destructive = Color(0xFFD32F2F);
  static const success = Color(0xFF2E7D32);
  static const successLight = Color(0xFF66BB6A);
  static const successBackground = Color(0xFFE8F5E9);
  static const debtRed = Color(0xFFEF5350);

  // Disabled States
  static const disabledBackground = Color(0xFFE5E5E5);
  static const disabledForeground = Color(0xFFB0B0B0);

  // Gradients
  static const gradientStart = Color(0xFF1A1A1A);
  static const gradientMid = Color(0xFF555555);
  static const gradientEnd = Color(0xFF6B6B6B);
}

abstract final class AppColorsDark {
  static const primary = Color(0xFFE5E5E5);
  static const primaryVariant = Color(0xFFB0B0B0);

  static const textPrimary = Color(0xFFF5F5F5);
  static const textSecondary = Color(0xFFB0B0B0);
  static const textTertiary = Color(0xFF808080);
  static const textDisabled = Color(0xFF606060);

  static const background = Color(0xFF121212);
  static const surface = Color(0xFF1E1E1E);
  static const surfaceVariant = Color(0xFF2A2A2A);

  static const border = Color(0xFF3A3A3A);
  static const borderInput = Color(0xFF4A4A4A);
  static const borderFocused = Color(0xFFE5E5E5);

  static const accent = Color(0xFF7BA3C4);
  static const accentBackground = Color(0xFF1E2A35);
  static const error = Color(0xFFEF5350);
  static const errorBackground = Color(0xFF2D1B1B);
  static const warning = Color(0xFFFFCA28);
  static const warningBackground = Color(0xFF2D2A1B);
  static const destructive = Color(0xFFEF5350);
  static const success = Color(0xFF66BB6A);
  static const successLight = Color(0xFF81C784);
  static const successBackground = Color(0xFF1B2D1B);
  static const debtRed = Color(0xFFEF5350);

  static const disabledBackground = Color(0xFF2A2A2A);
  static const disabledForeground = Color(0xFF606060);

  static const gradientStart = Color(0xFF2C3E50);
  static const gradientMid = Color(0xFF3D5A6C);
  static const gradientEnd = Color(0xFF4A6572);
}

extension AppColorsX on BuildContext {
  bool get _isDark => Theme.of(this).brightness == Brightness.dark;

  Color get colorPrimary => _isDark ? AppColorsDark.primary : AppColors.primary;
  Color get colorTextPrimary => _isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
  Color get colorTextSecondary => _isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;
  Color get colorTextTertiary => _isDark ? AppColorsDark.textTertiary : AppColors.textTertiary;
  Color get colorTextDisabled => _isDark ? AppColorsDark.textDisabled : AppColors.textDisabled;
  Color get colorBackground => _isDark ? AppColorsDark.background : AppColors.background;
  Color get colorSurface => _isDark ? AppColorsDark.surface : AppColors.surface;
  Color get colorSurfaceVariant => _isDark ? AppColorsDark.surfaceVariant : AppColors.surfaceVariant;
  Color get colorBorder => _isDark ? AppColorsDark.border : AppColors.border;
  Color get colorBorderInput => _isDark ? AppColorsDark.borderInput : AppColors.borderInput;
  Color get colorBorderFocused => _isDark ? AppColorsDark.borderFocused : AppColors.borderFocused;
  Color get colorAccent => _isDark ? AppColorsDark.accent : AppColors.accent;
  Color get colorAccentBackground => _isDark ? AppColorsDark.accentBackground : AppColors.accentBackground;
  Color get colorError => _isDark ? AppColorsDark.error : AppColors.error;
  Color get colorErrorBackground => _isDark ? AppColorsDark.errorBackground : AppColors.errorBackground;
  Color get colorWarning => _isDark ? AppColorsDark.warning : AppColors.warning;
  Color get colorWarningBackground => _isDark ? AppColorsDark.warningBackground : AppColors.warningBackground;
  Color get colorDestructive => _isDark ? AppColorsDark.destructive : AppColors.destructive;
  Color get colorSuccess => _isDark ? AppColorsDark.success : AppColors.success;
  Color get colorSuccessLight => _isDark ? AppColorsDark.successLight : AppColors.successLight;
  Color get colorSuccessBackground => _isDark ? AppColorsDark.successBackground : AppColors.successBackground;
  Color get colorDebtRed => _isDark ? AppColorsDark.debtRed : AppColors.debtRed;
  Color get colorDisabledBackground => _isDark ? AppColorsDark.disabledBackground : AppColors.disabledBackground;
  Color get colorDisabledForeground => _isDark ? AppColorsDark.disabledForeground : AppColors.disabledForeground;
  Color get colorGradientStart => _isDark ? AppColorsDark.gradientStart : AppColors.gradientStart;
  Color get colorGradientMid => _isDark ? AppColorsDark.gradientMid : AppColors.gradientMid;
  Color get colorGradientEnd => _isDark ? AppColorsDark.gradientEnd : AppColors.gradientEnd;
}
