import 'package:flutter/material.dart';
import '../design/theme.dart';
import '../screens/auth/initialization_error_screen.dart';

class InitializationErrorApp extends StatelessWidget {
  final String error;
  final VoidCallback? onRetry;

  const InitializationErrorApp({
    super.key,
    required this.error,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expenso - Critical Error',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: InitializationErrorScreen(
        error: error,
        onRetry: onRetry,
      ),
    );
  }
}
