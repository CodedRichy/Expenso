import 'package:flutter/material.dart';
import '../widgets/expenso_loader.dart';


class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  static const _logoFadeInDuration = Duration(milliseconds: 400);
  static const _logoHoldDuration = Duration(milliseconds: 1000);
  static const _logoFadeOutDuration = Duration(milliseconds: 300);
  static const _loaderFadeInDuration = Duration(milliseconds: 300);
  static const _loaderHoldDuration = Duration(milliseconds: 1500);

  late AnimationController _logoController;
  late Animation<double> _logoOpacity;
  
  bool _showLoader = false;

  @override
  void initState() {
    super.initState();
    
    _logoController = AnimationController(
      duration: _logoFadeInDuration,
      vsync: this,
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOut),
    );
    
    _logoController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Fade out logo
      Future.delayed(_logoFadeInDuration + _logoHoldDuration, () {
        if (!mounted) return;
        _logoController.reverse();
      });
      
      // Show loader after logo fades out
      Future.delayed(_logoFadeInDuration + _logoHoldDuration + _logoFadeOutDuration, () {
        if (!mounted) return;
        setState(() => _showLoader = true);
      });
      
      // Navigate after loader shows
      Future.delayed(
        _logoFadeInDuration + _logoHoldDuration + _logoFadeOutDuration + _loaderFadeInDuration + _loaderHoldDuration,
        () {
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, '/');
        },
      );
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF7E7E7E),
      body: Center(
        child: _showLoader
            ? AnimatedOpacity(
                opacity: 1.0,
                duration: _loaderFadeInDuration,
                child: const ExpensoLoader(),
              )
            : AnimatedBuilder(
                animation: _logoController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _logoOpacity.value,
                    child: child,
                  );
                },
                child: Image.asset(
                  'assets/images/logoRevamp.png',
                  width: 150,
                  height: 150,
                ),
              ),
      ),
    );
  }
}
