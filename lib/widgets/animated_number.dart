import 'package:flutter/material.dart';

class AnimatedNumber extends StatelessWidget {
  final double value;
  final TextStyle? style;
  final String prefix;
  final String suffix;
  final Duration duration;

  const AnimatedNumber({
    Key? key,
    required this.value,
    this.style,
    this.prefix = '',
    this.suffix = '',
    this.duration = const Duration(milliseconds: 300),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: duration,
      builder: (context, animatedValue, child) {
        return Text(
          '$prefix${animatedValue.toStringAsFixed(0)}$suffix',
          style: style,
        );
      },
    );
  }
}
