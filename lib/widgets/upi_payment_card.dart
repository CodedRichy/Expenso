import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../models/money_minor.dart';
import '../models/payment_attempt.dart';
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
  bool _showQr = false;
  bool _loading = false;
  UpiAppPickerResult? _lastResult;

  String get _formattedAmount {
    final display = MoneyConversion.minorToDisplay(widget.amountMinor, widget.currencyCode);
    return display.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

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

    final apps = await UpiPaymentService.getInstalledUpiApps();

    if (!mounted) return;
    setState(() => _loading = false);

    if (apps.isEmpty) {
      setState(() => _showQr = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No UPI apps found. Scan the QR code to pay.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.onPaymentInitiated?.call();
      return;
    }

    final result = await UpiAppPicker.show(
      context: context,
      paymentData: data,
    );

    if (!mounted) return;

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
                    const Icon(Icons.check_circle, color: Colors.white, size: 20),
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
                backgroundColor: AppColors.success,
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
        ? AppColors.successBackground 
        : (isDark ? theme.colorScheme.surfaceContainerHighest : Colors.white);
    final borderColor = _isConfirmed 
        ? AppColors.success.withValues(alpha: 0.3) 
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
                            style: AppTypography.bodyPrimary.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        if (_status != PaymentAttemptStatus.notStarted)
                          _buildStatusChip(),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.spaceXs),
                    Text(
                      '₹$_formattedAmount',
                      style: AppTypography.heroTitle.copyWith(
                        fontSize: 24,
                        color: _isConfirmed ? AppColors.success : theme.colorScheme.onSurface,
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
                color: isDark ? theme.colorScheme.surfaceContainerHigh : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                widget.payeeUpiId!,
                style: AppTypography.caption.copyWith(
                  fontFamily: 'monospace',
                  fontSize: 11,
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
          if (_showQr && _paymentData != null) ...[
            const SizedBox(height: AppSpacing.spaceXl),
            _buildQrCode(),
          ],
          if (!_hasUpiId && !_isConfirmed) ...[
            const SizedBox(height: AppSpacing.spaceMd),
            Text(
              '${widget.payeeName} hasn\'t added their UPI ID yet. Ask them to update their profile.',
              style: AppTypography.caption.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
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
          color: AppColors.success.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, size: 20, color: AppColors.success),
            const SizedBox(width: AppSpacing.spaceLg),
            Expanded(
              child: Text(
                'Payment manually confirmed',
                style: AppTypography.caption.copyWith(
                  color: AppColors.success,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            IconButton(
              onPressed: () => setState(() => _lastResult = null),
              icon: const Icon(Icons.close, size: 16),
              color: AppColors.textTertiary,
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
                      color: AppColors.textTertiary,
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
            color: AppColors.textTertiary,
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
        bgColor = AppColors.warningBackground;
        textColor = AppColors.warning;
        break;
      case PaymentAttemptStatus.confirmedByPayer:
        bgColor = AppColors.successBackground;
        textColor = AppColors.success;
        break;
      case PaymentAttemptStatus.confirmedByReceiver:
        bgColor = AppColors.successBackground;
        textColor = AppColors.success;
        break;
      case PaymentAttemptStatus.disputed:
        bgColor = AppColors.errorBackground;
        textColor = AppColors.error;
        break;
      case PaymentAttemptStatus.cashPending:
        bgColor = AppColors.warningBackground;
        textColor = AppColors.warning;
        break;
      case PaymentAttemptStatus.cashConfirmed:
        bgColor = AppColors.successBackground;
        textColor = AppColors.success;
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
              Icon(Icons.check_circle, color: AppColors.success, size: 20),
              const SizedBox(width: AppSpacing.spaceSm),
              Text(
                message,
                style: AppTypography.bodySecondary.copyWith(
                  color: AppColors.success,
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
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_long, size: 12, color: AppColors.textTertiary),
                  const SizedBox(width: 4),
                  Text(
                    'Txn: ${widget.upiTransactionId}',
                    style: AppTypography.caption.copyWith(
                      fontSize: 10,
                      color: AppColors.textTertiary,
                      fontFamily: 'monospace',
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
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
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
            Icon(Icons.hourglass_empty, color: AppColors.warning, size: 20),
            const SizedBox(width: AppSpacing.spaceSm),
            Expanded(
              child: Text(
                'Waiting for ${widget.payeeName} to confirm',
                style: AppTypography.bodySecondary.copyWith(
                  color: AppColors.warning,
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
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
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
    final buttonBg = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final buttonFg = isDark ? Colors.black : Colors.white;
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
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              onPressed: () => setState(() => _showQr = !_showQr),
              icon: Icon(_showQr ? Icons.close : Icons.qr_code_2, size: 16),
              label: Text(_showQr ? 'Hide QR' : 'Show QR'),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.onSurfaceVariant,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.spaceMd,
                  vertical: AppSpacing.spaceXs,
                ),
              ),
            ),
            Container(
              width: 1,
              height: 16,
              color: theme.dividerColor,
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.spaceSm),
            ),
            TextButton.icon(
              onPressed: widget.onPaidViaCash,
              icon: const Icon(Icons.payments_outlined, size: 16),
              label: const Text('Paid via cash'),
              style: TextButton.styleFrom(
                foregroundColor: isDark ? Colors.white : const Color(0xFF1A1A1A),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.spaceMd,
                  vertical: AppSpacing.spaceXs,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCashPaymentOption() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final buttonBg = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final buttonFg = isDark ? Colors.black : Colors.white;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.spaceLg,
            vertical: AppSpacing.spaceMd,
          ),
          decoration: BoxDecoration(
            color: AppColors.warningBackground,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: AppColors.warning),
              const SizedBox(width: AppSpacing.spaceSm),
              Expanded(
                child: Text(
                  '${widget.payeeName} hasn\'t added UPI ID',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.warning,
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

  Widget _buildQrCode() {
    final data = _paymentData!;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surfaceContainerHigh : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.qr_code_scanner, size: 18, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                'Scan to pay ₹$_formattedAmount',
                style: AppTypography.bodyPrimary.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.spaceLg),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: QrImageView(
              data: data.qrData,
              version: QrVersions.auto,
              size: 200,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Colors.black,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Colors.black,
              ),
              errorStateBuilder: (context, error) => SizedBox(
                width: 200,
                height: 200,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, size: 32, color: AppColors.error),
                      const SizedBox(height: 8),
                      Text(
                        'Could not generate QR',
                        style: AppTypography.caption.copyWith(color: AppColors.error),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.spaceLg),
          Text(
            'Open any UPI app and scan this code',
            style: AppTypography.caption.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Works with GPay, PhonePe, Paytm, BHIM & more',
            style: AppTypography.captionSmall.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
