import 'package:flutter/material.dart';
import '../design/colors.dart';
import '../design/typography.dart';
import '../utils/money_format.dart';

/// Not used in navigation. Group delete is done via the confirmation dialog
/// in [GroupsList]. This screen is kept for reference or future full-page flow.
class DeleteGroup extends StatelessWidget {
  final String groupName;
  final bool hasPendingBalance;
  final double? pendingAmount;
  final String currencyCode;

  const DeleteGroup({
    super.key,
    this.groupName = '',
    this.hasPendingBalance = false,
    this.pendingAmount,
    this.currencyCode = 'INR',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.chevron_left, size: 24),
                    color: context.colorTextPrimary,
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                    constraints: const BoxConstraints(),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(32, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Delete Group', style: context.screenTitle),
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
                          style: context.subheader,
                        ),
                        const SizedBox(height: 16),
                        if (hasPendingBalance) ...[
                          Text(
                            'This group has ${formatMoneyFromMajor(pendingAmount ?? 0, currencyCode)} pending',
                            textAlign: TextAlign.center,
                            style: context.bodySecondary,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Deleting this group will remove all expense history. Outstanding balances will not be automatically settled.',
                            textAlign: TextAlign.center,
                            style: context.bodySecondary,
                          ),
                        ] else
                          Text(
                            'This will permanently delete the group and all expense history.',
                            textAlign: TextAlign.center,
                            style: context.bodySecondary.copyWith(
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
                              child: Text('Delete Group', style: Theme.of(context).textTheme.labelLarge),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 0),
                              ),
                              child: Text('Cancel', style: Theme.of(context).textTheme.labelLarge),
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
