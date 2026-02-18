import 'package:flutter/material.dart';

/// Full-screen splash shown on launch. Displays logo with animation then navigates to main route.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  static const _animDuration = Duration(milliseconds: 700);
  static const _holdDuration = Duration(milliseconds: 1200);
  static const _logoHeight = 220.0;

  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: _animDuration,
      vsync: this,
    );
    _scale = Tween<double>(begin: 0.72, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 700ms fade in, hold, then fade out and navigate
      Future.delayed(_animDuration + _holdDuration, () {
        if (!mounted) return;
        _controller.reverse();
      });
      Future.delayed(_animDuration + _holdDuration + _animDuration, () {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/');
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _opacity.value,
              child: Transform.scale(
                scale: _scale.value,
                child: child,
              ),
            );
          },
          child: Image.asset(
            'assets/images/logoTransparent.png',
            height: _logoHeight,
            fit: BoxFit.contain,
            errorBuilder: (_, error, stackTrace) => const Text(
              'Expenso',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
