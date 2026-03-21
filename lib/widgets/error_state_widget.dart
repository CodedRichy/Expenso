import 'package:flutter/material.dart';
import '../design/colors.dart';
import '../design/typography.dart';
import '../repositories/cycle_repository.dart';
import 'fade_in.dart';

/// Reusable error state widget for embedding in screens.
/// Types:
/// - 'network': Connection error with retry
/// - 'session-expired': Auth error with redirect
/// - 'payment-unavailable': Payment error
/// - 'generic': Generic error with retry
class ErrorStateWidget extends StatelessWidget {
  final String type;
  final VoidCallback? onRetry;
  final VoidCallback? onBack;
  final VoidCallback? onVerify;

  const ErrorStateWidget({
    super.key,
    this.type = 'generic',
    this.onRetry,
    this.onBack,
    this.onVerify,
  });

  @override
  Widget build(BuildContext context) {
    final colorBorder = context.colorBorder;
    final colorTextSecondary = context.colorTextSecondary;

    if (type == 'network') {
      return FadeIn(
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
                  decoration: BoxDecoration(
                    color: colorBorder,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.wifi_off,
                    color: colorTextSecondary,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Connection unavailable',
                  textAlign: TextAlign.center,
                  style: context.subheader,
                ),
                const SizedBox(height: 12),
                Text(
                  'Unable to load data. Check your connection and try again.',
                  textAlign: TextAlign.center,
                  style: context.bodySecondary.copyWith(height: 1.5),
                ),
                const SizedBox(height: 48),
                ElevatedButton(
                  onPressed: onRetry ?? () {
                    CycleRepository.instance.restartListening();
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 0),
                  ),
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (type == 'session-expired') {
      return FadeIn(
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
                  decoration: BoxDecoration(
                    color: colorBorder,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.access_time,
                    color: colorTextSecondary,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Session expired',
                  textAlign: TextAlign.center,
                  style: context.subheader,
                ),
                const SizedBox(height: 12),
                Text(
                  'Your session has expired. Verify your phone number to continue.',
                  textAlign: TextAlign.center,
                  style: context.bodySecondary.copyWith(height: 1.5),
                ),
                const SizedBox(height: 48),
                ElevatedButton(
                  onPressed: onVerify ?? () {
                    Navigator.pushReplacementNamed(context, '/');
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 0),
                  ),
                  child: const Text('Verify'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (type == 'payment-unavailable') {
      return FadeIn(
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
                  decoration: BoxDecoration(
                    color: colorBorder,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.payment,
                    color: colorTextSecondary,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Payment unavailable',
                  textAlign: TextAlign.center,
                  style: context.subheader,
                ),
                const SizedBox(height: 12),
                Text(
                  'Payment processing is temporarily unavailable. You can settle manually outside the app.',
                  textAlign: TextAlign.center,
                  style: context.bodySecondary.copyWith(height: 1.5),
                ),
                const SizedBox(height: 48),
                ElevatedButton(
                  onPressed: onBack ?? () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 0),
                  ),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Generic error
    return FadeIn(
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
                decoration: BoxDecoration(
                  color: colorBorder,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.refresh,
                  color: colorTextSecondary,
                  size: 32,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Something went wrong',
                textAlign: TextAlign.center,
                style: context.subheader,
              ),
              const SizedBox(height: 12),
              Text(
                'We had trouble loading data. Your existing data is safe.',
                textAlign: TextAlign.center,
                style: context.bodySecondary.copyWith(height: 1.5),
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: onRetry ?? () {
                  CycleRepository.instance.restartListening();
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 0),
                ),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
