import 'dart:async';
import 'package:flutter/material.dart';
import '../design/colors.dart';
import '../repositories/cycle_repository.dart';

class UndoExpense extends StatefulWidget {
  final String? groupId;
  final String? expenseId;
  final String? description;
  final double? amount;

  const UndoExpense({
    super.key,
    this.groupId,
    this.expenseId,
    this.description,
    this.amount,
  });

  @override
  State<UndoExpense> createState() => _UndoExpenseState();
}

class _UndoExpenseState extends State<UndoExpense> {
  static const int _countdownSeconds = 5;
  int _timeLeft = _countdownSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_timeLeft <= 0) {
        _timer?.cancel();
        _dismiss();
      } else {
        setState(() => _timeLeft--);
      }
    });
  }

  void _undo() {
    _timer?.cancel();
    final repo = CycleRepository.instance;
    final gid = widget.groupId ?? repo.lastAddedGroupId;
    final eid = widget.expenseId ?? repo.lastAddedExpenseId;
    if (gid != null && eid != null) {
      repo.hardDeleteExpense(gid, eid);
    }
    _dismiss();
  }

  void _dismiss() {
    if (!mounted) return;
    CycleRepository.instance.clearLastAdded();
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = CycleRepository.instance;
    final description = widget.description ?? repo.lastAddedDescription ?? '';
    final amount = widget.amount ?? repo.lastAddedAmount ?? 0.0;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final toastBg = isDark ? theme.colorScheme.surfaceContainerHighest : context.colorPrimary;
    final toastText = isDark ? theme.colorScheme.onSurface : context.colorSurface;
    final toastSecondary = isDark ? theme.colorScheme.onSurfaceVariant : context.colorSurface.withValues(alpha: 0.7);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned(
            bottom: 32,
            left: 24,
            right: 24,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 430),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: toastBg,
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
                            color: toastText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$description · ₹${amount.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: toastSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  TextButton.icon(
                    onPressed: _undo,
                    icon: Icon(
                      Icons.refresh,
                      size: 16,
                      color: toastText,
                    ),
                    label: Text(
                      'Undo',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: toastText,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
