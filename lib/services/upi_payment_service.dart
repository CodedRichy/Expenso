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

  /// UPI deep-link used for QR display and fallback launches.
  /// Includes tr= (transaction reference) as required by the UPI spec.
  String get upiDeepLink {
    final amount = amountDisplay.toStringAsFixed(2);
    final encodedName = Uri.encodeComponent(payeeName);
    final encodedNote = Uri.encodeComponent(transactionNote);
    final encodedRef = Uri.encodeComponent(transactionRef);
    return 'upi://pay?pa=$payeeUpiId&pn=$encodedName&am=$amount&cu=$currencyCode&tn=$encodedNote&tr=$encodedRef';
  }

  String get qrData => upiDeepLink;
}

enum UpiTransactionStatus {
  success,
  failure,
  submitted,
  cancelled,
  unknown,
}

class UpiTransactionResult {
  final UpiTransactionStatus status;
  final String? transactionId;
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
  bool get isFailed => status == UpiTransactionStatus.failure;
  bool get isCancelled => status == UpiTransactionStatus.cancelled;
}

class UpiPaymentService {
  UpiPaymentService._();

  static final upi.UpiPay _upiPay = upi.UpiPay();
  static List<UpiAppInfo>? _cachedApps;

  /// Creates a validated [UpiPaymentData] for the given payee and amount.
  /// [transactionRef] MUST be generated once per payment attempt (e.g. at the
  /// settlement-confirmation level) and passed in — never let this method generate
  /// a fresh ref on each call, as that would produce duplicate transactions on retry.
  static UpiPaymentData createPaymentData({
    required String payeeUpiId,
    required String payeeName,
    required int amountMinor,
    required String groupName,
    required String transactionRef,
    String currencyCode = 'INR',
  }) {
    // Sanitize UPI ID — strip whitespace, enforce basic format.
    final sanitizedUpiId = payeeUpiId.trim();
    assert(
      RegExp(r'^[a-zA-Z0-9._\-]+@[a-zA-Z0-9]+$').hasMatch(sanitizedUpiId),
      'UPI ID does not match expected format: $sanitizedUpiId',
    );
    // Sanitize payee name — UPI spec disallows some special characters.
    final sanitizedName = payeeName.trim().replaceAll(RegExp(r'[&=#+%]'), '');
    return UpiPaymentData(
      payeeUpiId: sanitizedUpiId,
      payeeName: sanitizedName.isNotEmpty ? sanitizedName : 'Payee',
      amountMinor: amountMinor,
      currencyCode: currencyCode.toUpperCase(),
      transactionNote: 'Expenso • $groupName • Cycle',
      transactionRef: transactionRef,
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

      return _parseResponse(response);
    } catch (e) {
      debugPrint('UpiPaymentService: Transaction error: $e');
      return UpiTransactionResult(
        status: UpiTransactionStatus.failure,
        rawResponse: e.toString(),
      );
    }
  }

  static UpiTransactionResult _parseResponse(upi.UpiTransactionResponse response) {
    UpiTransactionStatus status;
    
    switch (response.status) {
      case upi.UpiTransactionStatus.success:
        status = UpiTransactionStatus.success;
        break;
      case upi.UpiTransactionStatus.failure:
        status = UpiTransactionStatus.failure;
        break;
      case upi.UpiTransactionStatus.submitted:
        status = UpiTransactionStatus.submitted;
        break;
      default:
        status = UpiTransactionStatus.unknown;
    }

    return UpiTransactionResult(
      status: status,
      transactionId: response.txnId,
      responseCode: response.responseCode,
      approvalRefNo: response.approvalRefNo,
      rawResponse: 'Status: ${response.status}',
    );
  }

  static String getStatusMessage(UpiTransactionResult result) {
    switch (result.status) {
      case UpiTransactionStatus.success:
        return 'Payment successful';
      case UpiTransactionStatus.submitted:
        return 'Payment submitted. Please verify with your bank.';
      case UpiTransactionStatus.failure:
        return 'Payment failed. Please try again.';
      case UpiTransactionStatus.cancelled:
        return 'Payment cancelled';
      case UpiTransactionStatus.unknown:
        return 'Payment status unknown. Please check your UPI app.';
    }
  }

  static IconData getStatusIcon(UpiTransactionResult result) {
    switch (result.status) {
      case UpiTransactionStatus.success:
        return Icons.check_circle;
      case UpiTransactionStatus.submitted:
        return Icons.hourglass_bottom;
      case UpiTransactionStatus.failure:
        return Icons.error;
      case UpiTransactionStatus.cancelled:
        return Icons.cancel;
      case UpiTransactionStatus.unknown:
        return Icons.help;
    }
  }

  static Color getStatusColor(UpiTransactionResult result) {
    switch (result.status) {
      case UpiTransactionStatus.success:
        return AppColors.success;
      case UpiTransactionStatus.submitted:
        return AppColors.warning;
      case UpiTransactionStatus.failure:
      case UpiTransactionStatus.cancelled:
        return AppColors.error;
      case UpiTransactionStatus.unknown:
        return AppColors.textSecondary;
    }
  }
}
