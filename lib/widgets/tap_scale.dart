import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TapScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double targetScale;
  final double? scaleDown; // Alias for targetScale for backwards compatibility
  final Duration duration;
  final bool enableHaptic;

  const TapScale({
    Key? key,
    required this.child,
    this.onTap,
    this.targetScale = 0.96,
    this.scaleDown,
    this.duration = const Duration(milliseconds: 100),
    this.enableHaptic = false,
  }) : super(key: key);

  @override
  State<TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<TapScale> {
  bool _isPressed = false;

  double get _effectiveScale => widget.scaleDown ?? widget.targetScale;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        if (widget.enableHaptic) {
          HapticFeedback.lightImpact();
        }
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? _effectiveScale : 1.0,
        duration: widget.duration,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

