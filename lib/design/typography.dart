import 'package:flutter/material.dart';
import 'colors.dart';

extension ThemedTypography on BuildContext {
  TextStyle get heroTitle => AppTypography.heroTitle.copyWith(
    color: Theme.of(this).colorScheme.onSurface,
  );
  TextStyle get screenTitle => AppTypography.screenTitle.copyWith(
    color: Theme.of(this).colorScheme.onSurface,
  );
  TextStyle get subheader => AppTypography.subheader.copyWith(
    color: Theme.of(this).colorScheme.onSurface,
  );
  TextStyle get bodyPrimary => AppTypography.bodyPrimary.copyWith(
    color: Theme.of(this).colorScheme.onSurface,
  );
  TextStyle get bodySecondary => AppTypography.bodySecondary.copyWith(
    color: Theme.of(this).colorScheme.onSurfaceVariant,
  );
  TextStyle get listItemTitle => AppTypography.listItemTitle.copyWith(
    color: Theme.of(this).colorScheme.onSurface,
  );
  TextStyle get caption => AppTypography.caption.copyWith(
    color: Theme.of(this).colorScheme.onSurfaceVariant,
  );
  TextStyle get captionSmall => AppTypography.captionSmall.copyWith(
    color: Theme.of(this).colorScheme.onSurfaceVariant,
  );
  TextStyle get sectionLabel => AppTypography.sectionLabel.copyWith(
    color: Theme.of(this).colorScheme.onSurfaceVariant,
  );
  TextStyle get amountXL => AppTypography.amountXL.copyWith(
    color: Theme.of(this).colorScheme.onSurface,
  );
  TextStyle get amountLG => AppTypography.amountLG.copyWith(
    color: Theme.of(this).colorScheme.onSurface,
  );
  TextStyle get amountMD => AppTypography.amountMD.copyWith(
    color: Theme.of(this).colorScheme.onSurface,
  );
  TextStyle get amountSM => AppTypography.amountSM.copyWith(
    color: Theme.of(this).colorScheme.onSurface,
  );
  TextStyle get input => AppTypography.input.copyWith(
    color: Theme.of(this).colorScheme.onSurface,
  );
}

abstract final class AppTypography {
  // Hero/Page Titles - no color = inherits from DefaultTextStyle/Theme
  static const heroTitle = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.6,
  );

  // Screen/Dialog Titles
  static const screenTitle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
  );

  // Subheader
  static const subheader = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
  );

  // Amount Display - Extra Large
  static const amountXL = TextStyle(
    fontSize: 52,
    fontWeight: FontWeight.w600,
    letterSpacing: -1.2,
    height: 1.1,
  );

  // Amount Display - Large
  static const amountLG = TextStyle(
    fontSize: 38,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.9,
    height: 1.1,
  );

  // Amount Display - Medium
  static const amountMD = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
  );

  // Amount Display - Small (inline amounts)
  static const amountSM = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
  );

  // AppBar Title
  static const appBarTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
  );

  // List Item Title
  static const listItemTitle = TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.3,
  );

  // Section Label (ALL CAPS)
  static const sectionLabel = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
  );

  // Body Primary
  static const bodyPrimary = TextStyle(
    fontSize: 17,
  );

  // Body Secondary
  static const bodySecondary = TextStyle(
    fontSize: 15,
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
  );

  // Caption Small
  static const captionSmall = TextStyle(
    fontSize: 12,
  );

  // Input Text
  static const input = TextStyle(
    fontSize: 17,
  );

  // Hint Text
  static const hint = TextStyle(
    fontSize: 17,
  );

  // Error Text
  static const errorText = TextStyle(
    fontSize: 13,
  );
}
