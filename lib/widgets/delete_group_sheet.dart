import 'package:flutter/material.dart';
import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../utils/money_format.dart';
import '../services/locale_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/tap_scale.dart';

class DeleteGroupSheet extends StatelessWidget {
  final String groupName;
  final bool hasPendingBalance;
  final double? pendingAmount;
  final String currencyCode;
  final VoidCallback onDelete;

  const DeleteGroupSheet({
    super.key,
    required this.groupName,
    this.hasPendingBalance = false,
    this.pendingAmount,
    this.currencyCode = 'INR',
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      decoration: BoxDecoration(
        color: context.colorSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 12,
        bottom: 24 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.colorBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 32),
          
          // Warning Icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: context.colorError.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.delete_outline_rounded,
              color: context.colorError,
              size: 32,
            ),
          ),
          const SizedBox(height: 24),
          
          Text(
            groupName.isEmpty ? 'Delete group' : 'Delete "$groupName"',
            textAlign: TextAlign.center,
            style: context.subheader.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              hasPendingBalance
                  ? 'This group has ${formatMoneyFromMajor(pendingAmount ?? 0, currencyCode, LocaleService.instance.localeCode)} pending. Deleting this will remove all history. Outstanding balances will not be automatically settled.'
                  : 'This will permanently delete the group and all expense history. This action cannot be undone.',
              textAlign: TextAlign.center,
              style: context.bodySecondary.copyWith(height: 1.5),
            ),
          ),
          const SizedBox(height: 32),
          
          Row(
            children: [
              Expanded(
                child: TapScale(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: context.colorBorder),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        'Cancel',
                        style: context.labelLarge.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TapScale(
                  onTap: () {
                    Navigator.pop(context);
                    onDelete();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: context.colorError,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        'Delete',
                        style: context.labelLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Future<void> show(
    BuildContext context, {
    required String groupName,
    bool hasPendingBalance = false,
    double? pendingAmount,
    String currencyCode = 'INR',
    required VoidCallback onDelete,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DeleteGroupSheet(
        groupName: groupName,
        hasPendingBalance: hasPendingBalance,
        pendingAmount: pendingAmount,
        currencyCode: currencyCode,
        onDelete: onDelete,
      ),
    );
  }
}
