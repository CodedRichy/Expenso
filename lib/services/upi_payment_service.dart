/// Payment data needed for QR display and copy-to-clipboard UPI flows.
/// Intent launching is NOT supported — this class is used for QR code
/// generation and UPI ID display only.
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

  /// UPI deep-link string used for QR code display.
  /// Not used for intent launching.
  String get upiDeepLink {
    final amount = amountDisplay.toStringAsFixed(2);
    final encodedName = Uri.encodeComponent(payeeName);
    final encodedNote = Uri.encodeComponent(transactionNote);
    final encodedRef = Uri.encodeComponent(transactionRef);
    return 'upi://pay?pa=$payeeUpiId&pn=$encodedName&am=$amount&cu=$currencyCode&tn=$encodedNote&tr=$encodedRef';
  }

  String get qrData => upiDeepLink;
}

class UpiPaymentService {
  UpiPaymentService._();

  /// Creates a validated [UpiPaymentData] for the given payee and amount.
  /// Generates a fresh alphanumeric `tr` per call.
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
    String sanitizedName = payeeName
        .replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '')
        .trim();
    if (sanitizedName.length > 30) {
      sanitizedName = sanitizedName.substring(0, 30).trim();
    }

    // Sanitize note — alphanumeric + spaces, max 50 chars.
    String note = 'Expenso $groupName Cycle'
        .replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '')
        .trim();
    if (note.length > 50) note = note.substring(0, 50).trim();

    // Fresh tr per call to avoid PSP duplicate detection.
    String finalRef =
        transactionRef ?? 'EX${DateTime.now().millisecondsSinceEpoch}';
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
}
