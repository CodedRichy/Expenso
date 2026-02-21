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
      duration: const Duration(milliseconds: 6000),
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
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            'assets/app_icon_light.png',
            width: widget.size * 0.7,
            height: widget.size * 0.7,
            fit: BoxFit.contain,
          ),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _OrbitTextPainter(
                  progress: _controller.value,
                  size: widget.size,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _OrbitTextPainter extends CustomPainter {
  final double progress;
  final double size;
  
  static const String _text = 'EXPENSO • EXPENSO •';

  _OrbitTextPainter({
    required this.progress,
    required this.size,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    
    final textStyle = TextStyle(
      fontSize: size * 0.055,
      fontWeight: FontWeight.w500,
      color: const Color(0xFF1A1A1A),
      letterSpacing: 1.0,
    );
    
    final a = size * 0.46;
    final b = size * 0.18;
    final tilt = -0.38;
    final offsetY = size * 0.06;
    
    final angleOffset = progress * 2 * math.pi;
    final anglePerChar = (2 * math.pi) / _text.length;
    
    for (int i = 0; i < _text.length; i++) {
      final char = _text[i];
      if (char == ' ') continue;
      
      final angle = angleOffset + (i * anglePerChar);
      
      final x0 = a * math.cos(angle);
      final y0 = b * math.sin(angle);
      
      final x = x0 * math.cos(tilt) - y0 * math.sin(tilt);
      final y = x0 * math.sin(tilt) + y0 * math.cos(tilt) + offsetY;
      
      final dx = -a * math.sin(angle);
      final dy = b * math.cos(angle);
      final tangentAngle = math.atan2(
        dx * math.sin(tilt) + dy * math.cos(tilt),
        dx * math.cos(tilt) - dy * math.sin(tilt),
      );
      
      canvas.save();
      canvas.translate(center.dx + x, center.dy + y);
      canvas.rotate(tangentAngle);
      
      final painter = TextPainter(
        text: TextSpan(text: char, style: textStyle),
        textDirection: TextDirection.ltr,
      );
      painter.layout();
      painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
      
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitTextPainter oldDelegate) {
    return oldDelegate.progress != progress ||
           oldDelegate.size != size;
  }
}
