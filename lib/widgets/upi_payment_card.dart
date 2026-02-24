import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../models/money_minor.dart';
import '../models/payment_attempt.dart';
import '../services/upi_payment_service.dart';

class UpiPaymentCard extends StatefulWidget {
  final String payeeName;
  final String? payeeUpiId;
  final int amountMinor;
  final String groupName;
  final String currencyCode;
  final PaymentAttemptStatus? attemptStatus;
  final VoidCallback? onPaymentInitiated;
  final VoidCallback? onMarkAsPaid;

  const UpiPaymentCard({
    super.key,
    required this.payeeName,
    required this.payeeUpiId,
    required this.amountMinor,
    required this.groupName,
    this.currencyCode = 'INR',
    this.attemptStatus,
    this.onPaymentInitiated,
    this.onMarkAsPaid,
  });

  @override
  State<UpiPaymentCard> createState() => _UpiPaymentCardState();
}

class _UpiPaymentCardState extends State<UpiPaymentCard> {
  bool _showQr = false;
  bool _launching = false;

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

  Future<void> _launchUpi() async {
    final data = _paymentData;
    if (data == null) return;

    setState(() => _launching = true);

    final result = await UpiPaymentService.launchUpiPayment(data);

    if (!mounted) return;
    setState(() => _launching = false);

    switch (result) {
      case UpiLaunchResult.launched:
        widget.onPaymentInitiated?.call();
        break;
      case UpiLaunchResult.noUpiApp:
        widget.onPaymentInitiated?.call();
        setState(() => _showQr = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No UPI app found. Scan the QR code instead.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        break;
      case UpiLaunchResult.failed:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open UPI app. Try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.spaceLg),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: _isConfirmed ? AppColors.successBackground : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isConfirmed ? AppColors.success.withValues(alpha: 0.3) : AppColors.border,
        ),
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
                        color: _isConfirmed ? AppColors.success : AppColors.textPrimary,
                        decoration: _isConfirmed ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.spaceLg),
          _buildActionArea(),
          if (_showQr && _paymentData != null) ...[
            const SizedBox(height: AppSpacing.spaceXl),
            _buildQrCode(),
          ],
          if (!_hasUpiId && !_isConfirmed) ...[
            const SizedBox(height: AppSpacing.spaceMd),
            Text(
              '${widget.payeeName} hasn\'t added their UPI ID yet. Ask them to update their profile.',
              style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
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
      return Row(
        children: [
          Icon(Icons.check_circle, color: AppColors.success, size: 20),
          const SizedBox(width: AppSpacing.spaceSm),
          Text(
            _status == PaymentAttemptStatus.confirmedByReceiver
                ? 'Payment confirmed'
                : 'Marked as paid',
            style: AppTypography.bodySecondary.copyWith(
              color: AppColors.success,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    if (_showMarkAsPaid) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _launching ? null : _launchUpi,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Pay again'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.border),
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
              onPressed: widget.onMarkAsPaid,
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
      return _buildNoUpiChip();
    }

    return _buildPayButton();
  }

  Widget _buildPayButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _launching ? null : _launchUpi,
        icon: _launching
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.payment, size: 18),
        label: Text(_launching ? 'Opening...' : 'Pay via UPI'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
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
    );
  }

  Widget _buildNoUpiChip() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.spaceLg,
        vertical: AppSpacing.spaceMd,
      ),
      decoration: BoxDecoration(
        color: AppColors.warningBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'No UPI ID',
        style: AppTypography.caption.copyWith(
          color: AppColors.warning,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildQrCode() {
    final data = _paymentData!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.spaceXl),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: QrImageView(
            data: data.qrData,
            version: QrVersions.auto,
            size: 180,
            backgroundColor: Colors.white,
            errorStateBuilder: (context, error) => const Center(
              child: Text('Could not generate QR'),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.spaceLg),
        Text(
          'Scan with any UPI app to pay',
          style: AppTypography.caption.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.spaceMd),
        TextButton.icon(
          onPressed: () => setState(() => _showQr = false),
          icon: const Icon(Icons.close, size: 16),
          label: const Text('Hide QR'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }
}
