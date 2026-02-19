import 'dart:async';
import 'package:flutter/material.dart';
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
      repo.deleteExpense(gid, eid);
      repo.clearLastAdded();
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
                color: const Color(0xFF1A1A1A),
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
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$description · ₹${amount.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: const Color(0xFFB0B0B0),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  TextButton.icon(
                    onPressed: _undo,
                    icon: const Icon(
                      Icons.refresh,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: Text(
                      'Undo',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
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
