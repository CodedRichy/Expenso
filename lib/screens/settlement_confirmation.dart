import 'package:flutter/material.dart';
import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../models/models.dart';
import '../repositories/cycle_repository.dart';
import '../utils/route_args.dart';
import '../utils/settlement_engine.dart';
import '../widgets/upi_payment_card.dart';

class SettlementConfirmation extends StatelessWidget {
  const SettlementConfirmation({super.key});

  @override
  Widget build(BuildContext context) {
    final group = RouteArgs.getGroup(context);
    if (group == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.of(context).maybePop());
      return const Scaffold(body: SizedBox.shrink());
    }

    final repo = CycleRepository.instance;
    final myPaymentRoutes = _getMyPaymentRoutes(group.id);
    final myTotalDue = myPaymentRoutes.fold<int>(0, (s, r) => s + r.amountMinor);
    final hasUpiDues = myTotalDue > 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.screenPaddingH,
                AppSpacing.screenPaddingTop,
                AppSpacing.screenPaddingH,
                AppSpacing.space3xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
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
                  Text(
                    group.name,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenPaddingH,
                  vertical: AppSpacing.space3xl,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: _buildUpiSection(context, group, repo, myPaymentRoutes, hasUpiDues, myTotalDue),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<PaymentRoute> _getMyPaymentRoutes(String groupId) {
    final repo = CycleRepository.instance;
    final cycle = repo.getActiveCycle(groupId);
    final members = repo.getMembersForGroup(groupId);
    final netBalances = SettlementEngine.computeNetBalances(cycle.expenses, members);
    final allRoutes = SettlementEngine.computePaymentRoutes(netBalances, 'INR');
    return SettlementEngine.getPaymentsForMember(repo.currentUserId, allRoutes);
  }

  Widget _buildUpiSection(
    BuildContext context,
    Group group,
    CycleRepository repo,
    List<PaymentRoute> myRoutes,
    bool hasUpiDues,
    int totalMinor,
  ) {
    if (!hasUpiDues) {
      return Column(
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 64,
            color: AppColors.success,
          ),
          const SizedBox(height: AppSpacing.spaceXl),
          Text(
            'You\'re all settled!',
            style: AppTypography.screenTitle,
          ),
          const SizedBox(height: AppSpacing.spaceMd),
          Text(
            'You have no payments to make this cycle.',
            style: AppTypography.bodySecondary,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.space5xl),
          _buildBackButton(context),
        ],
      );
    }

    final totalDisplay = (totalMinor / 100).toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Column(
            children: [
              Text(
                '₹$totalDisplay',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  letterSpacing: -1.2,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: AppSpacing.spaceMd),
              Text(
                'Your total dues',
                style: AppTypography.bodySecondary,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.space4xl),
        Text(
          'PAY INDIVIDUALLY',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textTertiary,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: AppSpacing.spaceXl),
        ...myRoutes.map((route) {
          final payeeName = repo.getMemberDisplayNameById(route.toMemberId);
          final payeeUpiId = repo.getMemberUpiId(route.toMemberId);
          return UpiPaymentCard(
            payeeName: payeeName,
            payeeUpiId: payeeUpiId,
            amountMinor: route.amountMinor,
            groupName: group.name,
            currencyCode: route.currencyCode,
          );
        }),
        const SizedBox(height: AppSpacing.space3xl),
        Container(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          decoration: BoxDecoration(
            color: AppColors.warningBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: AppColors.warning, size: 20),
              const SizedBox(width: AppSpacing.spaceLg),
              Expanded(
                child: Text(
                  'Payments are not tracked automatically. Confirm with your group after paying.',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.space3xl),
        _buildBackButton(context),
      ],
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return OutlinedButton(
      onPressed: () => Navigator.pop(context),
      style: OutlinedButton.styleFrom(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        minimumSize: const Size(double.infinity, 0),
      ),
      child: const Text('Back to Group', style: AppTypography.button),
    );
  }
}
