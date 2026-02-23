import 'package:flutter/material.dart';
import 'colors.dart';

abstract final class AppTypography {
  // Hero/Page Titles
  static const heroTitle = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: -0.6,
  );

  // Screen/Dialog Titles
  static const screenTitle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );

  // Subheaders
  static const subheader = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: -0.4,
  );

  // Amount Display - Extra Large
  static const amountXL = TextStyle(
    fontSize: 52,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: -1.2,
    height: 1.1,
  );

  // Amount Display - Large
  static const amountLG = TextStyle(
    fontSize: 38,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: -0.9,
    height: 1.1,
  );

  // Amount Display - Medium
  static const amountMD = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );

  // Amount Display - Small (inline amounts)
  static const amountSM = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  // AppBar Title
  static const appBarTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
  );

  // List Item Title
  static const listItemTitle = TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
  );

  // Section Label (ALL CAPS)
  static const sectionLabel = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.textTertiary,
    letterSpacing: 0.3,
  );

  // Body Primary
  static const bodyPrimary = TextStyle(
    fontSize: 17,
    color: AppColors.textPrimary,
  );

  // Body Secondary
  static const bodySecondary = TextStyle(
    fontSize: 15,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  // Button Text
  static const button = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w500,
  );

  // Caption
  static const caption = TextStyle(
    fontSize: 14,
    color: AppColors.textTertiary,
  );

  // Caption Small
  static const captionSmall = TextStyle(
    fontSize: 12,
    color: AppColors.textTertiary,
  );

  // Input Text
  static const input = TextStyle(
    fontSize: 17,
    color: AppColors.textPrimary,
  );

  // Hint Text
  static const hint = TextStyle(
    fontSize: 17,
    color: AppColors.textDisabled,
  );

  // Error Text
  static const errorText = TextStyle(
    fontSize: 13,
    color: AppColors.error,
  );
}
