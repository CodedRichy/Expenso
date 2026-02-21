import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Full-screen splash shown on launch. Displays circular text animation then navigates to main route.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  static const _fadeInDuration = Duration(milliseconds: 500);
  static const _holdDuration = Duration(milliseconds: 1800);
  static const _fadeOutDuration = Duration(milliseconds: 400);

  late AnimationController _fadeController;
  late AnimationController _rotateController;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: _fadeInDuration,
      vsync: this,
    );
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    
    _rotateController = AnimationController(
      duration: const Duration(milliseconds: 8000),
      vsync: this,
    )..repeat();
    
    _fadeController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(_fadeInDuration + _holdDuration, () {
        if (!mounted) return;
        _fadeController.reverse();
      });
      Future.delayed(_fadeInDuration + _holdDuration + _fadeOutDuration, () {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/');
      });
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      body: Center(
        child: AnimatedBuilder(
          animation: _fadeController,
          builder: (context, child) {
            return Opacity(
              opacity: _opacity.value,
              child: child,
            );
          },
          child: AnimatedBuilder(
            animation: _rotateController,
            builder: (context, child) {
              return Transform.rotate(
                angle: _rotateController.value * 2 * math.pi,
                child: child,
              );
            },
            child: const CircularText(
              text: 'EXPENSO • EXPENSO •',
              radius: 70,
              textStyle: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1A1A1A),
                letterSpacing: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CircularText extends StatelessWidget {
  final String text;
  final double radius;
  final TextStyle textStyle;

  const CircularText({
    super.key,
    required this.text,
    required this.radius,
    required this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: radius * 2 + 40,
      height: radius * 2 + 40,
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
