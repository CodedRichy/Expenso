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
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            settings: const RouteSettings(name: '/'),
            pageBuilder: (context, animation, secondaryAnimation) => const RootScreen(),
            transitionDuration: const Duration(milliseconds: 300),
            opaque: true,
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
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
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: const _SplashBody(),
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
                'assets/app_icon_transparent.png',
                width: 250,
                height: 250,
              ),
            ),
    );
  }
}