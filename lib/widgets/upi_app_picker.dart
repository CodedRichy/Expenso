import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../services/upi_payment_service.dart';
import '../utils/money_format.dart';
import 'upi_payment_waiting.dart';

class UpiAppPickerResult {
  final UpiTransactionResult? transactionResult;
  final bool manuallyConfirmed;

  const UpiAppPickerResult({
    this.transactionResult,
    this.manuallyConfirmed = false,
  });

  bool get isSuccess => transactionResult?.isSuccess == true || manuallyConfirmed;
}

class UpiAppPicker extends StatefulWidget {
  final UpiPaymentData paymentData;
  final Function(UpiAppInfo app, UpiTransactionResult result) onPaymentComplete;
  final VoidCallback? onCancel;
  final VoidCallback? onManualConfirm;

  const UpiAppPicker({
    super.key,
    required this.paymentData,
    required this.onPaymentComplete,
    this.onCancel,
    this.onManualConfirm,
  });

  static Future<UpiAppPickerResult?> show({
    required BuildContext context,
    required UpiPaymentData paymentData,
  }) {
    return Navigator.of(context).push<UpiAppPickerResult>(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.transparent,
        pageBuilder: (context, animation, secondaryAnimation) {
          return _UpiPaymentFlow(paymentData: paymentData);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
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

  void _onAppTap(UpiAppInfo appInfo) {
    setState(() => _processingApp = appInfo);
    widget.onPaymentComplete(appInfo, const UpiTransactionResult(status: UpiTransactionStatus.unknown));
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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.space3xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppSpacing.spaceXl),
          Text(
            _error!,
            style: context.bodyPrimary,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.spaceMd),
          Text(
            'Install a UPI app like Google Pay, PhonePe, or Paytm to pay.',
            style: context.caption,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.spaceLg),
          TextButton.icon(
            onPressed: _openPlayStoreForUpiApp,
            icon: const Icon(Icons.get_app, size: 18),
            label: const Text('Install UPI app'),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.spaceXl),
          TextButton(
            onPressed: widget.onCancel,
            child: const Text('Back'),
          ),
        ],
      ),
    );
  }

  Future<void> _openPlayStoreForUpiApp() async {
    final uri = Uri.parse(
      Platform.isIOS
          ? 'https://apps.apple.com/in/app/google-pay-india/id1193357045'
          : 'https://play.google.com/store/apps/details?id=com.google.android.apps.nbu.paisa.user',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
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
    final theme = Theme.of(context);
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
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.shadow.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: isProcessing
                    ? Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary),
                        ),
                      )
                    : appInfo.iconBuilder(44),
              ),
            ),
            const SizedBox(height: AppSpacing.spaceSm),
            Text(
              _formatAppName(appInfo.name),
              style: context.captionSmall.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
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

enum _FlowState { appSelection, waiting }

class _UpiPaymentFlow extends StatefulWidget {
  final UpiPaymentData paymentData;

  const _UpiPaymentFlow({required this.paymentData});

  @override
  State<_UpiPaymentFlow> createState() => _UpiPaymentFlowState();
}

class _UpiPaymentFlowState extends State<_UpiPaymentFlow> {
  _FlowState _state = _FlowState.appSelection;
  UpiAppInfo? _selectedApp;
  Completer<UpiTransactionResult>? _transactionCompleter;
  double _dragOffset = 0;

  void _onAppSelected(UpiAppInfo app, UpiTransactionResult _) {
    setState(() {
      _selectedApp = app;
      _state = _FlowState.waiting;
    });
    _startTransaction(app);
  }

  Future<void> _startTransaction(UpiAppInfo app) async {
    _transactionCompleter = Completer<UpiTransactionResult>();

    final result = await UpiPaymentService.initiateTransaction(
      data: widget.paymentData,
      appInfo: app,
    );

    if (!_transactionCompleter!.isCompleted) {
      _transactionCompleter!.complete(result);
    }
  }

  void _onRetry() {
    if (_selectedApp != null) {
      _startTransaction(_selectedApp!);
    }
  }

  void _onManualConfirm() {
    Navigator.of(context).pop(const UpiAppPickerResult(manuallyConfirmed: true));
  }

  void _onCancel() {
    Navigator.of(context).pop();
  }

  void _onBackToAppSelection() {
    setState(() {
      _state = _FlowState.appSelection;
      _selectedApp = null;
      _transactionCompleter = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          GestureDetector(
            onTap: _state == _FlowState.appSelection ? _onCancel : null,
            child: Container(color: Colors.black54),
          ),
          if (_state == _FlowState.appSelection)
            _buildAppSelectionSheet()
          else
            _buildWaitingOverlay(),
        ],
      ),
    );
  }

  Widget _buildAppSelectionSheet() {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Transform.translate(
        offset: Offset(0, _dragOffset),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: theme.bottomSheetTheme.backgroundColor ?? theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragUpdate: (details) {
                  setState(() {
                    _dragOffset = (_dragOffset + details.delta.dy).clamp(0.0, 400.0);
                  });
                },
                onVerticalDragEnd: (details) {
                  const threshold = 80.0;
                  final shouldDismiss = _dragOffset > threshold ||
                      (details.primaryVelocity != null && details.primaryVelocity! > 300);
                  if (shouldDismiss) {
                    Navigator.of(context).pop();
                  } else {
                    setState(() => _dragOffset = 0);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.only(
                    top: AppSpacing.spaceMd,
                    bottom: AppSpacing.spaceXl,
                  ),
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.dividerColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
              _buildPaymentHeader(),
              const SizedBox(height: AppSpacing.space3xl),
              _buildPayUsingDivider(),
              const SizedBox(height: AppSpacing.spaceLg),
              Flexible(
                child: SingleChildScrollView(
                  child: UpiAppPicker(
                    paymentData: widget.paymentData,
                    onPaymentComplete: _onAppSelected,
                    onCancel: _onCancel,
                    onManualConfirm: () => Navigator.of(context).pop(const UpiAppPickerResult(manuallyConfirmed: true)),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(AppSpacing.screenPaddingH, AppSpacing.spaceMd, AppSpacing.screenPaddingH, 16 + bottomPadding),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(const UpiAppPickerResult(manuallyConfirmed: true)),
                    child: const Text('I\'ve paid'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentHeader() {
    final theme = Theme.of(context);
    final amountStr = formatMoneyWithCurrency(widget.paymentData.amountMinor, widget.paymentData.currencyCode);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPaddingH),
      child: Column(
        children: [
          Text(
            'Pay $amountStr',
            style: context.amountMD.copyWith(color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: AppSpacing.spaceXs),
          Text(
            'to ${widget.paymentData.payeeName}',
            style: context.bodySecondary,
          ),
          const SizedBox(height: AppSpacing.spaceSm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.spaceLg,
              vertical: AppSpacing.spaceXs,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.paymentData.payeeUpiId,
              style: context.caption.copyWith(
                fontFamily: 'monospace',
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayUsingDivider() {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPaddingH),
      child: Row(
        children: [
          Expanded(child: Divider(color: theme.dividerColor)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spaceLg),
            child: Text(
              'PAY USING',
              style: context.sectionLabel,
            ),
          ),
          Expanded(child: Divider(color: theme.dividerColor)),
        ],
      ),
    );
  }

  Widget _buildWaitingOverlay() {
    return UpiPaymentWaitingOverlay(
      payeeName: widget.paymentData.payeeName,
      amountMinor: widget.paymentData.amountMinor,
      currencyCode: widget.paymentData.currencyCode,
      appName: _selectedApp?.name ?? 'UPI',
      transactionFuture: _transactionCompleter!.future,
      onRetry: _onRetry,
      onManualConfirm: _onManualConfirm,
      onCancel: _onBackToAppSelection,
    );
  }
}
