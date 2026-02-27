import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../design/colors.dart';
import '../utils/money_format.dart';

class UndoToast extends StatefulWidget {
  final String description;
  final double amount;
  final String currencyCode;
  final VoidCallback onUndo;
  final VoidCallback onDismiss;
  final int countdownSeconds;

  const UndoToast({
    super.key,
    required this.description,
    required this.amount,
    required this.currencyCode,
    required this.onUndo,
    required this.onDismiss,
    this.countdownSeconds = 5,
  });

  @override
  State<UndoToast> createState() => _UndoToastState();
}

class _UndoToastState extends State<UndoToast> with SingleTickerProviderStateMixin {
  late AnimationController _enterController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  Timer? _timer;
  int _timeLeft = 5;

  @override
  void initState() {
    super.initState();
    _timeLeft = widget.countdownSeconds;
    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _enterController, curve: Curves.easeOutCubic));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _enterController, curve: Curves.easeOut),
    );
    _enterController.forward();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _timer?.cancel();
        return;
      }
      if (_timeLeft <= 1) {
        _timer?.cancel();
        if (mounted) widget.onDismiss();
      } else {
        setState(() => _timeLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _enterController.dispose();
    super.dispose();
  }

  void _onUndo() {
    _timer?.cancel();
    HapticFeedback.lightImpact();
    widget.onUndo();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final toastBgColor = isDark ? theme.colorScheme.surfaceContainerHighest : context.colorPrimary;
    final toastTextColor = isDark ? theme.colorScheme.onSurface : context.colorSurface;
    final toastSecondaryColor = isDark ? theme.colorScheme.onSurfaceVariant : context.colorSurface.withValues(alpha: 0.7);
    final progress = _timeLeft / widget.countdownSeconds;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned(
            bottom: 32,
            left: 24,
            right: 24,
            child: SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 430),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: toastBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Expense added',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: toastTextColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${widget.description} · ${formatMoneyFromMajor(widget.amount, widget.currencyCode)}',
                              style: TextStyle(
                                fontSize: 14,
                                color: toastSecondaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 2,
                          backgroundColor: toastTextColor.withValues(alpha: 0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(toastTextColor),
                        ),
                      ),
                      const SizedBox(width: 12),
                      TextButton.icon(
                        onPressed: _onUndo,
                        icon: Icon(Icons.refresh, size: 16, color: toastTextColor),
                        label: Text(
                          'Undo',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: toastTextColor),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                      ),
                    ],
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
