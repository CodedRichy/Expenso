import 'package:flutter/material.dart';
import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../services/upi_payment_service.dart';

class UpiAppPicker extends StatefulWidget {
  final UpiPaymentData paymentData;
  final Function(UpiAppInfo app, UpiTransactionResult result) onPaymentComplete;
  final VoidCallback? onCancel;

  const UpiAppPicker({
    super.key,
    required this.paymentData,
    required this.onPaymentComplete,
    this.onCancel,
  });

  static Future<UpiTransactionResult?> show({
    required BuildContext context,
    required UpiPaymentData paymentData,
  }) {
    return showModalBottomSheet<UpiTransactionResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _UpiAppPickerSheet(paymentData: paymentData),
    );
  }

  @override
  State<UpiAppPicker> createState() => _UpiAppPickerState();
}

class _UpiAppPickerState extends State<UpiAppPicker> {
  List<UpiAppInfo>? _apps;
  bool _loading = true;
  String? _error;
  UpiAppInfo? _processingApp;

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  Future<void> _loadApps() async {
    try {
      final apps = await UpiPaymentService.getInstalledUpiApps();
      if (mounted) {
        setState(() {
          _apps = apps;
          _loading = false;
          _error = apps.isEmpty ? 'No UPI apps found on this device' : null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load UPI apps';
        });
      }
    }
  }

  Future<void> _onAppTap(UpiAppInfo appInfo) async {
    setState(() => _processingApp = appInfo);

    final result = await UpiPaymentService.initiateTransaction(
      data: widget.paymentData,
      appInfo: appInfo,
    );

    if (mounted) {
      setState(() => _processingApp = null);
      widget.onPaymentComplete(appInfo, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.space3xl),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return _buildError();
    }

    return _buildAppGrid();
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.space3xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.account_balance_wallet_outlined,
            size: 48,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: AppSpacing.spaceXl),
          Text(
            _error!,
            style: AppTypography.bodyPrimary,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.spaceMd),
          Text(
            'Install a UPI app like Google Pay, PhonePe, or Paytm to make payments.',
            style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.spaceXl),
          TextButton(
            onPressed: widget.onCancel,
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildAppGrid() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPaddingH,
            vertical: AppSpacing.spaceLg,
          ),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: AppSpacing.spaceLg,
            crossAxisSpacing: AppSpacing.spaceLg,
            childAspectRatio: 0.85,
          ),
          itemCount: _apps!.length,
          itemBuilder: (context, index) => _buildAppTile(_apps![index]),
        ),
      ],
    );
  }

  Widget _buildAppTile(UpiAppInfo appInfo) {
    final isProcessing = _processingApp == appInfo;
    final isDisabled = _processingApp != null && !isProcessing;

    return GestureDetector(
      onTap: isDisabled ? null : () => _onAppTap(appInfo),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: isDisabled ? 0.4 : 1.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: isProcessing
                    ? const Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : Image.memory(
                        appInfo.icon,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.account_balance_wallet,
                          color: AppColors.textTertiary,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: AppSpacing.spaceSm),
            Text(
              _formatAppName(appInfo.name),
              style: AppTypography.caption.copyWith(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _formatAppName(String name) {
    if (name.length > 10) {
      return name.split(' ').first;
    }
    return name;
  }
}

class _UpiAppPickerSheet extends StatefulWidget {
  final UpiPaymentData paymentData;

  const _UpiAppPickerSheet({required this.paymentData});

  @override
  State<_UpiAppPickerSheet> createState() => _UpiAppPickerSheetState();
}

class _UpiAppPickerSheetState extends State<_UpiAppPickerSheet> {
  UpiTransactionResult? _result;

  void _handlePaymentComplete(UpiAppInfo app, UpiTransactionResult result) {
    setState(() => _result = result);

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        Navigator.of(context).pop(result);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppSpacing.spaceMd),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppSpacing.spaceXl),
          if (_result != null)
            _buildResultView()
          else
            _buildPaymentView(),
        ],
      ),
    );
  }

  Widget _buildPaymentView() {
    final amount = (widget.paymentData.amountMinor / 100).toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPaddingH),
          child: Column(
            children: [
              Text(
                'Pay ₹$amount',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.spaceXs),
              Text(
                'to ${widget.paymentData.payeeName}',
                style: AppTypography.bodySecondary,
              ),
              const SizedBox(height: AppSpacing.spaceSm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.spaceLg,
                  vertical: AppSpacing.spaceXs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  widget.paymentData.payeeUpiId,
                  style: AppTypography.caption.copyWith(
                    fontFamily: 'monospace',
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.space3xl),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPaddingH),
          child: Row(
            children: [
              const Expanded(child: Divider(color: AppColors.border)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spaceLg),
                child: Text(
                  'PAY USING',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textTertiary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Expanded(child: Divider(color: AppColors.border)),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.spaceLg),
        UpiAppPicker(
          paymentData: widget.paymentData,
          onPaymentComplete: _handlePaymentComplete,
          onCancel: () => Navigator.of(context).pop(),
        ),
        const SizedBox(height: AppSpacing.spaceLg),
      ],
    );
  }

  Widget _buildResultView() {
    final result = _result!;
    final icon = UpiPaymentService.getStatusIcon(result);
    final color = UpiPaymentService.getStatusColor(result);
    final message = UpiPaymentService.getStatusMessage(result);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.space3xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 36, color: color),
          ),
          const SizedBox(height: AppSpacing.spaceXl),
          Text(
            message,
            style: AppTypography.bodyPrimary.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          if (result.transactionId != null) ...[
            const SizedBox(height: AppSpacing.spaceMd),
            Text(
              'Txn ID: ${result.transactionId}',
              style: AppTypography.caption.copyWith(
                color: AppColors.textTertiary,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      ),
    );
  }
}
