import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class UpiPaymentData {
  final String payeeUpiId;
  final String payeeName;
  final int amountMinor;
  final String currencyCode;
  final String transactionNote;

  const UpiPaymentData({
    required this.payeeUpiId,
    required this.payeeName,
    required this.amountMinor,
    required this.currencyCode,
    required this.transactionNote,
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

class UpiPaymentService {
  UpiPaymentService._();

  static UpiPaymentData createPaymentData({
    required String payeeUpiId,
    required String payeeName,
    required int amountMinor,
    required String groupName,
    String currencyCode = 'INR',
  }) {
    return UpiPaymentData(
      payeeUpiId: payeeUpiId,
      payeeName: payeeName,
      amountMinor: amountMinor,
      currencyCode: currencyCode,
      transactionNote: 'Expenso • $groupName • Cycle',
    );
  }

  static Future<bool> canLaunchUpi() async {
    try {
      final uri = Uri.parse('upi://pay');
      return await canLaunchUrl(uri);
    } catch (_) {
      return false;
    }
  }

  static Future<UpiLaunchResult> launchUpiPayment(UpiPaymentData data) async {
    try {
      final uri = Uri.parse(data.upiDeepLink);
      final canLaunch = await canLaunchUrl(uri);
      
      if (!canLaunch) {
        return UpiLaunchResult.noUpiApp;
      }

      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      return launched ? UpiLaunchResult.launched : UpiLaunchResult.failed;
    } on PlatformException {
      return UpiLaunchResult.noUpiApp;
    } catch (_) {
      return UpiLaunchResult.failed;
    }
  }
}

enum UpiLaunchResult {
  launched,
  noUpiApp,
  failed,
}
