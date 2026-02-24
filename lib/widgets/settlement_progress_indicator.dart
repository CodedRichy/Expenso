import 'package:flutter/material.dart';
import '../design/colors.dart';
import '../design/typography.dart';
import '../models/models.dart';
import '../models/payment_attempt.dart';
import '../repositories/cycle_repository.dart';
import '../utils/settlement_engine.dart';

class SettlementProgressIndicator extends StatefulWidget {
  final String groupId;

  const SettlementProgressIndicator({super.key, required this.groupId});

  @override
  State<SettlementProgressIndicator> createState() => _SettlementProgressIndicatorState();
}

class _SettlementProgressIndicatorState extends State<SettlementProgressIndicator> {
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadPaymentAttempts();
  }

  Future<void> _loadPaymentAttempts() async {
    await CycleRepository.instance.loadPaymentAttempts(widget.groupId);
    if (mounted) setState(() => _loaded = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const SizedBox.shrink();
    }

    return ListenableBuilder(
      listenable: CycleRepository.instance,
      builder: (context, _) {
        final progress = _computeProgress();
        if (progress == null) return const SizedBox.shrink();

        final (settled, total) = progress;
        if (total == 0) return const SizedBox.shrink();

        final fraction = total > 0 ? settled / total : 0.0;
        final allSettled = settled == total;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: allSettled ? AppColors.successBackground : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: allSettled ? AppColors.success.withValues(alpha: 0.3) : AppColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    allSettled ? Icons.check_circle : Icons.hourglass_empty,
                    size: 18,
                    color: allSettled ? AppColors.success : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      allSettled
                          ? 'All payments complete'
                          : '$settled of $total payments settled',
                      style: AppTypography.bodyPrimary.copyWith(
                        color: allSettled ? AppColors.success : AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (!allSettled)
                    Text(
                      '${(fraction * 100).toInt()}%',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: fraction,
                  minHeight: 6,
                  backgroundColor: AppColors.border,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    allSettled ? AppColors.success : AppColors.accent,
                  ),
                ),
              ),
              if (!allSettled && (total - settled) > 0) ...[
                const SizedBox(height: 8),
                Text(
                  'Waiting for ${total - settled} payment${(total - settled) == 1 ? '' : 's'}',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  (int settled, int total)? _computeProgress() {
    final repo = CycleRepository.instance;
    final cycle = repo.getActiveCycle(widget.groupId);
    final members = repo.getMembersForGroup(widget.groupId);

    if (members.isEmpty) return null;

    final netBalances = SettlementEngine.computeNetBalances(cycle.expenses, members);
    final routes = SettlementEngine.computePaymentRoutes(netBalances, 'INR');

    if (routes.isEmpty) return null;

    final attempts = repo.getPaymentAttempts(widget.groupId);

    int settled = 0;
    for (final route in routes) {
      final attempt = attempts.firstWhere(
        (a) => a.fromMemberId == route.fromMemberId && a.toMemberId == route.toMemberId,
        orElse: () => PaymentAttempt(
          id: '',
          groupId: '',
          cycleId: '',
          fromMemberId: '',
          toMemberId: '',
          amountMinor: 0,
          currencyCode: 'INR',
          status: PaymentAttemptStatus.notStarted,
          createdAt: 0,
        ),
      );

      if (attempt.status.isSettled) {
        settled++;
      }
    }

    return (settled, routes.length);
  }
}
