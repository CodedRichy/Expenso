import 'package:flutter/material.dart';
import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../models/money_minor.dart';
import '../models/payment_attempt.dart';
import '../utils/money_format.dart';
import '../services/upi_payment_service.dart';
import 'upi_app_picker.dart';

class UpiPaymentCard extends StatefulWidget {
  final String payeeName;
  final String? payeeUpiId;
  final int amountMinor;
  final String groupName;
  final String currencyCode;
  final PaymentAttemptStatus? attemptStatus;
  final String? upiTransactionId;
  final VoidCallback? onPaymentInitiated;
  final void Function({String? transactionId, String? responseCode})? onMarkAsPaid;
  final VoidCallback? onPaidViaCash;
  final VoidCallback? onConfirmCashReceived;
  final Function(UpiTransactionResult result)? onPaymentResult;
  final bool isReceiver;

  const UpiPaymentCard({
    super.key,
    required this.payeeName,
    required this.payeeUpiId,
    required this.amountMinor,
    required this.groupName,
    this.currencyCode = 'INR',
    this.attemptStatus,
    this.upiTransactionId,
    this.onPaymentInitiated,
    this.onMarkAsPaid,
    this.onPaidViaCash,
    this.onConfirmCashReceived,
    this.onPaymentResult,
    this.isReceiver = false,
  });

  @override
  State<UpiPaymentCard> createState() => _UpiPaymentCardState();
}

class _UpiPaymentCardState extends State<UpiPaymentCard> {
  bool _loading = false;
  UpiAppPickerResult? _lastResult;

  String get _formattedAmount =>
      formatMoneyWithCurrency(widget.amountMinor, widget.currencyCode);

  bool get _hasUpiId => widget.payeeUpiId != null && widget.payeeUpiId!.isNotEmpty;

  PaymentAttemptStatus get _status => widget.attemptStatus ?? PaymentAttemptStatus.notStarted;

  bool get _showMarkAsPaid => _status == PaymentAttemptStatus.initiated;
  bool get _isConfirmed => _status.isSettled;

  UpiPaymentData? get _paymentData {
    if (!_hasUpiId) return null;
    return UpiPaymentService.createPaymentData(
      payeeUpiId: widget.payeeUpiId!,
      payeeName: widget.payeeName,
      amountMinor: widget.amountMinor,
      groupName: widget.groupName,
      currencyCode: widget.currencyCode,
    );
  }

  Future<void> _showUpiAppPicker() async {
    final data = _paymentData;
    if (data == null) return;

    setState(() => _loading = true);

    final result = await UpiAppPicker.show(
      context: context,
      paymentData: data,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (result != null) {
      setState(() => _lastResult = result);
      widget.onPaymentInitiated?.call();

      if (result.transactionResult != null) {
        widget.onPaymentResult?.call(result.transactionResult!);

        final txn = result.transactionResult!;
        if (txn.isSuccess) {
          widget.onMarkAsPaid?.call(
            transactionId: txn.transactionId,
            responseCode: txn.responseCode,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: context.colorSurface, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        txn.transactionId != null
                            ? 'Payment confirmed (Txn: ${txn.transactionId})'
                            : 'Payment confirmed',
                      ),
                    ),
                  ],
                ),
                backgroundColor: context.colorSuccess,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      } else if (result.manuallyConfirmed) {
        widget.onMarkAsPaid?.call();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = _isConfirmed 
        ? context.colorSuccessBackground 
        : (isDark ? theme.colorScheme.surfaceContainerHighest : context.colorSurface);
    final borderColor = _isConfirmed 
        ? context.colorSuccess.withValues(alpha: 0.3) 
        : theme.dividerColor;
    
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.spaceLg),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Pay ${widget.payeeName}',
                            style: context.listItemTitle.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (_status != PaymentAttemptStatus.notStarted)
                          _buildStatusChip(),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.spaceXs),
                    Text(
                      _formattedAmount,
                      style: context.amountMD.copyWith(
                        color: _isConfirmed ? context.colorSuccess : theme.colorScheme.onSurface,
                        decoration: _isConfirmed ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_hasUpiId && !_isConfirmed) ...[
            const SizedBox(height: AppSpacing.spaceSm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.spaceMd,
                vertical: AppSpacing.spaceXs,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.payeeUpiId!,
                style: context.captionSmall.copyWith(
                  fontFamily: 'monospace',
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.spaceLg),
          _buildActionArea(),
          if (_lastResult != null && !_isConfirmed) ...[
            const SizedBox(height: AppSpacing.spaceLg),
            _buildLastResultBanner(),
          ],
          if (!_hasUpiId && !_isConfirmed) ...[
            const SizedBox(height: AppSpacing.spaceMd),
            Text(
              '${widget.payeeName} hasn\'t added their UPI ID yet. Ask them to update their profile.',
              style: context.caption,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLastResultBanner() {
    final pickerResult = _lastResult!;
    
    if (pickerResult.manuallyConfirmed) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.spaceLg),
        decoration: BoxDecoration(
          color: context.colorSuccess.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.colorSuccess.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, size: 20, color: context.colorSuccess),
            const SizedBox(width: AppSpacing.spaceLg),
            Expanded(
              child: Text(
                'Payment manually confirmed',
                style: AppTypography.caption.copyWith(
                  color: context.colorSuccess,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            IconButton(
              onPressed: () => setState(() => _lastResult = null),
              icon: const Icon(Icons.close, size: 16),
              color: context.colorTextTertiary,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      );
    }

    final txnResult = pickerResult.transactionResult;
    if (txnResult == null) return const SizedBox.shrink();
    
    final color = UpiPaymentService.getStatusColor(txnResult);
    final icon = UpiPaymentService.getStatusIcon(txnResult);
    final message = UpiPaymentService.getStatusMessage(txnResult);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.spaceLg),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: AppSpacing.spaceLg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: AppTypography.caption.copyWith(
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (txnResult.transactionId != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Txn: ${txnResult.transactionId}',
                    style: AppTypography.caption.copyWith(
                      fontSize: 10,
                      color: context.colorTextTertiary,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _lastResult = null),
            icon: const Icon(Icons.close, size: 16),
                      color: context.colorTextTertiary,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip() {
    Color bgColor;
    Color textColor;
    String label = _status.displayLabel;

    switch (_status) {
      case PaymentAttemptStatus.initiated:
        bgColor = context.colorWarningBackground;
        textColor = context.colorWarning;
        break;
      case PaymentAttemptStatus.confirmedByPayer:
        bgColor = context.colorSuccessBackground;
        textColor = context.colorSuccess;
        break;
      case PaymentAttemptStatus.confirmedByReceiver:
        bgColor = context.colorSuccessBackground;
        textColor = context.colorSuccess;
        break;
      case PaymentAttemptStatus.disputed:
        bgColor = context.colorErrorBackground;
        textColor = context.colorError;
        break;
      case PaymentAttemptStatus.cashPending:
        bgColor = context.colorWarningBackground;
        textColor = context.colorWarning;
        break;
      case PaymentAttemptStatus.cashConfirmed:
        bgColor = context.colorSuccessBackground;
        textColor = context.colorSuccess;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.spaceMd,
        vertical: AppSpacing.spaceXs,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: textColor,
          fontWeight: FontWeight.w500,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildActionArea() {
    if (_isConfirmed) {
      String message;
      if (_status == PaymentAttemptStatus.cashConfirmed) {
        message = 'Cash received';
      } else if (_status == PaymentAttemptStatus.confirmedByReceiver) {
        message = 'Payment confirmed';
      } else {
        message = 'Marked as paid';
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: context.colorSuccess, size: 20),
              const SizedBox(width: AppSpacing.spaceSm),
              Text(
                message,
                style: context.bodySecondary.copyWith(
                  color: context.colorSuccess,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (widget.upiTransactionId != null && widget.upiTransactionId!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.spaceSm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.spaceMd,
                vertical: AppSpacing.spaceXs,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_long, size: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: AppSpacing.spaceXs),
                  Text(
                    'Txn: ${widget.upiTransactionId}',
                    style: context.captionSmall.copyWith(
                      fontFamily: 'monospace',
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    }

    if (_status.isCashPending) {
      if (widget.isReceiver) {
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: widget.onConfirmCashReceived,
            icon: const Icon(Icons.payments, size: 18),
            label: const Text('Confirm cash received'),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colorSuccess,
              foregroundColor: context.colorSurface,
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.spaceLg,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
          ),
        );
      } else {
        return Row(
          children: [
            Icon(Icons.hourglass_empty, color: context.colorWarning, size: 20),
            const SizedBox(width: AppSpacing.spaceSm),
            Expanded(
              child: Text(
                'Waiting for ${widget.payeeName} to confirm',
                style: context.bodySecondary.copyWith(
                  color: context.colorWarning,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );
      }
    }

    if (_showMarkAsPaid) {
      final theme = Theme.of(context);
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _loading ? null : _showUpiAppPicker,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Pay again'),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.onSurfaceVariant,
                side: BorderSide(color: theme.dividerColor),
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.spaceLg,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.spaceMd),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => widget.onMarkAsPaid?.call(),
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Mark as paid'),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colorSuccess,
                foregroundColor: context.colorSurface,
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.spaceLg,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      );
    }

    if (!_hasUpiId) {
      return _buildCashPaymentOption();
    }

    return _buildPayButton();
  }

  Widget _buildPayButton() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final buttonBg = context.colorSurface;
    final buttonFg = context.colorTextPrimary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _loading ? null : _showUpiAppPicker,
            icon: _loading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: buttonFg,
                    ),
                  )
                : const Icon(Icons.payment, size: 18),
            label: Text(_loading ? 'Loading...' : 'Pay via UPI'),
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonBg,
              foregroundColor: buttonFg,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.spaceXl,
                vertical: AppSpacing.spaceLg,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.spaceMd),
        Center(
          child: TextButton.icon(
            onPressed: widget.onPaidViaCash,
            icon: const Icon(Icons.payments_outlined, size: 16),
            label: const Text('Paid via cash'),
            style: TextButton.styleFrom(
              foregroundColor: context.colorTextPrimary,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.spaceMd,
                vertical: AppSpacing.spaceXs,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCashPaymentOption() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final buttonBg = context.colorSurface;
    final buttonFg = context.colorTextPrimary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.spaceLg,
            vertical: AppSpacing.spaceMd,
          ),
          decoration: BoxDecoration(
            color: context.colorWarningBackground,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: context.colorWarning),
              const SizedBox(width: AppSpacing.spaceSm),
              Expanded(
                child: Text(
                  '${widget.payeeName} hasn\'t added UPI ID',
                  style: context.caption.copyWith(
                    color: context.colorWarning,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.spaceMd),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: widget.onPaidViaCash,
            icon: const Icon(Icons.payments_outlined, size: 18),
            label: const Text('Paid via cash'),
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonBg,
              foregroundColor: buttonFg,
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.spaceLg,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }
}
