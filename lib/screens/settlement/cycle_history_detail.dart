import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../design/colors.dart';
import '../../design/spacing.dart';
import '../../design/typography.dart';
import '../../widgets/animated_number.dart';
import '../../widgets/fade_in.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/gradient_scaffold.dart';
import '../../widgets/tap_scale.dart';
import '../../widgets/staggered_list_item.dart';
import '../../models/cycle.dart';
import '../../utils/money_format.dart';
import '../../utils/route_args.dart';
import '../../services/locale_service.dart';

class CycleHistoryDetail extends StatelessWidget {
  const CycleHistoryDetail({super.key});

  @override
  Widget build(BuildContext context) {
    final args = RouteArgs.getMap(context);
    if (args == null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => Navigator.of(context).maybePop(),
      );
      return const Scaffold(body: SizedBox.shrink());
    }
    final cycleData = args['cycle'];
    final groupName = args['groupName'] as String?;
    final currencyCode = args['currencyCode'] as String? ?? 'INR';
    if (cycleData is! Cycle || groupName == null || groupName.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => Navigator.of(context).maybePop(),
      );
      return const Scaffold(body: SizedBox.shrink());
    }
    final cycle = cycleData;
    final startDate = cycle.startDate ?? '–';
    final endDate = cycle.endDate ?? '–';
    final cycleDate = '$startDate – $endDate';
    final settledAmount = cycle.expenses.fold<double>(
      0.0,
      (sum, e) => sum + e.amount,
    );
    final listExpenses = cycle.expenses;
    final locale = LocaleService.instance.localeCode;

    return GradientScaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  TapScale(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.08),
                        ),
                      ),
                      child: const Icon(Icons.chevron_left, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FadeIn(
                          delay: const Duration(milliseconds: 80),
                          child: Text(
                            groupName,
                            style: context.headingMedium.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        FadeIn(
                          delay: const Duration(milliseconds: 120),
                          child: Text(
                            cycleDate,
                            style: context.labelMedium.copyWith(
                              color: context.colorTextSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Summary card ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: FadeIn(
                delay: const Duration(milliseconds: 160),
                child: GlassCard(
                  padding: const EdgeInsets.all(20),
                  borderRadius: AppSpacing.radiusMedium,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Settled',
                              style: context.labelMedium.copyWith(
                                color: context.colorTextSecondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            AnimatedNumber(
                              value: settledAmount,
                              currencyCode: currencyCode,
                              locale: locale,
                              duration: const Duration(milliseconds: 900),
                              style: context.displayLarge.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: -1,
                                height: 1.1,
                                color: context.colorSuccess,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 14,
                              color: Colors.green.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Settled',
                              style: context.caption.copyWith(
                                color: Colors.green.shade600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Expenses list ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text('EXPENSES', style: context.sectionLabel),
            ),
            Expanded(
              child: listExpenses.isEmpty
                  ? Center(
                      child: Text(
                        'No expenses in this cycle',
                        style: context.bodyPrimary.copyWith(
                          color: context.colorTextSecondary,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                      itemCount: listExpenses.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final expense = listExpenses[index];
                        return StaggeredListItem(
                          index: index,
                          child: GlassCard(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                            borderRadius: AppSpacing.radiusSmall,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        expense.description,
                                        style: context.listItemTitle,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        expense.displayDate,
                                        style: context.bodySecondary,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  formatMoneyFromMajor(
                                    expense.amount,
                                    currencyCode,
                                    locale,
                                  ),
                                  style: context.listItemTitle.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
