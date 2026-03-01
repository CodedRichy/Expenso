import 'package:flutter/material.dart';
import '../main.dart';
import '../widgets/expenso_loader.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _logoFadeInDuration = Duration(milliseconds: 400);
  static const _logoHoldDuration = Duration(milliseconds: 1000);
  static const _logoFadeOutDuration = Duration(milliseconds: 300);
  static const _loaderHoldDuration = Duration(milliseconds: 1500);

  late final AnimationController _logoController;
  late final Animation<double> _logoOpacity;

  bool _showLoader = false;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: _logoFadeInDuration,
    );

    _logoOpacity = CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeOut,
    );

    _logoController.forward();

    // Fade out logo
    Future.delayed(_logoFadeInDuration + _logoHoldDuration, () {
      if (!mounted) return;
      _logoController.reverse();
    });

    // Show loader after logo fades out
    Future.delayed(
      _logoFadeInDuration + _logoHoldDuration + _logoFadeOutDuration,
      () {
        if (!mounted) return;
        setState(() => _showLoader = true);
      },
    );

    // Navigate to app
    Future.delayed(
      _logoFadeInDuration +
          _logoHoldDuration +
          _logoFadeOutDuration +
          _loaderHoldDuration,
      () {
        if (!mounted) return;
        // Inside _SplashScreenState where you handle navigation
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            settings: const RouteSettings(name: '/'),
            pageBuilder: (context, animation, secondaryAnimation) => const RootScreen(),
            transitionDuration: const Duration(milliseconds: 300), // Precise cross-fade speed
            opaque: true, 
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOut,
                ),
                // The child (RootScreen) fades in OVER the Splash grey
                child: child,
              );
            },
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _logoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF7E7E7E),
      body: _SplashBody(),
    );
  }
}

class _SplashBody extends StatelessWidget {
  const _SplashBody();

  @override
  Widget build(BuildContext context) {
    final state =
        context.findAncestorStateOfType<_SplashScreenState>()!;

    return Center(
      child: state._showLoader
          ? const ExpensoLoader()
          : FadeTransition(
              opacity: state._logoOpacity,
              child: Image.asset(
                'assets/images/logoRevamp.png',
                width: 250,
                height: 250,
              ),
            ),
    );
  }
}