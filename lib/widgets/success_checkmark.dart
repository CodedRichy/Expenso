import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../design/colors.dart';

class SuccessCheckmark extends StatefulWidget {
  final double size;
  final Color? color;
  final VoidCallback? onComplete;

  const SuccessCheckmark({
    Key? key,
    this.size = 80,
    this.color,
    this.onComplete,
  }) : super(key: key);

  @override
  State<SuccessCheckmark> createState() => _SuccessCheckmarkState();
}

class _SuccessCheckmarkState extends State<SuccessCheckmark>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );
    _controller.forward();
    HapticFeedback.mediumImpact();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete?.call();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? context.colorSuccess;
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.check,
          size: widget.size * 0.6,
          color: Colors.white,
        ),
      ),
    );
  }
}
