import 'dart:async';
import 'package:flutter/material.dart';
import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../utils/money_format.dart';
import '../services/upi_payment_service.dart';

enum PaymentWaitingState {
  waiting,
  success,
  failure,
  pending,
  cancelled,
}

class UpiPaymentWaitingOverlay extends StatefulWidget {
  final String payeeName;
  final int amountMinor;
  final String currencyCode;
  final String appName;
  final Future<UpiTransactionResult> transactionFuture;
  final VoidCallback onRetry;
  final VoidCallback onManualConfirm;
  final VoidCallback onCancel;

  const UpiPaymentWaitingOverlay({
    super.key,
    required this.payeeName,
    required this.amountMinor,
    this.currencyCode = 'INR',
    required this.appName,
    required this.transactionFuture,
    required this.onRetry,
    required this.onManualConfirm,
    required this.onCancel,
  });

  @override
  State<UpiPaymentWaitingOverlay> createState() => _UpiPaymentWaitingOverlayState();
}

class _UpiPaymentWaitingOverlayState extends State<UpiPaymentWaitingOverlay>
    with SingleTickerProviderStateMixin {
  PaymentWaitingState _state = PaymentWaitingState.waiting;
  UpiTransactionResult? _result;
  int _secondsRemaining = 90;
  Timer? _timer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  String get _formattedAmount =>
      formatMoneyWithCurrency(widget.amountMinor, widget.currencyCode);

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startTimer();
    _listenToTransaction();
  }

  void _setupAnimations() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _timer?.cancel();
        if (_state == PaymentWaitingState.waiting) {
          setState(() => _state = PaymentWaitingState.pending);
        }
      }
    });
  }

  Future<void> _listenToTransaction() async {
    try {
      final result = await widget.transactionFuture;
      if (!mounted) return;

      _timer?.cancel();
      _result = result;

      setState(() {
        switch (result.status) {
          case UpiTransactionStatus.success:
            _state = PaymentWaitingState.success;
            break;
          case UpiTransactionStatus.failure:
            // Many UPI apps (including GPay) return 'failure' for transactions
            // that settled asynchronously. Show a non-definitive state and let
            // the user verify in their UPI app before deciding what to do.
            _state = PaymentWaitingState.failure;
            break;
          case UpiTransactionStatus.submitted:
            _state = PaymentWaitingState.pending;
            break;
          case UpiTransactionStatus.cancelled:
            _state = PaymentWaitingState.cancelled;
            break;
          case UpiTransactionStatus.unknown:
            // Unknown = the app returned before the transaction resolved.
            // Treat as pending so the user can self-confirm.
            _state = PaymentWaitingState.pending;
            break;
        }
      });
    } catch (e) {
      if (mounted) {
        // Exception thrown by the UPI plugin — treat as pending, not hard failure,
        // because the user may have completed payment in the external app.
        setState(() => _state = PaymentWaitingState.pending);
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPaddingH),
          child: Column(
            children: [
              const Spacer(flex: 2),
              _buildMainContent(),
              const Spacer(flex: 1),
              _buildActions(),
              const SizedBox(height: AppSpacing.space3xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    switch (_state) {
      case PaymentWaitingState.waiting:
        return _buildWaitingState();
      case PaymentWaitingState.success:
        return _buildSuccessState();
      case PaymentWaitingState.failure:
        return _buildFailureState();
      case PaymentWaitingState.pending:
        return _buildPendingState();
      case PaymentWaitingState.cancelled:
        return _buildCancelledState();
    }
  }

  Widget _buildWaitingState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) => Transform.scale(
            scale: _pulseAnimation.value,
            child: child,
          ),
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.space3xl),
        Text(
          'Waiting for payment...',
          style: AppTypography.screenTitle.copyWith(
            color: Colors.white,
            fontSize: 22,
          ),
        ),
        const SizedBox(height: AppSpacing.spaceLg),
        Text(
          'Complete payment in ${widget.appName}',
          style: AppTypography.bodySecondary.copyWith(
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: AppSpacing.space3xl),
        _buildAmountCard(),
        const SizedBox(height: AppSpacing.space3xl),
        _buildTimer(),
      ],
    );
  }

  Widget _buildSuccessState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: context.colorSuccess,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check,
            size: 56,
            color: context.colorSurface,
          ),
        ),
        const SizedBox(height: AppSpacing.space3xl),
        Text(
          'Payment Successful!',
          style: AppTypography.screenTitle.copyWith(
            color: Colors.white,
            fontSize: 22,
          ),
        ),
        const SizedBox(height: AppSpacing.spaceLg),
        Text(
          '$_formattedAmount paid to ${widget.payeeName}',
          style: AppTypography.bodySecondary.copyWith(
            color: Colors.white70,
          ),
        ),
        if (_result?.transactionId != null) ...[
          const SizedBox(height: AppSpacing.spaceXl),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.spaceLg,
              vertical: AppSpacing.spaceMd,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Txn ID: ${_result!.transactionId}',
              style: AppTypography.caption.copyWith(
                color: Colors.white60,
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFailureState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: context.colorWarning.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.warning_amber_rounded,
            size: 56,
            color: context.colorWarning,
          ),
        ),
        const SizedBox(height: AppSpacing.space3xl),
        Text(
          'Payment May Have Failed',
          style: AppTypography.screenTitle.copyWith(
            color: Colors.white,
            fontSize: 22,
          ),
        ),
        const SizedBox(height: AppSpacing.spaceLg),
        Text(
          'The UPI app reported an error, but your bank may\nhave processed the payment. Check your UPI app\nbefore trying again to avoid a duplicate charge.',
          style: AppTypography.bodySecondary.copyWith(
            color: Colors.white70,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPendingState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.hourglass_bottom,
            size: 48,
            color: AppColors.warning,
          ),
        ),
        const SizedBox(height: AppSpacing.space3xl),
        Text(
          'Payment Pending',
          style: AppTypography.screenTitle.copyWith(
            color: Colors.white,
            fontSize: 22,
          ),
        ),
        const SizedBox(height: AppSpacing.spaceLg),
        Text(
          'Your payment is being processed.\nPlease check your UPI app for status.',
          style: AppTypography.bodySecondary.copyWith(
            color: Colors.white70,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.space3xl),
        _buildAmountCard(),
      ],
    );
  }

  Widget _buildCancelledState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.cancel_outlined,
            size: 48,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: AppSpacing.space3xl),
        Text(
          'Payment Cancelled',
          style: AppTypography.screenTitle.copyWith(
            color: Colors.white,
            fontSize: 22,
          ),
        ),
        const SizedBox(height: AppSpacing.spaceLg),
        Text(
          'You cancelled the payment.\nTry again when ready.',
          style: AppTypography.bodySecondary.copyWith(
            color: Colors.white70,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildAmountCard() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.space3xl,
        vertical: AppSpacing.spaceXl,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        children: [
          Text(
            _formattedAmount,
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: AppSpacing.spaceXs),
          Text(
            'to ${widget.payeeName}',
            style: AppTypography.bodySecondary.copyWith(
              color: Colors.white60,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimer() {
    final minutes = _secondsRemaining ~/ 60;
    final seconds = _secondsRemaining % 60;
    final timeStr = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Column(
      children: [
        Text(
          timeStr,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w300,
            color: _secondsRemaining < 30 ? AppColors.warning : Colors.white54,
            fontFamily: 'monospace',
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: AppSpacing.spaceSm),
        Text(
          'Time remaining',
          style: AppTypography.caption.copyWith(
            color: Colors.white38,
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    switch (_state) {
      case PaymentWaitingState.waiting:
        return _buildWaitingActions();
      case PaymentWaitingState.success:
        return _buildSuccessActions();
      case PaymentWaitingState.failure:
      case PaymentWaitingState.cancelled:
        return _buildFailureActions();
      case PaymentWaitingState.pending:
        return _buildPendingActions();
    }
  }

  Widget _buildWaitingActions() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: widget.onManualConfirm,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('I\'ve already paid'),
          ),
        ),
        const SizedBox(height: AppSpacing.spaceLg),
        TextButton(
          onPressed: widget.onCancel,
          child: Text(
            'Cancel',
            style: AppTypography.bodySecondary.copyWith(
              color: context.colorTextSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessActions() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: widget.onManualConfirm,
        style: ElevatedButton.styleFrom(
          backgroundColor: context.colorSuccess,
          foregroundColor: context.colorSurface,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 0,
        ),
        child: const Text('Done'),
      ),
    );
  }

  Widget _buildFailureActions() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: widget.onManualConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colorSuccess,
              foregroundColor: context.colorSurface,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: const Text('I\'ve completed payment'),
          ),
        ),
        const SizedBox(height: AppSpacing.spaceLg),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: widget.onRetry,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Try Again'),
          ),
        ),
        const SizedBox(height: AppSpacing.spaceLg),
        TextButton(
          onPressed: widget.onCancel,
          child: Text(
            'Cancel',
            style: AppTypography.bodySecondary.copyWith(
              color: Colors.white54,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPendingActions() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: widget.onManualConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colorSuccess,
              foregroundColor: context.colorSurface,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: const Text('I\'ve completed payment'),
          ),
        ),
        const SizedBox(height: AppSpacing.spaceLg),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: widget.onRetry,
            style: OutlinedButton.styleFrom(
              foregroundColor: context.colorTextPrimary,
              side: BorderSide(color: context.colorBorder),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Retry Payment'),
          ),
        ),
        const SizedBox(height: AppSpacing.spaceLg),
        TextButton(
          onPressed: widget.onCancel,
          child: Text(
            'Cancel',
            style: AppTypography.bodySecondary.copyWith(
              color: context.colorTextSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
