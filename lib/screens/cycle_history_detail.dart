import 'package:flutter/material.dart';
import '../design/spacing.dart';
import '../widgets/fade_in.dart';
import '../widgets/tap_scale.dart';
import '../models/cycle.dart';
import '../utils/money_format.dart';
import '../utils/route_args.dart';
import '../widgets/staggered_list_item.dart';

class CycleHistoryDetail extends StatelessWidget {
  const CycleHistoryDetail({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final args = RouteArgs.getMap(context);
    if (args == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.of(context).maybePop());
      return const Scaffold(body: SizedBox.shrink());
    }
    final cycleData = args['cycle'];
    final groupName = args['groupName'] as String?;
    final currencyCode = args['currencyCode'] as String? ?? 'INR';
    if (cycleData is! Cycle || groupName == null || groupName.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.of(context).maybePop());
      return const Scaffold(body: SizedBox.shrink());
    }
    final cycle = cycleData;
    final startDate = cycle.startDate ?? '–';
    final endDate = cycle.endDate ?? '–';
    final cycleDate = '$startDate – $endDate';
    final settledAmount = cycle.expenses.fold<double>(0.0, (sum, e) => sum + e.amount);
    final listExpenses = cycle.expenses;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.screenPaddingH,
                AppSpacing.screenHeaderPaddingTop,
                AppSpacing.screenPaddingH,
                AppSpacing.space3xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TapScale(
                    child: IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.chevron_left, size: 24),
                      color: theme.colorScheme.onSurface,
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                      constraints: const BoxConstraints(),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(32, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FadeIn(
                    delay: const Duration(milliseconds: 100),
                    child: Text(
                      groupName,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  FadeIn(
                    delay: const Duration(milliseconds: 150),
                    child: Text(
                      cycleDate,
                      style: TextStyle(
                        fontSize: 17,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            FadeIn(
              delay: const Duration(milliseconds: 200),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: theme.dividerColor,
                      width: 1,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatMoneyFromMajor(settledAmount, currencyCode),
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                        letterSpacing: -0.9,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'settled',
                      style: TextStyle(
                        fontSize: 15,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FadeIn(
                    delay: const Duration(milliseconds: 250),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                      child: Text(
                        'EXPENSES',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurfaceVariant,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: listExpenses.length,
                      itemBuilder: (context, index) {
                        final expense = listExpenses[index];
                        return StaggeredListItem(
                          index: index,
                          child: FadeIn(
                            delay: Duration(milliseconds: 300 + index * 50),
                            child: TapScale(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: index > 0
                                        ? BorderSide(color: theme.dividerColor, width: 1)
                                        : BorderSide.none,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            expense.description,
                                            style: TextStyle(
                                              fontSize: 17,
                                              color: theme.colorScheme.onSurface,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            expense.displayDate,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: theme.colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Text(
                                      formatMoneyFromMajor(expense.amount, currencyCode),
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
