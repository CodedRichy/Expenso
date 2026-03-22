import 'dart:ui';
import 'package:flutter/material.dart';
import '../design/colors.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double? borderRadius;
  final Color? backgroundColor;
  final double? blur;
  final double? width;
  final EdgeInsets? margin;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.backgroundColor,
    this.blur,
    this.width,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    Widget card = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius ?? 16),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: blur ?? 20,
          sigmaY: blur ?? 20,
        ),
        child: Container(
          width: width,
          padding: padding ?? const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: backgroundColor ?? context.colorSurfaceGlass,
            borderRadius: BorderRadius.circular(borderRadius ?? 16),
            border: Border.all(
              color: context.colorBorder,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: context.colorGlassShadow,
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );

    if (margin != null) {
      card = Padding(padding: margin!, child: card);
    }

    return card;
  }
}
