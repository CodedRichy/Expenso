import 'package:flutter/material.dart';
import '../design/colors.dart';
import '../design/typography.dart';

class DeleteGroup extends StatelessWidget {
  final String groupName;
  final bool hasPendingBalance;
  final double? pendingAmount;

  const DeleteGroup({
    super.key,
    this.groupName = '',
    this.hasPendingBalance = false,
    this.pendingAmount,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.chevron_left, size: 24),
                    color: AppColors.textPrimary,
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                    constraints: const BoxConstraints(),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(32, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Delete Group', style: AppTypography.screenTitle),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 96),
                  child: SizedBox(
                    width: 320,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          groupName.isEmpty ? 'Delete group' : 'Delete "$groupName"',
                          textAlign: TextAlign.center,
                          style: AppTypography.subheader,
                        ),
                        const SizedBox(height: 16),
                        if (hasPendingBalance) ...[
                          Text(
                            'This group has ₹${(pendingAmount ?? 0).toStringAsFixed(0).replaceAllMapped(
                              RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                              (Match m) => '${m[1]},',
                            )} pending',
                            textAlign: TextAlign.center,
                            style: AppTypography.bodyPrimary.copyWith(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Deleting this group will remove all expense history. Outstanding balances will not be automatically settled.',
                            textAlign: TextAlign.center,
                            style: AppTypography.bodySecondary,
                          ),
                        ] else
                          Text(
                            'This will permanently delete the group and all expense history.',
                            textAlign: TextAlign.center,
                            style: AppTypography.bodyPrimary.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                        const SizedBox(height: 48),
                        Column(
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 0),
                              ),
                              child: const Text('Delete Group', style: AppTypography.button),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 0),
                              ),
                              child: const Text('Cancel', style: AppTypography.button),
                            ),
                          ],
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
