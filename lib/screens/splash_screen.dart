import 'package:flutter/material.dart';
import '../widgets/expenso_loader.dart';

/// Full-screen splash shown on launch. Displays elliptical text animation then navigates to main route.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  static const _fadeInDuration = Duration(milliseconds: 500);
  static const _holdDuration = Duration(milliseconds: 1800);
  static const _fadeOutDuration = Duration(milliseconds: 400);

  late AnimationController _fadeController;
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
          child: const ExpensoLoader(),
        ),
      ),
    );
  }
}
