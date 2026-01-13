import 'dart:async';
import 'package:flutter/material.dart';

class ExpenseData {
  final String description;
  final double amount;

  ExpenseData({
    required this.description,
    required this.amount,
  });
}

class UndoExpense extends StatefulWidget {
  final ExpenseData? expense;

  const UndoExpense({
    super.key,
    this.expense,
  });

  @override
  State<UndoExpense> createState() => _UndoExpenseState();
}

class _UndoExpenseState extends State<UndoExpense> {
  int timeLeft = 5;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    startTimer();
  }

  void startTimer() {
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (timeLeft == 0) {
        timer.cancel();
        handleDismiss();
      } else {
        setState(() {
          timeLeft--;
        });
      }
    });
  }

  void handleUndo() {
    timer?.cancel();
    // onUndo callback would go here
    handleDismiss();
  }

  void handleDismiss() {
    // onDismiss callback would go here
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final defaultExpense = widget.expense ??
        ExpenseData(
          description: 'Dinner at Bistro 42',
          amount: 1200,
        );

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
                          '${defaultExpense.description} · ₹${defaultExpense.amount.toStringAsFixed(0)}',
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
                    onPressed: handleUndo,
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
