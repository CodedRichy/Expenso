import 'package:flutter/material.dart';
import '../design/colors.dart';
import '../design/typography.dart';
import '../utils/route_args.dart';
import '../utils/money_format.dart';

class PaymentResult extends StatelessWidget {
  final String status; // 'success', 'failed', 'cancelled'
  final double? amount;
  final String? transactionId;

  const PaymentResult({
    super.key,
    this.status = 'success',
    this.amount,
    this.transactionId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final group = RouteArgs.getGroup(context);
    if (group == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.of(context).maybePop());
      return const Scaffold(body: SizedBox.shrink());
    }
    final statusLabel = status == 'success'
        ? 'Payment successful'
        : status == 'failed'
            ? 'Payment failed'
            : 'Payment cancelled';
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: 320,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(
                    label: statusLabel,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: status == 'success' ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        status == 'success'
                            ? Icons.check
                            : status == 'failed'
                                ? Icons.error_outline
                                : Icons.close,
                        color: status == 'success' ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Column(
                    children: [
                      Text(
                        statusLabel,
                        textAlign: TextAlign.center,
                        style: context.screenTitle,
                      ),
                      const SizedBox(height: 12),
                      if (status == 'success' && amount != null) ...[
                        Semantics(
                          label: '${formatMoneyFromMajor(amount!, group.currencyCode)} transferred',
                          child: Text(
                            '${formatMoneyFromMajor(amount!, group.currencyCode)} transferred',
                            textAlign: TextAlign.center,
                            style: context.bodyPrimary.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ),
                        if (transactionId != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Transaction ID: $transactionId',
                            textAlign: TextAlign.center,
                            style: context.caption.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ],
                      if (status == 'failed')
                        Text(
                          'The transaction could not be completed',
                          textAlign: TextAlign.center,
                          style: context.bodyPrimary.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      if (status == 'cancelled')
                        Text(
                          'No amount was transferred',
                          textAlign: TextAlign.center,
                          style: context.bodyPrimary.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                  const SizedBox(height: 48),
                  Semantics(
                    label: status == 'success' ? 'Done' : 'Close',
                    button: true,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(
                          context,
                          '/cycle-settled',
                          arguments: group,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                        minimumSize: const Size(double.infinity, 0),
                      ),
                      child: Text(
                        status == 'success' ? 'Done' : 'Close',
                        style: AppTypography.button,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
