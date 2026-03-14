import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../models/payment_attempt.dart';
import '../utils/money_format.dart';
import '../services/upi_payment_service.dart';

class UpiPaymentCard extends StatefulWidget {
  final String payeeName;
  final String? payeeUpiId;
  final int amountMinor;
  final String groupName;
  final String currencyCode;
  final PaymentAttemptStatus? attemptStatus;
  final String? upiTransactionId;
  final void Function({String? transactionId, String? responseCode})?
  onMarkAsPaid;
  final VoidCallback? onPaidViaCash;
  final VoidCallback? onConfirmCashReceived;
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
    this.onMarkAsPaid,
    this.onPaidViaCash,
    this.onConfirmCashReceived,
    this.isReceiver = false,
  });

  @override
  State<UpiPaymentCard> createState() => _UpiPaymentCardState();
}

class _UpiPaymentCardState extends State<UpiPaymentCard> {
  bool _qrExpanded = false;
  bool _copying = false;

  String get _formattedAmount =>
      formatMoneyWithCurrency(widget.amountMinor, widget.currencyCode);

  bool get _hasUpiId =>
      widget.payeeUpiId != null && widget.payeeUpiId!.isNotEmpty;

  PaymentAttemptStatus get _status =>
      widget.attemptStatus ?? PaymentAttemptStatus.notStarted;

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

  Future<void> _copyUpiId() async {
    if (!_hasUpiId) return;
    setState(() => _copying = true);
    await Clipboard.setData(ClipboardData(text: widget.payeeUpiId!));
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) setState(() => _copying = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Copied: ${widget.payeeUpiId}'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = _isConfirmed
        ? context.colorSuccessBackground
        : (isDark
              ? theme.colorScheme.surfaceContainerHighest
              : context.colorSurface);
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
          // ── Header: name + amount + status chip ─────────────────────────
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
                        color: _isConfirmed
                            ? context.colorSuccess
                            : theme.colorScheme.onSurface,
                        decoration: _isConfirmed
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ── UPI ID + copy button ─────────────────────────────────────────
          if (_hasUpiId && !_isConfirmed) ...[
            const SizedBox(height: AppSpacing.spaceMd),
            Row(
              children: [
                Expanded(
                  child: Container(
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
                ),
                const SizedBox(width: AppSpacing.spaceSm),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _copying
                      ? Icon(
                          Icons.check,
                          key: const ValueKey('check'),
                          size: 20,
                          color: context.colorSuccess,
                        )
                      : IconButton(
                          key: const ValueKey('copy'),
                          onPressed: _copyUpiId,
                          icon: const Icon(Icons.copy, size: 18),
                          color: theme.colorScheme.onSurfaceVariant,
                          tooltip: 'Copy UPI ID',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                        ),
                ),
              ],
            ),

            /*
            // ── QR Code (expandable) ───────────────────────────────────────
            const SizedBox(height: AppSpacing.spaceSm),
            GestureDetector(
              onTap: () => setState(() => _qrExpanded = !_qrExpanded),
              child: Row(
                children: [
                  Icon(
                    Icons.qr_code_2,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.spaceXs),
                  Text(
                    _qrExpanded ? 'Hide QR code' : 'Show QR code',
                    style: context.captionSmall.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _qrExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 250),
              crossFadeState: _qrExpanded
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: _buildQrPanel(theme),
              secondChild: const SizedBox.shrink(),
            ),
            */
          ],

          // ── No UPI ID notice ─────────────────────────────────────────────
          if (!_hasUpiId && !_isConfirmed) ...[
            const SizedBox(height: AppSpacing.spaceMd),
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
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: context.colorWarning,
                  ),
                  const SizedBox(width: AppSpacing.spaceSm),
                  Expanded(
                    child: Text(
                      '${widget.payeeName} hasn\'t added their UPI ID. Pay by cash or ask them to update their profile.',
                      style: context.caption.copyWith(
                        color: context.colorWarning,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.spaceLg),
          _buildActionArea(),
        ],
      ),
    );
  }

  /*
  Widget _buildQrPanel(ThemeData theme) {
    ...
  }
  */

  Widget _buildStatusChip() {
    Color bgColor;
    Color textColor;
    final label = _status.displayLabel;

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
    // ── Fully confirmed ───────────────────────────────────────────────────
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
          if (widget.upiTransactionId != null &&
              widget.upiTransactionId!.isNotEmpty) ...[
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
                  Icon(
                    Icons.receipt_long,
                    size: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
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

    // ── Cash pending — receiver confirms ─────────────────────────────────
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
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.spaceLg),
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

    // ── Payer confirmed — waiting for receiver ────────────────────────────
    if (_status == PaymentAttemptStatus.confirmedByPayer) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.spaceLg),
        decoration: BoxDecoration(
          color: context.colorSuccessBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: context.colorSuccess.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.hourglass_bottom, color: context.colorSuccess, size: 20),
            const SizedBox(width: AppSpacing.spaceLg),
            Expanded(
              child: Text(
                'Marked as sent. Waiting for ${widget.payeeName} to confirm receipt.',
                style: context.caption.copyWith(
                  color: context.colorSuccess,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ── Disputed ─────────────────────────────────────────────────────────
    if (_status == PaymentAttemptStatus.disputed) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.spaceLg),
        decoration: BoxDecoration(
          color: context.colorErrorBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.colorError.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: context.colorError, size: 20),
            const SizedBox(width: AppSpacing.spaceLg),
            Expanded(
              child: Text(
                '${widget.payeeName} says they didn\'t receive this payment. Discuss and re-send if needed.',
                style: context.caption.copyWith(
                  color: context.colorError,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // ── Default: primary + secondary CTAs ────────────────────────────────
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_hasUpiId) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                final data = _paymentData;
                if (data != null) {
                  UpiPaymentService.launchUpi(data);
                }
              },
              icon: const Icon(Icons.bolt, size: 20),
              label: const Text('Pay with UPI app'),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colorAccent,
                foregroundColor: context.colorSurface,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
                shadowColor: context.colorAccent.withOpacity(0.3),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.spaceLg),
        ],
        // Disclaimer
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.spaceLg,
            vertical: AppSpacing.spaceMd,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Expenso can\'t verify UPI transfers. Only tap "I\'ve sent" after you\'ve confirmed the payment in your UPI app.',
            style: context.captionSmall.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.spaceMd),
        // Primary CTA
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => widget.onMarkAsPaid?.call(),
            icon: const Icon(Icons.check, size: 18),
            label: Text('I\'ve sent $_formattedAmount'),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colorSuccess,
              foregroundColor: context.colorSurface,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.spaceLg),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.spaceSm),
        // Secondary CTA
        Center(
          child: TextButton.icon(
            onPressed: widget.onPaidViaCash,
            icon: const Icon(Icons.payments_outlined, size: 16),
            label: const Text('Paid in cash'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
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
}
