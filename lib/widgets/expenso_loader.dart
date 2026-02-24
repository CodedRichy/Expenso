import 'dart:math' as math;
import 'package:flutter/material.dart';

class ExpensoLoader extends StatefulWidget {
  final double size;
  
  const ExpensoLoader({
    super.key,
    this.size = 160,
  });

  @override
  State<ExpensoLoader> createState() => _ExpensoLoaderState();
}

class _ExpensoLoaderState extends State<ExpensoLoader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 8000),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: _controller.value * 2 * math.pi,
          child: child,
        );
      },
      child: _CircularText(
        text: 'EXPENSO • EXPENSO •',
        radius: widget.size / 2 - 10,
        textStyle: TextStyle(
          fontSize: widget.size * 0.1,
          fontWeight: FontWeight.w500,
          color: textColor,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _CircularText extends StatelessWidget {
  final String text;
  final double radius;
  final TextStyle textStyle;

  const _CircularText({
    required this.text,
    required this.radius,
    required this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: (radius + 20) * 2,
      height: (radius + 20) * 2,
      child: CustomPaint(
        painter: _CircularTextPainter(
          text: text,
          radius: radius,
          textStyle: textStyle,
        ),
      ),
    );
  }
}

class _CircularTextPainter extends CustomPainter {
  final String text;
  final double radius;
  final TextStyle textStyle;

  _CircularTextPainter({
    required this.text,
    required this.radius,
    required this.textStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final anglePerChar = (2 * math.pi) / text.length;
    
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      if (char == ' ') continue;
      
      final angle = -math.pi / 2 + (i * anglePerChar);
      
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle + math.pi / 2);
      canvas.translate(0, -radius);
      
      final textPainter = TextPainter(
        text: TextSpan(text: char, style: textStyle),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2),
      );
      
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _CircularTextPainter oldDelegate) {
    return oldDelegate.text != text || 
           oldDelegate.radius != radius ||
           oldDelegate.textStyle != textStyle;
  }
}
