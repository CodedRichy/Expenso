import 'package:flutter/material.dart';
import '../design/colors.dart';
import '../design/typography.dart';
import '../repositories/cycle_repository.dart';
import '../widgets/fade_in.dart';

class ErrorStates extends StatelessWidget {
  final String type; // 'network', 'session-expired', 'payment-unavailable', 'generic'

  const ErrorStates({
    super.key,
    this.type = 'generic',
  });

  @override
  Widget build(BuildContext context) {
    final colorTextPrimary = context.colorTextPrimary;
    final colorBorder = context.colorBorder;
    final colorTextSecondary = context.colorTextSecondary;
    if (type == 'network') {
      return Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: 16,
                left: 8,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.chevron_left, size: 24),
                  color: colorTextPrimary,
                ),
              ),
              Center(
                child: FadeIn(
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
                          child: Icon(Icons.wifi_off, color: colorTextSecondary, size: 32),
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
                          onPressed: () {
                            CycleRepository.instance.restartListening();
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 0),
                          ),
                          child: Text('Try Again', style: Theme.of(context).textTheme.labelLarge),
                        ),
                      ],
                    ),
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
        body: SafeArea(
          child: Center(
            child: FadeIn(
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
                      child: Icon(Icons.access_time, color: colorTextSecondary, size: 32),
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
                      style: context.bodySecondary.copyWith(
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
                      child: Text('Verify', style: Theme.of(context).textTheme.labelLarge),
                    ),
                  ],
                ),
              ),
            ),
            ),
          ),
        ),
      );
    }

    if (type == 'payment-unavailable') {
      return Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: 16,
                left: 8,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.chevron_left, size: 24),
                  color: colorTextPrimary,
                ),
              ),
              Center(
                child: FadeIn(
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
                          child: Icon(Icons.payment, color: colorTextSecondary, size: 32),
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
                          style: context.bodySecondary.copyWith(
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
                          child: Text('Go Back', style: Theme.of(context).textTheme.labelLarge),
                        ),
                      ],
                    ),
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
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 16,
              left: 8,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.chevron_left, size: 24),
                color: colorTextPrimary,
              ),
            ),
            Center(
              child: FadeIn(
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
                          child: Icon(Icons.refresh, color: colorTextSecondary, size: 32),
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
                          style: context.bodySecondary.copyWith(
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
                          child: Text('Try Again', style: Theme.of(context).textTheme.labelLarge),
                        ),
                      ],
                    ),
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
