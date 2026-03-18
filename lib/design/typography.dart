import 'package:flutter/material.dart';
import 'colors.dart';

extension ThemedTypography on BuildContext {
  // Text styles from Material Design
  TextStyle get displayLarge => AppTypography.displayLarge.copyWith(
        color: colorTextPrimary,
      );
  TextStyle get displayMedium => AppTypography.displayMedium.copyWith(
        color: colorTextPrimary,
      );
  TextStyle get headingLarge => AppTypography.headingLarge.copyWith(
        color: colorTextPrimary,
      );
  TextStyle get headingMedium => AppTypography.headingMedium.copyWith(
    color: Theme.of(this).colorScheme.onSurface,
  );
  TextStyle get headingSmall => AppTypography.headingSmall.copyWith(
    color: colorTextPrimary,
  );
  TextStyle get bodyLarge => AppTypography.bodyLarge.copyWith(
        color: colorTextPrimary,
      );
  TextStyle get bodyMedium => AppTypography.bodyMedium.copyWith(
        color: colorTextPrimary,
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
  TextStyle get labelLarge => AppTypography.labelLarge.copyWith(
        color: colorTextSecondary,
      );
  TextStyle get labelMedium => AppTypography.labelMedium.copyWith(
        color: colorTextSecondary,
      );
  TextStyle get labelSmall => AppTypography.labelSmall.copyWith(
        color: colorTextTertiary,
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
  TextStyle get input =>
      AppTypography.input.copyWith(color: Theme.of(this).colorScheme.onSurface);

  // Legacy styles for backwards compatibility
  TextStyle get heroTitle => AppTypography.heroTitle.copyWith(
        color: colorTextPrimary,
      );
  TextStyle get screenTitle => AppTypography.screenTitle.copyWith(
        color: colorTextPrimary,
      );
  TextStyle get subheader => AppTypography.subheader.copyWith(
        color: colorTextPrimary,
      );
}

abstract final class AppTypography {
  // Display (Amounts, Big Numbers)
  static const displayLarge = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w600,
    height: 1.1,
    letterSpacing: -0.8,
  );

  static const displayMedium = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: -0.5,
  );

  // Headings
  static const headingLarge = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );

  static const headingMedium = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );

  static const headingSmall = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );

  // Body
  static const bodyLarge = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const bodyMedium = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  // Labels
  static const labelLarge = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static const labelMedium = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.4,
  );

  static const labelSmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.3,
    letterSpacing: 0.4,
  );

  // Legacy/Supporting styles (consider refactoring later)
  static const heroTitle = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.6,
  );

  static const screenTitle = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
  );

  static const subheader = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
  );

  static const amountXL = TextStyle(
    fontSize: 52,
    fontWeight: FontWeight.w600,
    letterSpacing: -1.2,
    height: 1.1,
  );

  static const amountLG = TextStyle(
    fontSize: 38,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.9,
    height: 1.1,
  );

  static const amountMD = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
  );

  static const amountSM = TextStyle(fontSize: 17, fontWeight: FontWeight.w600);

  static const appBarTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
  );

  static const listItemTitle = TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.3,
  );

  static const sectionLabel = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
  );

  static const bodyPrimary = TextStyle(fontSize: 17);

  static const bodySecondary = TextStyle(fontSize: 15, height: 1.5);

  static const button = TextStyle(fontSize: 17, fontWeight: FontWeight.w500);

  static const caption = TextStyle(fontSize: 14);

  static const captionSmall = TextStyle(fontSize: 12);

  static const input = TextStyle(fontSize: 17);

  static const hint = TextStyle(fontSize: 17);

  static const errorText = TextStyle(fontSize: 13);
}
