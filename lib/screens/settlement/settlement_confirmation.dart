import 'package:flutter/material.dart';
import '../../design/colors.dart';
import '../../design/spacing.dart';
import '../../design/typography.dart';
import '../../models/models.dart';
import '../../repositories/cycle_repository.dart';
import '../../services/connectivity_service.dart';
import '../../utils/route_args.dart';
import '../../utils/settlement_engine.dart';
import '../../widgets/gradient_scaffold.dart';
import '../../widgets/offline_banner.dart';
import '../../widgets/settlement_activity_feed.dart';
import '../../widgets/skeleton_placeholders.dart';
import '../../widgets/staggered_list_item.dart';
import '../../widgets/upi_payment_card.dart';
import '../../utils/money_format.dart';
import '../../widgets/tap_scale.dart';
import '../../widgets/glass_card.dart';

class SettlementConfirmation extends StatefulWidget {
  final Group? group;

  const SettlementConfirmation({super.key, this.group});

  @override
  State<SettlementConfirmation> createState() => _SettlementConfirmationState();
}

class _SettlementConfirmationState extends State<SettlementConfirmation> {
  Group? _group;
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _group = widget.group ?? RouteArgs.getGroup(context);
    if (_group != null) {
      _loadPaymentAttempts();
    } else {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => Navigator.of(context).maybePop(),
      );
    }
  }

  Future<void> _loadPaymentAttempts() async {
    if (_group == null) return;
    await CycleRepository.instance.loadPaymentAttempts(_group!.id);
    if (mounted) setState(() => _loading = false);
  }

  List<PaymentRoute> _getMyPaymentRoutes(String groupId) {
    final repo = CycleRepository.instance;
    final netBalances = repo.getNetBalancesAfterSettlementsMinor(groupId);
    final allRoutes = SettlementEngine.computePaymentRoutes(netBalances, 'INR');
    return SettlementEngine.getPaymentsForMember(repo.currentUserId, allRoutes);
  }

  List<PaymentRoute> _getReceivingRoutes(String groupId) {
    final repo = CycleRepository.instance;
    final netBalances = repo.getNetBalancesAfterSettlementsMinor(groupId);
    final allRoutes = SettlementEngine.computePaymentRoutes(netBalances, 'INR');
    return allRoutes.where((r) => r.toMemberId == repo.currentUserId).toList();
  }

  Future<void> _handleMarkAsPaid(
    PaymentRoute route, {
    String? transactionId,
    String? responseCode,
  }) async {
    if (_group == null) return;
    if (ConnectivityService.instance.isOffline) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot confirm payment while offline'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    final repo = CycleRepository.instance;

    final attempt = repo.getPaymentAttemptForRoute(
      _group!.id,
      route.fromMemberId,
      route.toMemberId,
    );

    if (attempt != null &&
        (attempt.status == PaymentAttemptStatus.initiated ||
            attempt.status == PaymentAttemptStatus.notStarted)) {
      await repo.markPaymentConfirmedByPayer(
        _group!.id,
        attempt.id,
        upiTransactionId: transactionId,
        upiResponseCode: responseCode,
      );
      // Domain rule: confirmedByPayer is NOT settled. Settlement requires the
      // receiver to independently confirm via markPaymentConfirmedByReceiver.
      // A non-null transactionId means the payer's UPI app returned a reference;
      // it does NOT mean the bank transfer completed or the receiver got funds.
      // Never auto-call markPaymentConfirmedByReceiver from the payer's device.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              transactionId != null && transactionId.isNotEmpty
                  ? 'Payment sent. Waiting for ${repo.getMemberDisplayNameById(route.toMemberId)} to confirm receipt.'
                  : 'Marked as paid. Waiting for receiver to confirm.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {});
      }
    }
  }

  Future<void> _handlePaidViaCash(PaymentRoute route) async {
    if (_group == null) return;
    if (ConnectivityService.instance.isOffline) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot record payment while offline'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    final repo = CycleRepository.instance;

    final attempt = await repo.getOrCreatePaymentAttempt(
      groupId: _group!.id,
      fromMemberId: route.fromMemberId,
      toMemberId: route.toMemberId,
      amountMinor: route.amountMinor,
      currencyCode: route.currencyCode,
    );

    if (attempt.status == PaymentAttemptStatus.notStarted ||
        attempt.status == PaymentAttemptStatus.initiated) {
      await repo.markPaymentAsCash(_group!.id, attempt.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cash payment recorded. Waiting for confirmation.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {});
      }
    }
  }

  Future<void> _handleConfirmCashReceived(PaymentRoute route) async {
    if (_group == null) return;
    if (ConnectivityService.instance.isOffline) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot confirm payment while offline'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    final repo = CycleRepository.instance;

    final attempt = repo.getPaymentAttemptForRoute(
      _group!.id,
      route.fromMemberId,
      route.toMemberId,
    );

    if (attempt != null && attempt.status == PaymentAttemptStatus.cashPending) {
      await repo.confirmCashReceived(_group!.id, attempt.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cash payment confirmed'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {});
      }
    }
  }

  PaymentAttemptStatus _getAttemptStatus(PaymentRoute route) {
    if (_group == null) return PaymentAttemptStatus.notStarted;
    final attempt = CycleRepository.instance.getPaymentAttemptForRoute(
      _group!.id,
      route.fromMemberId,
      route.toMemberId,
    );
    return attempt?.status ?? PaymentAttemptStatus.notStarted;
  }

  @override
  Widget build(BuildContext context) {
    if (_group == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final group = _group!;
    final repo = CycleRepository.instance;
    final myPaymentRoutes = _getMyPaymentRoutes(group.id);
    final receivingRoutes = _getReceivingRoutes(group.id);

    final pendingConfirmations = receivingRoutes.where((r) {
      final status = _getAttemptStatus(r);
      return status == PaymentAttemptStatus.cashPending ||
          status == PaymentAttemptStatus.confirmedByPayer;
    }).toList();

    final myTotalDue = myPaymentRoutes.fold<int>(
      0,
      (s, r) => s + r.amountMinor,
    );
    final hasUpiDues = myTotalDue > 0;

    return GradientScaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OfflineBanner(
              onRetry: () => ConnectivityService.instance.checkNow(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  TapScale(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                      ),
                      child: const Icon(Icons.chevron_left, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    group.name,
                    style: context.headingMedium.copyWith(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenPaddingH,
                      ),
                      child: Column(
                        children: const [
                          SkeletonPaymentCard(),
                          SkeletonPaymentCard(),
                          SkeletonPaymentCard(),
                        ],
                      ),
                    )
                  : ListenableBuilder(
                      listenable: repo,
                      builder: (context, _) {
                        if (!hasUpiDues && pendingConfirmations.isEmpty) {
                          return Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppSpacing.screenPaddingH,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.check_circle_outline,
                                          size: 64,
                                          color: context.colorSuccess,
                                        ),
                                        const SizedBox(height: 24),
                                        Text(
                                          'You\'re all settled!',
                                          style: context.headingLarge.copyWith(fontWeight: FontWeight.w600),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'You have no payments to make this cycle.',
                                          style: context.bodyMedium.copyWith(color: context.colorTextSecondary),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SettlementActivityFeed(
                                  groupId: group.id,
                                  maxItems: 10,
                                ),
                              ],
                            ),
                          );
                        }
                        return SingleChildScrollView(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.screenPaddingH,
                            vertical: AppSpacing.space3xl,
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (pendingConfirmations.isNotEmpty) ...[
                                  _buildPendingConfirmations(
                                    repo,
                                    pendingConfirmations,
                                  ),
                                  const SizedBox(height: AppSpacing.space4xl),
                                ],
                                _buildUpiSection(
                                  context,
                                  group,
                                  repo,
                                  myPaymentRoutes,
                                  hasUpiDues,
                                  myTotalDue,
                                  pendingIncomingCount:
                                      pendingConfirmations.length,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (!_loading) _buildBackButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingConfirmations(
    CycleRepository repo,
    List<PaymentRoute> routes,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.colorAccent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.account_balance_wallet, color: context.colorAccent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Incoming Payments',
                      style: context.labelLarge.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      '${routes.length} awaiting confirmation',
                      style: context.labelMedium.copyWith(color: context.colorTextSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...routes.asMap().entries.map((e) {
          final index = e.key;
          final route = e.value;
          final payerName = repo.getMemberDisplayNameById(route.fromMemberId);
          final status = _getAttemptStatus(route);
          final isCash = status == PaymentAttemptStatus.cashPending;
          final amountStr = formatMoneyWithCurrency(
            route.amountMinor,
            route.currencyCode,
          );
          return StaggeredListItem(
            index: index,
            child: GlassCard(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isCash
                          ? context.colorWarning.withValues(alpha: 0.1)
                          : context.colorAccent.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isCash ? Icons.payments : Icons.phone_android,
                      size: 20,
                      color: isCash ? context.colorWarning : context.colorAccent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          payerName,
                          style: context.labelLarge.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '$amountStr ${isCash ? 'cash' : 'UPI'}',
                          style: context.labelMedium.copyWith(color: context.colorTextSecondary),
                        ),
                      ],
                    ),
                  ),
                  TapScale(
                    onTap: () => isCash
                        ? _handleConfirmCashReceived(route)
                        : _handleConfirmUpiReceived(route),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: context.colorSuccess,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                      ),
                      child: Text(
                        'Confirm',
                        style: context.labelMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Future<void> _handleConfirmUpiReceived(PaymentRoute route) async {
    if (_group == null) return;
    final repo = CycleRepository.instance;

    final attempt = repo.getPaymentAttemptForRoute(
      _group!.id,
      route.fromMemberId,
      route.toMemberId,
    );

    if (attempt != null &&
        attempt.status == PaymentAttemptStatus.confirmedByPayer) {
      await repo.markPaymentConfirmedByReceiver(_group!.id, attempt.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment confirmed as received'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() {});
      }
    }
  }

  Widget _buildUpiSection(
    BuildContext context,
    Group group,
    CycleRepository repo,
    List<PaymentRoute> myRoutes,
    bool hasUpiDues,
    int totalMinor, {
    int pendingIncomingCount = 0,
  }) {
    if (!hasUpiDues) {
      final hasPendingIncoming = pendingIncomingCount > 0;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!hasPendingIncoming) ...[
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: context.colorSuccess,
            ),
            const SizedBox(height: AppSpacing.spaceXl),
            Text(
              'You\'re all settled!',
              style: context.screenTitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.spaceMd),
            Text(
              'You have no payments to make this cycle.',
              style: context.bodySecondary,
              textAlign: TextAlign.center,
            ),
          ] else ...[
            Text(
              'Confirm the payment(s) above to complete this cycle.',
              style: context.bodySecondary,
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: AppSpacing.space4xl),
          SettlementActivityFeed(groupId: group.id, maxItems: 10),
        ],
      );
    }

    final confirmedRoutes = myRoutes
        .where((r) => _getAttemptStatus(r).isSettled)
        .length;
    final allConfirmed = confirmedRoutes == myRoutes.length;

    final pendingTotal = myRoutes
        .where((r) => !_getAttemptStatus(r).isSettled)
        .fold<int>(0, (s, r) => s + r.amountMinor);

    final totalDisplay = formatMoneyWithCurrency(
      pendingTotal,
      _group?.currencyCode ?? 'INR',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Column(
            children: [
              if (allConfirmed) ...[
                Icon(Icons.check_circle, size: 56, color: context.colorSuccess),
                const SizedBox(height: 16),
                Text(
                  'All payments marked!',
                  style: context.headingLarge.copyWith(
                    color: context.colorSuccess,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ] else ...[
                Text(
                  totalDisplay,
                  style: context.displayLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: -1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  confirmedRoutes > 0
                      ? 'Remaining dues (${myRoutes.length - confirmedRoutes} of ${myRoutes.length})'
                      : 'Your total dues',
                  style: context.labelLarge.copyWith(color: context.colorTextSecondary),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.space4xl),
        Text(
          allConfirmed ? 'COMPLETED PAYMENTS' : 'PAY INDIVIDUALLY',
          style: context.labelSmall.copyWith(
            color: context.colorTextTertiary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: AppSpacing.spaceXl),
        ...myRoutes.asMap().entries.map((e) {
          final index = e.key;
          final route = e.value;
          final payeeName = repo.getMemberDisplayNameById(route.toMemberId);
          final payeeUpiId = repo.getMemberUpiId(route.toMemberId);
          final status = _getAttemptStatus(route);
          final attempt = repo.getPaymentAttemptForRoute(
            group.id,
            route.fromMemberId,
            route.toMemberId,
          );
          return StaggeredListItem(
            index: index,
            child: UpiPaymentCard(
              payeeName: payeeName,
              payeeUpiId: payeeUpiId,
              amountMinor: route.amountMinor,
              groupName: group.name,
              currencyCode: route.currencyCode,
              attemptStatus: status,
              upiTransactionId: attempt?.upiTransactionId,
              onMarkAsPaid: ({String? transactionId, String? responseCode}) =>
                  _handleMarkAsPaid(
                    route,
                    transactionId: transactionId,
                    responseCode: responseCode,
                  ),
              onPaidViaCash: () => _handlePaidViaCash(route),
              isReceiver: false,
            ),
          );
        }),
        const SizedBox(height: AppSpacing.space3xl),
        if (!allConfirmed)
          Container(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            decoration: BoxDecoration(
              color: context.colorWarningBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: context.colorWarning.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: context.colorWarning, size: 20),
                const SizedBox(width: AppSpacing.spaceLg),
                Expanded(
                  child: Text(
                    'After paying via UPI, tap "Mark as paid" to record your payment.',
                    style: context.caption.copyWith(
                      color: context.colorWarning,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.space3xl),
        SettlementActivityFeed(groupId: group.id, maxItems: 5),
      ],
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: TapScale(
        enableHaptic: true,
        onTap: () => Navigator.pop(context),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: context.colorTextPrimary,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          ),
          child: Center(
            child: Text(
              'Back to Group',
              style: context.labelLarge.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
