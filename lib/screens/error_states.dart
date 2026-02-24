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
          child: Stack(
            children: [
              Positioned(
                top: 16,
                left: 8,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.chevron_left, size: 24),
                  color: AppColors.textPrimary,
                ),
              ),
              Center(
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
            ],
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
          child: Stack(
            children: [
              Positioned(
                top: 16,
                left: 8,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.chevron_left, size: 24),
                  color: AppColors.textPrimary,
                ),
              ),
              Center(
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
                          child: const Icon(Icons.payment, color: AppColors.textSecondary, size: 32),
                        ),
                        const SizedBox(height: 32),
                        const Text(
                          'Payment unavailable',
                          textAlign: TextAlign.center,
                          style: AppTypography.subheader,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Payment processing is temporarily unavailable. You can settle manually outside the app.',
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyPrimary.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 48),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 0),
                          ),
                          child: const Text('Go Back', style: AppTypography.button),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 16,
              left: 8,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.chevron_left, size: 24),
                color: AppColors.textPrimary,
              ),
            ),
            Center(
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
                        child: const Icon(Icons.refresh, color: AppColors.textSecondary, size: 32),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'Something went wrong',
                        textAlign: TextAlign.center,
                        style: AppTypography.subheader,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'We had trouble loading data. Your existing data is safe.',
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
          ],
        ),
      ),
    );
  }
}
