import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../design/colors.dart';
import '../design/typography.dart';
import '../models/models.dart';
import '../utils/money_format.dart';
import '../services/locale_service.dart';
import '../widgets/tap_scale.dart';
import './cycle_settled_sheet.dart';

class PaymentResultSheet extends StatefulWidget {
  final Group group;
  final String status;
  final double? amount;
  final String? transactionId;

  const PaymentResultSheet({
    super.key,
    required this.group,
    this.status = 'success',
    this.amount,
    this.transactionId,
  });

  static Future<void> show(
    BuildContext context, {
    required Group group,
    String status = 'success',
    double? amount,
    String? transactionId,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => PaymentResultSheet(
        group: group,
        status: status,
        amount: amount,
        transactionId: transactionId,
      ),
    );
  }

  @override
  State<PaymentResultSheet> createState() => _PaymentResultSheetState();
}

class _PaymentResultSheetState extends State<PaymentResultSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));
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
    final isSuccess = widget.status == 'success';
    final isFailed = widget.status == 'failed';
    
    final statusLabel = isSuccess
        ? 'Payment Successful'
        : isFailed
        ? 'Payment Failed'
        : 'Payment Cancelled';

    final statusIcon = isSuccess
        ? Icons.check_rounded
        : isFailed
        ? Icons.error_outline_rounded
        : Icons.close_rounded;

    final statusColor = isSuccess
        ? context.colorPrimary
        : isFailed
        ? context.colorError
        : context.colorTextSecondary;

    return Container(
      decoration: BoxDecoration(
        color: context.colorSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 12,
        bottom: 24 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: context.colorBorder.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
          const SizedBox(height: 48),
          
          // Animated Status Icon
          ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: statusColor.withValues(alpha: 0.2),
                  width: 2,
                ),
              ),
              child: Center(
                child: Icon(
                  statusIcon,
                  color: statusColor,
                  size: 40,
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          
          Text(
            statusLabel,
            textAlign: TextAlign.center,
            style: context.subheader.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 22,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          
          if (isSuccess && widget.amount != null) ...[
            Text(
              formatMoneyFromMajor(
                widget.amount!,
                widget.group.currencyCode,
                LocaleService.instance.localeCode,
              ),
              textAlign: TextAlign.center,
              style: context.amountSM.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Transferred Successfully',
              textAlign: TextAlign.center,
              style: context.bodySecondary,
            ),
            if (widget.transactionId != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: context.colorBorder.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'ID: ${widget.transactionId}',
                  style: context.caption.copyWith(
                    fontFamily: 'JetBrainsMono',
                    color: context.colorTextSecondary,
                  ),
                ),
              ),
            ],
          ] else if (isFailed) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'The transaction could not be completed. Please try again or check your payment source.',
                textAlign: TextAlign.center,
                style: context.bodySecondary.copyWith(height: 1.5),
              ),
            ),
          ] else ...[
            Text(
              'No amount was transferred.',
              textAlign: TextAlign.center,
              style: context.bodySecondary,
            ),
          ],
          
          const SizedBox(height: 48),
          
          TapScale(
            onTap: () {
              HapticFeedback.mediumImpact();
              Navigator.pop(context);
              if (isSuccess) {
                // Show the settled sheet after short delay if successful
                Future.delayed(const Duration(milliseconds: 300), () {
                  if (!mounted) return;
                  CycleSettledSheet.show(context, group: widget.group);
                });
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: isSuccess ? context.colorPrimary : context.colorSurface,
                border: isSuccess ? null : Border.all(color: context.colorBorder),
                borderRadius: BorderRadius.circular(16),
                boxShadow: isSuccess ? [
                  BoxShadow(
                    color: context.colorPrimary.withValues(alpha: 0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ] : null,
              ),
              child: Center(
                child: Text(
                  isSuccess ? 'Done' : 'Close',
                  style: TextStyle(
                    color: isSuccess ? Colors.white : context.colorTextPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

}
