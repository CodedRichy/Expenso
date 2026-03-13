import 'package:flutter/material.dart';
import 'colors.dart';
import 'typography.dart';

ThemeData buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;

  final primary = isDark ? AppColorsDark.primary : AppColors.primary;
  final surface = isDark ? AppColorsDark.surface : AppColors.surface;
  final background = isDark ? AppColorsDark.background : AppColors.background;
  final error = isDark ? AppColorsDark.error : AppColors.error;
  final textPrimary = isDark
      ? AppColorsDark.textPrimary
      : AppColors.textPrimary;
  final textSecondary = isDark
      ? AppColorsDark.textSecondary
      : AppColors.textSecondary;
  final textTertiary = isDark
      ? AppColorsDark.textTertiary
      : AppColors.textTertiary;
  final textDisabled = isDark
      ? AppColorsDark.textDisabled
      : AppColors.textDisabled;
  final border = isDark ? AppColorsDark.border : AppColors.border;
  final borderInput = isDark
      ? AppColorsDark.borderInput
      : AppColors.borderInput;
  final borderFocused = isDark
      ? AppColorsDark.borderFocused
      : AppColors.borderFocused;
  final accent = isDark ? AppColorsDark.accent : AppColors.accent;
  final disabledBg = isDark
      ? AppColorsDark.disabledBackground
      : AppColors.disabledBackground;
  final disabledFg = isDark
      ? AppColorsDark.disabledForeground
      : AppColors.disabledForeground;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
      primary: primary,
      onPrimary: surface,
      surface: surface,
      error: error,
    ),
    scaffoldBackgroundColor: background,
    textTheme: TextTheme(
      displayLarge: AppTypography.heroTitle.copyWith(color: textPrimary),
      headlineLarge: AppTypography.screenTitle.copyWith(color: textPrimary),
      headlineMedium: AppTypography.subheader.copyWith(color: textPrimary),
      titleLarge: AppTypography.appBarTitle.copyWith(color: textPrimary),
      titleMedium: AppTypography.listItemTitle.copyWith(color: textPrimary),
      bodyLarge: AppTypography.bodyPrimary.copyWith(color: textPrimary),
      bodyMedium: AppTypography.bodySecondary.copyWith(color: textSecondary),
      labelLarge: AppTypography.button.copyWith(color: textPrimary),
      labelMedium: AppTypography.sectionLabel.copyWith(color: textTertiary),
      bodySmall: AppTypography.caption.copyWith(color: textTertiary),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        disabledBackgroundColor: disabledBg,
        foregroundColor: surface,
        disabledForegroundColor: disabledFg,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        side: BorderSide(color: border),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: accent,
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      hintStyle: AppTypography.hint.copyWith(color: textDisabled),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderInput),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderInput),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderFocused),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: error),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    dividerTheme: DividerThemeData(color: border, thickness: 1, space: 0),
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: textPrimary,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: isDark ? AppColorsDark.cardGradientStart : AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? AppColorsDark.cardBorder : AppColors.cardBorder,
        ),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: isDark
          ? AppColorsDark.cardGradientStart
          : AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: isDark
          ? AppColorsDark.cardGradientStart
          : AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: isDark
          ? AppColorsDark.cardGradientEnd
          : const Color(0xFF323232),
      contentTextStyle: AppTypography.bodyPrimary.copyWith(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
