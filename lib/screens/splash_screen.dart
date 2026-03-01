import 'package:flutter/material.dart';

class ExpensoLoader extends StatelessWidget {
  const ExpensoLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 48,
      height: 48,
      child: CircularProgressIndicator(
        strokeWidth: 3,
        backgroundColor: Colors.transparent,
        valueColor: AlwaysStoppedAnimation<Color>(
          Color(0xFF1E1E1E), // or white depending on logo contrast
        ),
      ),
    );
  }
}