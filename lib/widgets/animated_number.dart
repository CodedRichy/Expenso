import 'package:flutter/material.dart';
import '../utils/money_format.dart';

/// A widget that animates a numeric value from 0 to [value] on mount,
/// or from the previous [value] to the new one on rebuild.
///
/// Use [currencyCode] + [locale] for formatted currency output.
/// Leave both null for a plain formatted integer.
class AnimatedNumber extends StatelessWidget {
  final double value;
  final TextStyle? style;
  final String prefix;
  final String suffix;
  final Duration duration;
  final String? currencyCode;
  final String? locale;
  final int decimalDigits;

  const AnimatedNumber({
    Key? key,
    required this.value,
    this.style,
    this.prefix = '',
    this.suffix = '',
    this.duration = const Duration(milliseconds: 600),
    this.currencyCode,
    this.locale,
    this.decimalDigits = 0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.isFinite ? value : 0),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) {
        final String display;
        if (currencyCode != null) {
          display = formatMoneyFromMajor(animatedValue, currencyCode!, locale);
        } else if (decimalDigits > 0) {
          display =
              '$prefix${animatedValue.toStringAsFixed(decimalDigits)}$suffix';
        } else {
          display = '$prefix${animatedValue.toStringAsFixed(0)}$suffix';
        }
        return Text(display, style: style);
      },
    );
  }
}
