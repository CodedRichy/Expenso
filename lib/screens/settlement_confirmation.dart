import 'package:flutter/material.dart';
import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../models/models.dart';
import '../models/payment_attempt.dart';
import '../repositories/cycle_repository.dart';
import '../services/connectivity_service.dart';
import '../utils/route_args.dart';
import '../utils/settlement_engine.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/offline_banner.dart';
import '../widgets/settlement_activity_feed.dart';
import '../widgets/skeleton_placeholders.dart';
import '../widgets/upi_payment_card.dart';
import '../utils/money_format.dart';

class SettlementConfirmation extends StatefulWidget {
  const SettlementConfirmation({super.key});

  @override
  State<SettlementConfirmation> createState() => _SettlementConfirmationState();
}

class _SettlementConfirmationState extends State<SettlementConfirmation> {
  Group? _group;
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _group = RouteArgs.getGroup(context);
    if (_group != null) {
      _loadPaymentAttempts();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.of(context).maybePop());
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

  Future<void> _handlePaymentInitiated(PaymentRoute route) async {
    if (_group == null) return;
    if (ConnectivityService.instance.isOffline) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot initiate payment while offline'),
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

    if (attempt.status == PaymentAttemptStatus.notStarted) {
      await repo.markPaymentInitiated(_group!.id, attempt.id);
    }

    if (mounted) setState(() {});
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

    if (attempt != null && (attempt.status == PaymentAttemptStatus.initiated || attempt.status == PaymentAttemptStatus.notStarted)) {
      await repo.markPaymentConfirmedByPayer(
        _group!.id,
        attempt.id,
        upiTransactionId: transactionId,
        upiResponseCode: responseCode,
      );
      final hasUpiSuccess = transactionId != null && transactionId.isNotEmpty;
      if (hasUpiSuccess) {
        await repo.markPaymentConfirmedByReceiver(_group!.id, attempt.id);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(hasUpiSuccess
                ? 'Payment confirmed'
                : 'Payment marked as complete. Receiver can confirm.'),
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
    final theme = Theme.of(context);
    final myPaymentRoutes = _getMyPaymentRoutes(group.id);
    final receivingRoutes = _getReceivingRoutes(group.id);
    
    final pendingConfirmations = receivingRoutes.where((r) {
      final status = _getAttemptStatus(r);
      return status == PaymentAttemptStatus.cashPending || 
             status == PaymentAttemptStatus.confirmedByPayer;
    }).toList();
    
    final myTotalDue = myPaymentRoutes.fold<int>(0, (s, r) => s + r.amountMinor);
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
                    color: theme.colorScheme.onSurface,
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
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? Padding(
                      padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenPaddingH),
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
                            padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenPaddingH),
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
                                      ],
                                    ),
                                  ),
                                ),
                                SettlementActivityFeed(groupId: group.id, maxItems: 10),
                                const SizedBox(height: AppSpacing.space4xl),
                                _buildBackButton(context),
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
                                  _buildPendingConfirmations(repo, pendingConfirmations),
                                  const SizedBox(height: AppSpacing.space4xl),
                                ],
                                _buildUpiSection(
                                  context,
                                  group,
                                  repo,
                                  myPaymentRoutes,
                                  hasUpiDues,
                                  myTotalDue,
                                  pendingIncomingCount: pendingConfirmations.length,
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

  Widget _buildPendingConfirmations(CycleRepository repo, List<PaymentRoute> routes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          decoration: BoxDecoration(
            color: context.colorAccentBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.colorAccent.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.account_balance_wallet, color: context.colorAccent, size: 24),
              const SizedBox(width: AppSpacing.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Incoming payments',
                      style: context.bodyPrimary.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${routes.length} ${routes.length == 1 ? 'payment' : 'payments'} awaiting your confirmation',
                      style: context.caption.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.spaceXl),
        ...routes.map((route) {
          final payerName = repo.getMemberDisplayNameById(route.fromMemberId);
          final status = _getAttemptStatus(route);
          final isCash = status == PaymentAttemptStatus.cashPending;
          final amountStr = formatMoneyWithCurrency(route.amountMinor, route.currencyCode);
          return Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.spaceMd),
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isCash 
                        ? context.colorWarningBackground 
                        : context.colorAccentBackground,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isCash ? Icons.payments : Icons.phone_android,
                    size: 20,
                    color: isCash ? context.colorWarning : context.colorAccent,
                  ),
                ),
                const SizedBox(width: AppSpacing.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        payerName,
                        style: context.bodyPrimary.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${amountStr} ${isCash ? 'cash' : 'UPI'} payment',
                        style: context.bodySecondary,
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () => isCash 
                      ? _handleConfirmCashReceived(route) 
                      : _handleConfirmUpiReceived(route),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colorSuccess,
                    foregroundColor: context.colorSurface,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.spaceLg,
                      vertical: AppSpacing.spaceMd,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: const Text('Confirm'),
                ),
              ],
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

    if (attempt != null && attempt.status == PaymentAttemptStatus.confirmedByPayer) {
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
          const SizedBox(height: AppSpacing.space4xl),
          _buildBackButton(context),
        ],
      );
    }

    final confirmedRoutes = myRoutes.where((r) => _getAttemptStatus(r).isSettled).length;
    final allConfirmed = confirmedRoutes == myRoutes.length;

    final pendingTotal = myRoutes
        .where((r) => !_getAttemptStatus(r).isSettled)
        .fold<int>(0, (s, r) => s + r.amountMinor);

    final totalDisplay = formatMoneyWithCurrency(pendingTotal, _group?.currencyCode ?? 'INR');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Column(
            children: [
              if (allConfirmed) ...[
                Icon(
                  Icons.check_circle,
                  size: 48,
                  color: context.colorSuccess,
                ),
                const SizedBox(height: AppSpacing.spaceLg),
                Text(
                  'All payments marked!',
                  style: context.screenTitle.copyWith(
                    color: context.colorSuccess,
                  ),
                ),
              ] else ...[
                Text(
                  totalDisplay,
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                    letterSpacing: -1.2,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: AppSpacing.spaceMd),
                Text(
                  confirmedRoutes > 0
                      ? 'Remaining dues (${myRoutes.length - confirmedRoutes} of ${myRoutes.length})'
                      : 'Your total dues',
                  style: context.bodySecondary,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.space4xl),
        Text(
          allConfirmed ? 'COMPLETED PAYMENTS' : 'PAY INDIVIDUALLY',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: AppSpacing.spaceXl),
        ...myRoutes.map((route) {
          final payeeName = repo.getMemberDisplayNameById(route.toMemberId);
          final payeeUpiId = repo.getMemberUpiId(route.toMemberId);
          final status = _getAttemptStatus(route);
          final attempt = repo.getPaymentAttemptForRoute(
            group.id,
            route.fromMemberId,
            route.toMemberId,
          );
          return UpiPaymentCard(
            payeeName: payeeName,
            payeeUpiId: payeeUpiId,
            amountMinor: route.amountMinor,
            groupName: group.name,
            currencyCode: route.currencyCode,
            attemptStatus: status,
            upiTransactionId: attempt?.upiTransactionId,
            onPaymentInitiated: () => _handlePaymentInitiated(route),
            onMarkAsPaid: ({String? transactionId, String? responseCode}) =>
                _handleMarkAsPaid(route, transactionId: transactionId, responseCode: responseCode),
            onPaidViaCash: () => _handlePaidViaCash(route),
            isReceiver: false,
          );
        }),
        const SizedBox(height: AppSpacing.space3xl),
        if (!allConfirmed)
          Container(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            decoration: BoxDecoration(
              color: context.colorWarningBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.colorWarning.withValues(alpha: 0.3)),
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
        const SizedBox(height: AppSpacing.space3xl),
        _buildBackButton(context),
      ],
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return ElevatedButton(
      onPressed: () => Navigator.pop(context),
      style: ElevatedButton.styleFrom(
        backgroundColor: context.colorSurface,
        foregroundColor: context.colorTextPrimary,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        minimumSize: const Size(double.infinity, 0),
        elevation: 0,
      ),
      child: Text('Back to Group', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: context.colorTextPrimary)),
    );
  }
}
