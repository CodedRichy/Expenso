import 'package:flutter/material.dart';
import '../design/colors.dart';
import '../design/typography.dart';
import '../repositories/cycle_repository.dart';

class ErrorStates extends StatelessWidget {
  final String type; // 'network', 'session-expired', 'payment-unavailable', 'generic'

  const ErrorStates({
    super.key,
    this.type = 'generic',
  });

  @override
  Widget build(BuildContext context) {
    if (type == 'network') {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: AppColors.border,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.wifi_off, color: AppColors.textSecondary, size: 32),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Connection unavailable',
                      textAlign: TextAlign.center,
                      style: AppTypography.subheader,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Unable to load data. Check your connection and try again.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyPrimary.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 48),
                    ElevatedButton(
                      onPressed: () {
                        CycleRepository.instance.restartListening();
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 0),
                      ),
                      child: const Text('Try Again', style: AppTypography.button),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (type == 'session-expired') {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: AppColors.border,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.access_time, color: AppColors.textSecondary, size: 32),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Session expired',
                      textAlign: TextAlign.center,
                      style: AppTypography.subheader,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Your session has expired. Verify your phone number to continue.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyPrimary.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 48),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/');
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 0),
                      ),
                      child: const Text('Verify', style: AppTypography.button),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (type == 'payment-unavailable') {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: AppColors.border,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.error_outline, color: AppColors.textSecondary, size: 32),
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Payment service unavailable',
                      textAlign: TextAlign.center,
                      style: AppTypography.subheader,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Payment processing is temporarily unavailable. Try again later or settle manually.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyPrimary.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 48),
                    Column(
                      children: [
                        ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 0),
                          ),
                          child: const Text('Try Again', style: AppTypography.button),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 0),
                          ),
                          child: const Text('Cancel', style: AppTypography.button),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: AppColors.border,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.error_outline, color: AppColors.textSecondary, size: 32),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Something went wrong',
                    textAlign: TextAlign.center,
                    style: AppTypography.subheader,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'An error occurred. Try again or restart the app.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyPrimary.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 48),
                  ElevatedButton(
                    onPressed: () {
                      CycleRepository.instance.restartListening();
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 0),
                    ),
                    child: const Text('Try Again', style: AppTypography.button),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
