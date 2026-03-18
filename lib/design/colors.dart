import 'package:flutter/material.dart';

abstract final class AppColors {
  // Primary
  static const primary = Color(0xFF1A1A1A);
  static const primaryVariant = Color(0xFF3A3A3A);

  // Text Hierarchy
  static const textPrimary = Color(0xFF0A0A0A);
  static const textSecondary = Color(0xFF6B6B6B);
  static const textTertiary = Color(0xFF9B9B9B);
  static const textDisabled = Color(0xFFB0B0B0);

  // Backgrounds (Layered for Glassmorphism)
  static const background = Color(0xFFF8F9FA);
  static const surface = Colors.white;
  static const surfaceGlass = Color(0xF0FFFFFF); // 94% opacity
  static const surfaceVariant = Color(0xFFF5F6F7);

  // Card
  static const cardGradientStart = Color(0xFFFFFFFF);
  static const cardGradientEnd = Color(0xFFEFEFEF);
  static const cardBorder = Color(0xFFDADADA);
  static const cardShadow = Color(0x14000000);

  // Borders & Dividers
  static const border = Color(0x18000000); // 9% opacity black
  static const borderInput = Color(0x30000000); // 19% opacity
  static const borderFocused = Color(0xFF1A1A1A);

  // Semantic
  static const success = Color(0xFF10B981);
  static const successLight = Color(0xFF6EE7B7);
  static const successBackground = Color(0xFFD1FAE5);
  static const error = Color(0xFFEF4444);
  static const errorBackground = Color(0xFFFEE2E2);
  static const warning = Color(0xFFF59E0B);
  static const warningBackground = Color(0xFFFEF3C7);
  static const info = Color(0xFF3B82F6);
  static const infoBackground = Color(0xFFDBEAFE);
  static const debtRed = Color(0xFFEF5350);

  // Glassmorphic Overlays
  static const glassFrost = Color(0x80FFFFFF); // 50% white
  static const glassShadow = Color(0x0A000000); // 4% opacity shadow

  // Header/Profile Gradients
  static const gradientStart = Color(0xFF1A1A1A);
  static const gradientMid = Color(0xFF555555);
  static const gradientEnd = Color(0xFF6B6B6B);

  // Accent (Primary action color - same as primary for light theme)
  static const accent = Color(0xFF1A1A1A);

  // Disabled states
  static const disabledBackground = Color(0xFFE5E5E5);
  static const disabledForeground = Color(0xFF9B9B9B);

  // Background gradients (for light theme, similar to dark theme pattern)
  static const backgroundGradientStart = Color(0xFFF8F9FA);
  static const backgroundGradientEnd = Color(0xFFEFF1F3);
}

abstract final class AppColorsDark {
  // Primary
  static const primary = Color(0xFFE5E5E5);
  static const primaryVariant = Color(0xFFB0B0B0);

  // Text
  static const textPrimary = Color(0xFFF5F5F5);
  static const textSecondary = Color(0xFFB0B0B0);
  static const textTertiary = Color(0xFF808080);
  static const textDisabled = Color(0xFF606060);

  // Backgrounds (Dark Glassmorphism)
  static const background = Color(0xFF0A0A0A);
  static const backgroundGradientStart = Color(0xFF0A0A0A);
  static const backgroundGradientEnd = Color(0xFF121216);
  static const surface = Color(0xFF1A1A1E);
  static const surfaceGlass = Color(0xE61A1A1E); // 90% opacity
  static const surfaceVariant = Color(0xFF232329);

  // Card
  static const cardGradientStart = Color(0xFF18181C);
  static const cardGradientEnd = Color(0xFF232329);
  static const cardBorder = Color(0x20FFFFFF);
  static const cardShadow = Color(0x40000000);

  // Borders
  static const border = Color(0x20FFFFFF); // 13% white
  static const borderInput = Color(0x35FFFFFF); // 21% white
  static const borderFocused = Color(0xFFE5E5E5);

  // Semantic
  static const success = Color(0xFF34D399);
  static const successLight = Color(0xFF6EE7B7);
  static const successBackground = Color(0xFF064E3B);
  static const error = Color(0xFFF87171);
  static const errorBackground = Color(0xFF7F1D1D);
  static const warning = Color(0xFFFBBF24);
  static const warningBackground = Color(0xFF78350F);
  static const info = Color(0xFF60A5FA);
  static const infoBackground = Color(0xFF1E3A8A);
  static const debtRed = Color(0xFFEF5350);

  // Accent (Primary action color for dark theme)
  static const accent = Color(0xFFE5E5E5);

  // Disabled states
  static const disabledBackground = Color(0xFF3A3A3E);
  static const disabledForeground = Color(0xFF606060);

  // Glassmorphic Overlays
  static const glassFrost = Color(0x401A1A1E); // 25% surface
  static const glassShadow = Color(0x40000000); // 25% shadow

  // Header/Profile Gradients
  static const gradientStart = Color(0xFF18181C);
  static const gradientMid = Color(0xFF1E1E24);
  static const gradientEnd = Color(0xFF232329);
}

extension AppColorsX on BuildContext {
  bool get _isDark => Theme.of(this).brightness == Brightness.dark;

  Color get colorPrimary => _isDark ? AppColorsDark.primary : AppColors.primary;
  Color get colorPrimaryVariant =>
      _isDark ? AppColorsDark.primaryVariant : AppColors.primaryVariant;
  Color get colorTextPrimary =>
      _isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
  Color get colorTextSecondary =>
      _isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;
  Color get colorTextTertiary =>
      _isDark ? AppColorsDark.textTertiary : AppColors.textTertiary;
  Color get colorTextDisabled =>
      _isDark ? AppColorsDark.textDisabled : AppColors.textDisabled;
  Color get colorBackground =>
      _isDark ? AppColorsDark.background : AppColors.background;
  Color get colorBackgroundGradientStart => _isDark
      ? AppColorsDark.backgroundGradientStart
      : AppColors.backgroundGradientStart;
  Color get colorBackgroundGradientEnd => _isDark
      ? AppColorsDark.backgroundGradientEnd
      : AppColors.backgroundGradientEnd;
  Color get colorSurface => _isDark ? AppColorsDark.surface : AppColors.surface;
  Color get colorSurfaceGlass =>
      _isDark ? AppColorsDark.surfaceGlass : AppColors.surfaceGlass;
  Color get colorSurfaceVariant =>
      _isDark ? AppColorsDark.surfaceVariant : AppColors.surfaceVariant;
  Color get colorCardGradientStart =>
      _isDark ? AppColorsDark.cardGradientStart : AppColors.cardGradientStart;
  Color get colorCardGradientEnd =>
      _isDark ? AppColorsDark.cardGradientEnd : AppColors.cardGradientEnd;
  Color get colorCardBorder =>
      _isDark ? AppColorsDark.cardBorder : AppColors.cardBorder;
  Color get colorCardShadow =>
      _isDark ? AppColorsDark.cardShadow : AppColors.cardShadow;
  Color get colorBorder => _isDark ? AppColorsDark.border : AppColors.border;
  Color get colorBorderInput =>
      _isDark ? AppColorsDark.borderInput : AppColors.borderInput;
  Color get colorBorderFocused =>
      _isDark ? AppColorsDark.borderFocused : AppColors.borderFocused;
  Color get colorSuccess => _isDark ? AppColorsDark.success : AppColors.success;
  Color get colorSuccessLight => _isDark ? AppColorsDark.successLight : AppColors.successLight;
  Color get colorSuccessBackground => _isDark ? AppColorsDark.successBackground : AppColors.successBackground;
  Color get colorError => _isDark ? AppColorsDark.error : AppColors.error;
  Color get colorErrorBackground => _isDark ? AppColorsDark.errorBackground : AppColors.errorBackground;
  Color get colorWarning => _isDark ? AppColorsDark.warning : AppColors.warning;
  Color get colorWarningBackground => _isDark ? AppColorsDark.warningBackground : AppColors.warningBackground;
  Color get colorInfo => _isDark ? AppColorsDark.info : AppColors.info;
  Color get colorInfoBackground => _isDark ? AppColorsDark.infoBackground : AppColors.infoBackground;
  Color get colorDebtRed => _isDark ? AppColorsDark.debtRed : AppColors.debtRed;
  Color get colorAccent => _isDark ? AppColorsDark.accent : AppColors.accent;
  Color get colorAccentBackground => _isDark 
      ? AppColorsDark.surfaceVariant 
      : AppColors.surfaceVariant;
  Color get colorDisabledBackground => _isDark ? AppColorsDark.disabledBackground : AppColors.disabledBackground;
  Color get colorDisabledForeground => _isDark ? AppColorsDark.disabledForeground : AppColors.disabledForeground;
  Color get colorGlassFrost =>
      _isDark ? AppColorsDark.glassFrost : AppColors.glassFrost;
  Color get colorGlassShadow =>
      _isDark ? AppColorsDark.glassShadow : AppColors.glassShadow;
  Color get colorGradientStart =>
      _isDark ? AppColorsDark.gradientStart : AppColors.gradientStart;
  Color get colorGradientMid =>
      _isDark ? AppColorsDark.gradientMid : AppColors.gradientMid;
  Color get colorGradientEnd =>
      _isDark ? AppColorsDark.gradientEnd : AppColors.gradientEnd;
}

