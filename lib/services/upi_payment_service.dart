import 'package:flutter/material.dart';
import 'package:upi_pay/upi_pay.dart' as upi;
import '../design/colors.dart';

class UpiAppInfo {
  final String name;
  final Widget Function(double size) iconBuilder;
  final upi.ApplicationMeta appMeta;

  const UpiAppInfo({
    required this.name,
    required this.iconBuilder,
    required this.appMeta,
  });
}

class UpiPaymentData {
  final String payeeUpiId;
  final String payeeName;
  final int amountMinor;
  final String currencyCode;
  final String transactionNote;
  final String transactionRef;

  const UpiPaymentData({
    required this.payeeUpiId,
    required this.payeeName,
    required this.amountMinor,
    required this.currencyCode,
    required this.transactionNote,
    required this.transactionRef,
  });

  double get amountDisplay => amountMinor / 100;

  /// UPI deep-link used for QR display only.
  /// The actual intent is constructed by the upi_pay plugin's native layer.
  String get upiDeepLink {
    final amount = amountDisplay.toStringAsFixed(2);
    final encodedName = Uri.encodeComponent(payeeName);
    final encodedNote = Uri.encodeComponent(transactionNote);
    final encodedRef = Uri.encodeComponent(transactionRef);
    return 'upi://pay?pa=$payeeUpiId&pn=$encodedName&am=$amount&cu=$currencyCode&tn=$encodedNote&tr=$encodedRef';
  }

  String get qrData => upiDeepLink;
}

/// Refined 5-way classification of a UPI payment outcome.
/// 
/// Critical invariant: [intentRejected] and [cancelled] mean NO network
/// transaction was attempted. Money was NOT debited. Do NOT show "Payment failed."
enum UpiTransactionStatus {
  /// Network transaction confirmed success. txnId is present. Trust this.
  success,

  /// Bank or network returned failure. txnId is present — money was NOT debited.
  bankFailure,

  /// Submitted to banking network but unconfirmed. Never trust this as success
  /// or failure without a bank status check.
  submitted,

  /// Intent was returned without a network attempt (GPay blocked the app,
  /// user back-pressed, or PSP rejected the intent at the app layer).
  /// No money was debited. Treat as cancelled — do NOT show "Payment failed."
  intentRejected,

  /// User explicitly cancelled before selecting a payment method, or the
  /// intent result was null.
  cancelled,
}

class UpiTransactionResult {
  final UpiTransactionStatus status;
  final String? transactionId;
  /// Raw NPCI response code (e.g. ZM=limit, Z9=timeout). For audit / debug log.
  final String? responseCode;
  final String? approvalRefNo;
  final String? rawResponse;

  const UpiTransactionResult({
    required this.status,
    this.transactionId,
    this.responseCode,
    this.approvalRefNo,
    this.rawResponse,
  });

  bool get isSuccess => status == UpiTransactionStatus.success;
  bool get isPending => status == UpiTransactionStatus.submitted;
  bool get isFailed => status == UpiTransactionStatus.bankFailure;
  bool get isIntentRejected => status == UpiTransactionStatus.intentRejected;
  bool get isCancelled => status == UpiTransactionStatus.cancelled;

  /// True if the result is ambiguous and requires manual user confirmation.
  bool get requiresManualConfirm =>
      status == UpiTransactionStatus.submitted ||
      status == UpiTransactionStatus.intentRejected;
}

class UpiPaymentService {
  UpiPaymentService._();

  static final upi.UpiPay _upiPay = upi.UpiPay();
  static List<UpiAppInfo>? _cachedApps;

  /// Creates a validated [UpiPaymentData] for the given payee and amount.
  /// Generates a fresh pure-alphanumeric `tr` per call to prevent replay/duplicate
  /// rejections from bank PSPs (commonly masked as 'bank limit exceeded').
  static UpiPaymentData createPaymentData({
    required String payeeUpiId,
    required String payeeName,
    required int amountMinor,
    required String groupName,
    String? transactionRef,
    String currencyCode = 'INR',
  }) {
    // Sanitize UPI ID — strip whitespace, enforce basic VPA format.
    final sanitizedUpiId = payeeUpiId.trim();
    assert(
      RegExp(r'^[a-zA-Z0-9._\-]+@[a-zA-Z0-9]+$').hasMatch(sanitizedUpiId),
      'UPI ID does not match expected format: $sanitizedUpiId',
    );

    // Sanitize payee name — alphanumeric + spaces, max 30 chars.
    // Non-alphanumeric chars silently break some bank PSD parsers.
    String sanitizedName = payeeName.replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '').trim();
    if (sanitizedName.length > 30) sanitizedName = sanitizedName.substring(0, 30).trim();

    // Sanitize note — alphanumeric + spaces, max 50 chars. No emojis or URLs.
    String note = 'Expenso $groupName Cycle'.replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '').trim();
    if (note.length > 50) note = note.substring(0, 50).trim();

    // Generate a fresh high-entropy alphanumeric tr per call.
    // Reusing a tr from a failed/cancelled attempt causes PSP duplicate detection,
    // which maps to the generic "bank limit exceeded" screen in GPay.
    String finalRef = transactionRef ?? 'EX${DateTime.now().millisecondsSinceEpoch}';
    finalRef = finalRef.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    if (finalRef.length > 35) finalRef = finalRef.substring(0, 35);

    return UpiPaymentData(
      payeeUpiId: sanitizedUpiId,
      payeeName: sanitizedName.isNotEmpty ? sanitizedName : 'Payee',
      amountMinor: amountMinor,
      currencyCode: currencyCode.toUpperCase(),
      transactionNote: note.isNotEmpty ? note : 'Expenso Settlement',
      transactionRef: finalRef,
    );
  }

  static Future<List<UpiAppInfo>> getInstalledUpiApps() async {
    if (_cachedApps != null) return _cachedApps!;

    try {
      final apps = await _upiPay.getInstalledUpiApplications(
        statusType: upi.UpiApplicationDiscoveryAppStatusType.all,
      );

      _cachedApps = apps.map((appMeta) => UpiAppInfo(
        name: appMeta.upiApplication.getAppName(),
        iconBuilder: (size) => appMeta.iconImage(size),
        appMeta: appMeta,
      )).toList();

      _cachedApps!.sort((a, b) => _getAppPriority(a.name).compareTo(_getAppPriority(b.name)));
      debugPrint('UpiPaymentService: Found ${_cachedApps!.length} UPI app(s)');
      return _cachedApps!;
    } catch (e) {
      debugPrint('UpiPaymentService: Error getting UPI apps: $e');
      return [];
    }
  }

  static int _getAppPriority(String appName) {
    final name = appName.toLowerCase();
    if (name.contains('google') || name.contains('gpay')) return 0;
    if (name.contains('phonepe')) return 1;
    if (name.contains('paytm')) return 2;
    if (name.contains('bhim')) return 3;
    if (name.contains('amazon')) return 4;
    if (name.contains('whatsapp')) return 5;
    return 99;
  }

  static void clearCache() {
    _cachedApps = null;
  }

  static Future<UpiTransactionResult> initiateTransaction({
    required UpiPaymentData data,
    required UpiAppInfo appInfo,
  }) async {
    try {
      final response = await _upiPay.initiateTransaction(
        app: appInfo.appMeta.upiApplication,
        receiverUpiAddress: data.payeeUpiId,
        receiverName: data.payeeName,
        transactionRef: data.transactionRef,
        transactionNote: data.transactionNote,
        amount: data.amountDisplay.toStringAsFixed(2),
      );
      debugPrint('UpiPaymentService: raw response = ${response.rawResponse}');
      debugPrint('UpiPaymentService: responseCode = ${response.responseCode}');
      return _parseResponse(response);
    } catch (e) {
      debugPrint('UpiPaymentService: Transaction exception: $e');
      // An exception before the intent was launched means the app was not
      // found, or the plugin itself errored. Treat as intent_rejected.
      return UpiTransactionResult(
        status: UpiTransactionStatus.intentRejected,
        rawResponse: e.toString(),
      );
    }
  }

  /// Maps the upi_pay plugin response to our 5-way classification model.
  ///
  /// Key insight: The plugin defaults to [UpiTransactionStatus.failure] for
  /// ANY response that does not explicitly contain "success" or "submitted".
  /// This includes:
  ///   - GPay back-press (user exit, no network attempt)
  ///   - PSP/app-layer rejection (unregistered app, intent blocked)
  ///   - True bank failures (wrong PIN, actual limit)
  ///
  /// We disambiguate using the presence of [txnId]:
  ///   - txnId present → a network transaction occurred; trust the status
  ///   - txnId absent  → no network attempt; treat as [intentRejected]
  static UpiTransactionResult _parseResponse(upi.UpiTransactionResponse response) {
    final txnId = response.txnId;
    final responseCode = response.responseCode;
    final approvalRef = response.approvalRefNo;
    final rawResponse = response.rawResponse;

    switch (response.status) {
      case upi.UpiTransactionStatus.success:
        return UpiTransactionResult(
          status: UpiTransactionStatus.success,
          transactionId: txnId,
          responseCode: responseCode,
          approvalRefNo: approvalRef,
          rawResponse: rawResponse,
        );

      case upi.UpiTransactionStatus.submitted:
        // Submitted = in-progress at banking network. Cannot confirm success
        // or failure without a bank status check we cannot perform.
        return UpiTransactionResult(
          status: UpiTransactionStatus.submitted,
          transactionId: txnId,
          responseCode: responseCode,
          approvalRefNo: approvalRef,
          rawResponse: rawResponse,
        );

      case upi.UpiTransactionStatus.failure:
        // Disambiguate bank failure from intent rejection using txnId.
        final hasTxnId = txnId != null && txnId.isNotEmpty;
        return UpiTransactionResult(
          status: hasTxnId
              ? UpiTransactionStatus.bankFailure    // real network attempt, bank said no
              : UpiTransactionStatus.intentRejected, // no network attempt (GPay blocked / back-press)
          transactionId: txnId,
          responseCode: responseCode,
          approvalRefNo: approvalRef,
          rawResponse: rawResponse,
        );

      default:
        return UpiTransactionResult(
          status: UpiTransactionStatus.cancelled,
          rawResponse: rawResponse,
        );
    }
  }

  static String getStatusMessage(UpiTransactionResult result) {
    switch (result.status) {
      case UpiTransactionStatus.success:
        return 'Payment confirmed';
      case UpiTransactionStatus.submitted:
        return 'Payment is being processed. Do not pay again.';
      case UpiTransactionStatus.bankFailure:
        return 'Payment declined by your bank. No money was debited.';
      case UpiTransactionStatus.intentRejected:
        return 'GPay returned without completing payment. Tap \'I\'ve paid\' only if you saw a success screen in GPay.';
      case UpiTransactionStatus.cancelled:
        return 'Payment cancelled.';
    }
  }

  static IconData getStatusIcon(UpiTransactionResult result) {
    switch (result.status) {
      case UpiTransactionStatus.success:
        return Icons.check_circle;
      case UpiTransactionStatus.submitted:
        return Icons.hourglass_bottom;
      case UpiTransactionStatus.bankFailure:
        return Icons.error;
      case UpiTransactionStatus.intentRejected:
        return Icons.info_outline;
      case UpiTransactionStatus.cancelled:
        return Icons.cancel_outlined;
    }
  }

  static Color getStatusColor(UpiTransactionResult result) {
    switch (result.status) {
      case UpiTransactionStatus.success:
        return AppColors.success;
      case UpiTransactionStatus.submitted:
        return AppColors.warning;
      case UpiTransactionStatus.bankFailure:
        return AppColors.error;
      case UpiTransactionStatus.intentRejected:
        return AppColors.textSecondary;
      case UpiTransactionStatus.cancelled:
        return AppColors.textSecondary;
    }
  }
}
