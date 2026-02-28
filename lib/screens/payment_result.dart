import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../design/typography.dart';
import '../models/models.dart';
import '../utils/route_args.dart';
import '../utils/money_format.dart';

class PaymentResult extends StatefulWidget {
  final Group? group;
  final String status;
  final double? amount;
  final String? transactionId;

  const PaymentResult({
    super.key,
    this.group,
    this.status = 'success',
    this.amount,
    this.transactionId,
  });

  @override
  State<PaymentResult> createState() => _PaymentResultState();
}

class _PaymentResultState extends State<PaymentResult> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final group = widget.group ?? RouteArgs.getGroup(context);
    if (group == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.of(context).maybePop());
      return const Scaffold(body: SizedBox.shrink());
    }
    final statusLabel = widget.status == 'success'
        ? 'Payment successful'
        : widget.status == 'failed'
            ? 'Payment failed'
            : 'Payment cancelled';
    final isSuccess = widget.status == 'success';

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
                    child: ScaleTransition(
                      scale: isSuccess ? _scaleAnimation : const AlwaysStoppedAnimation(1.0),
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: isSuccess ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isSuccess
                              ? Icons.check
                              : widget.status == 'failed'
                                  ? Icons.error_outline
                                  : Icons.close,
                          color: isSuccess ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
                          size: 32,
                        ),
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
                      if (isSuccess && widget.amount != null) ...[
                        Semantics(
                          label: '${formatMoneyFromMajor(widget.amount!, group.currencyCode)} transferred',
                          child: Text(
                            '${formatMoneyFromMajor(widget.amount!, group.currencyCode)} transferred',
                            textAlign: TextAlign.center,
                            style: context.bodyPrimary.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ),
                        if (widget.transactionId != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Transaction ID: ${widget.transactionId}',
                            textAlign: TextAlign.center,
                            style: context.caption.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ],
                      if (widget.status == 'failed')
                        Text(
                          'The transaction could not be completed',
                          textAlign: TextAlign.center,
                          style: context.bodyPrimary.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      if (widget.status == 'cancelled')
                        Text(
                          'No amount was transferred',
                          textAlign: TextAlign.center,
                          style: context.bodyPrimary.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                  const SizedBox(height: 48),
                  Semantics(
                    label: isSuccess ? 'Done' : 'Close',
                    button: true,
                    child: ElevatedButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
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
                        isSuccess ? 'Done' : 'Close',
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
