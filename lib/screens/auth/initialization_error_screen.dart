import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../design/colors.dart';
import '../../design/typography.dart';
import '../../widgets/fade_in.dart';

class InitializationErrorScreen extends StatelessWidget {
  final String error;
  final VoidCallback? onRetry;

  const InitializationErrorScreen({
    super.key,
    required this.error,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Design tokens from v2.1
    final colorSurfaceGlass = isDark ? const Color(0xE61A1A1E) : const Color(0xF0FFFFFF);
    final colorTextPrimary = isDark ? const Color(0xFFF5F5F5) : const Color(0xFF0A0A0A);
    final colorTextSecondary = isDark ? const Color(0xFFB0B0B0) : const Color(0xFF6B6B6B);
    final colorError = const Color(0xFFEF4444);
    final colorBorder = isDark ? const Color(0x20FFFFFF) : const Color(0x18000000);

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient/Image (Optional, using soft gray background)
          Container(
            color: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF8F9FA),
          ),
          
          Center(
            child: FadeIn(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: colorSurfaceGlass,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colorBorder, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: colorError.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.error_outline_rounded,
                              color: colorError,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Configuration Error',
                            style: context.headingLarge.copyWith(
                              color: colorTextPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Expenso could not initialize because of a environment configuration issue.',
                            textAlign: TextAlign.center,
                            style: context.bodyMedium.copyWith(
                              color: colorTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.black26 : Colors.black.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: colorBorder),
                            ),
                            child: Text(
                              error,
                              textAlign: TextAlign.center,
                              style: context.labelSmall.copyWith(
                                color: colorError.withOpacity(0.8),
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                HapticFeedback.mediumImpact();
                                if (onRetry != null) {
                                  onRetry!();
                                } else {
                                  // Default behavior: restart app log or message
                                  debugPrint('Retry pressed. Please restart the app.');
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark ? Colors.white : Colors.black,
                                foregroundColor: isDark ? Colors.black : Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                'Retry Initialization',
                                style: context.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              // Could open documentation or help center
                            },
                            child: Text(
                              'Check Setup Guide',
                              style: context.labelLarge.copyWith(
                                color: colorTextSecondary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
