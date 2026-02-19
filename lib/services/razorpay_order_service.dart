import 'package:cloud_functions/cloud_functions.dart';

class RazorpayOrderResult {
  final String orderId;
  final String keyId;

  const RazorpayOrderResult({required this.orderId, required this.keyId});
}

Future<RazorpayOrderResult> createRazorpayOrder({
  required int amountPaise,
  String? receipt,
}) async {
  final callable = FirebaseFunctions.instanceFor(region: 'asia-south1')
      .httpsCallable('createRazorpayOrder');
  final result = await callable.call({
    'amountPaise': amountPaise,
    if (receipt != null) 'receipt': receipt,
  });
  final data = result.data;
  if (data == null || data is! Map) throw Exception('No response from server.');
  final map = Map<String, dynamic>.from(data as Map);
  final orderId = map['orderId'] as String?;
  final keyId = map['keyId'] as String?;
  if (orderId == null || orderId.isEmpty || keyId == null || keyId.isEmpty) {
    throw Exception('Invalid order response.');
  }
  return RazorpayOrderResult(orderId: orderId, keyId: keyId);
}
