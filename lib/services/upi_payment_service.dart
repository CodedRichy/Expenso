import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:upi_india/upi_india.dart';

class UpiAppInfo {
  final String name;
  final Uint8List icon;
  final UpiApp app;

  const UpiAppInfo({
    required this.name,
    required this.icon,
    required this.app,
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

  String get upiDeepLink {
    final amount = amountDisplay.toStringAsFixed(2);
    final encodedName = Uri.encodeComponent(payeeName);
    final encodedNote = Uri.encodeComponent(transactionNote);
    return 'upi://pay?pa=$payeeUpiId&pn=$encodedName&am=$amount&cu=$currencyCode&tn=$encodedNote';
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

  static final UpiIndia _upiIndia = UpiIndia();
  static List<UpiAppInfo>? _cachedApps;

  static UpiPaymentData createPaymentData({
    required String payeeUpiId,
    required String payeeName,
    required int amountMinor,
    required String groupName,
    String currencyCode = 'INR',
    String? transactionRef,
  }) {
    final ref = transactionRef ?? 'EXP${DateTime.now().millisecondsSinceEpoch}';
    return UpiPaymentData(
      payeeUpiId: payeeUpiId,
      payeeName: payeeName,
      amountMinor: amountMinor,
      currencyCode: currencyCode,
      transactionNote: 'Expenso • $groupName • Cycle',
      transactionRef: ref,
    );
  }

  static Future<List<UpiAppInfo>> getInstalledUpiApps() async {
    if (_cachedApps != null) return _cachedApps!;

    try {
      final apps = await _upiIndia.getAllUpiApps(
        mandatoryTransactionId: false,
        allowNonVerifiedApps: true,
      );

      _cachedApps = apps.map((app) => UpiAppInfo(
        name: app.name,
        icon: app.icon,
        app: app,
      )).toList();

      _cachedApps!.sort((a, b) => _getAppPriority(a.name).compareTo(_getAppPriority(b.name)));

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
      final response = await _upiIndia.startTransaction(
        app: appInfo.app,
        receiverUpiId: data.payeeUpiId,
        receiverName: data.payeeName,
        transactionRefId: data.transactionRef,
        transactionNote: data.transactionNote,
        amount: data.amountDisplay,
      );

      return _parseResponse(response);
    } on UpiIndiaAppNotInstalledException {
      clearCache();
      return const UpiTransactionResult(
        status: UpiTransactionStatus.failure,
        rawResponse: 'App not installed',
      );
    } on UpiIndiaUserCancelledException {
      return const UpiTransactionResult(
        status: UpiTransactionStatus.cancelled,
        rawResponse: 'User cancelled',
      );
    } on UpiIndiaNullResponseException {
      return const UpiTransactionResult(
        status: UpiTransactionStatus.unknown,
        rawResponse: 'No response from app',
      );
    } on UpiIndiaInvalidParametersException catch (e) {
      return UpiTransactionResult(
        status: UpiTransactionStatus.failure,
        rawResponse: 'Invalid parameters: ${e.message}',
      );
    } catch (e) {
      return UpiTransactionResult(
        status: UpiTransactionStatus.failure,
        rawResponse: e.toString(),
      );
    }
  }

  static UpiTransactionResult _parseResponse(UpiResponse response) {
    UpiTransactionStatus status;
    
    switch (response.status) {
      case UpiPaymentStatus.SUCCESS:
        status = UpiTransactionStatus.success;
        break;
      case UpiPaymentStatus.FAILURE:
        status = UpiTransactionStatus.failure;
        break;
      case UpiPaymentStatus.SUBMITTED:
        status = UpiTransactionStatus.submitted;
        break;
      default:
        status = UpiTransactionStatus.unknown;
    }

    return UpiTransactionResult(
      status: status,
      transactionId: response.transactionId,
      responseCode: response.responseCode,
      approvalRefNo: response.approvalRefNo,
      rawResponse: 'Status: ${response.status ?? "unknown"}',
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
        return const Color(0xFF2E7D32);
      case UpiTransactionStatus.submitted:
        return const Color(0xFFF9A825);
      case UpiTransactionStatus.failure:
      case UpiTransactionStatus.cancelled:
        return const Color(0xFFC62828);
      case UpiTransactionStatus.unknown:
        return const Color(0xFF6B6B6B);
    }
  }
}
