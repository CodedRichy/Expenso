import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../models/models.dart';
import '../models/currency.dart';
import '../repositories/cycle_repository.dart';
import '../services/connectivity_service.dart';
import '../utils/money_format.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/tap_scale.dart';
        : 'INR';
    final theme = Theme.of(context);
    final isExact = expense.splitAmountsById != null && expense.splitAmountsById!.isNotEmpty;
    final splitLabel = expense.splitType.isNotEmpty ? expense.splitType : (isExact ? 'Exact' : 'Even');
    final participants = isExact
        ? expense.splitAmountsById!.entries.toList()
        : expense.participantIds.map((id) => MapEntry(id, expense.amount / (expense.participantIds.isEmpty ? 1 : expense.participantIds.length))).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SPLIT',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          splitLabel,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface),
        ),
        const SizedBox(height: 12),
        Text(
          'PEOPLE INVOLVED',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        ...participants.map((e) {
          final name = repo.getMemberDisplayNameById(e.key);
          final amt = e.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  name,
                  style: TextStyle(fontSize: 15, color: theme.colorScheme.onSurface),
                ),
                Text(
                  formatMoneyFromMajor(amt, currencyCode),
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSaveButton() {
    if (!_canEdit) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.dividerColor,
            width: 1,
          ),
        ),
      ),
      child: ElevatedButton(
        onPressed: descriptionController.text.trim().isNotEmpty && amountController.text.isNotEmpty
            ? handleSave
            : null,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 0,
        ),
        child: Text(
          'Save Changes',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
