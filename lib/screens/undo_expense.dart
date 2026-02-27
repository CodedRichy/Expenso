import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../repositories/cycle_repository.dart';
import '../widgets/undo_toast.dart';

class UndoExpense extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final repo = CycleRepository.instance;
    final gid = groupId ?? repo.lastAddedGroupId;
    final desc = description ?? repo.lastAddedDescription ?? '';
    final amt = amount ?? repo.lastAddedAmount ?? 0.0;
    final currencyCode = gid != null ? repo.getGroup(gid)?.currencyCode ?? 'INR' : 'INR';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: UndoToast(
        description: desc,
        amount: amt,
        currencyCode: currencyCode,
        onUndo: () {
          HapticFeedback.lightImpact();
          final id = expenseId ?? repo.lastAddedExpenseId;
          if (gid != null && id != null) repo.hardDeleteExpense(gid, id);
          repo.clearLastAdded();
          Navigator.of(context).pop();
        },
        onDismiss: () {
          repo.clearLastAdded();
          Navigator.of(context).pop();
        },
      ),
    );
  }
}
