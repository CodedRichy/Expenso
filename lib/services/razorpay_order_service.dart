import 'package:supabase_flutter/supabase_flutter.dart';

class RazorpayOrderResult {
  final String orderId;
  final String keyId;

  const RazorpayOrderResult({required this.orderId, required this.keyId});
}

Future<RazorpayOrderResult> createRazorpayOrder({
  required int amountPaise,
  String? receipt,
}) async {
  final result = await Supabase.instance.client.functions.invoke('createRazorpayOrder', body: {
    'amountPaise': amountPaise,
    if (receipt != null) 'receipt': receipt,
  });
  final data = result.data;
  if (data == null || data is! Map) throw Exception('No response from server.');
  final map = Map<String, dynamic>.from(data);
  final orderId = map['orderId'] as String?;
  final keyId = map['keyId'] as String?;
  if (orderId == null || orderId.isEmpty || keyId == null || keyId.isEmpty) {
    throw Exception('Invalid order response.');
  }
  return RazorpayOrderResult(orderId: orderId, keyId: keyId);
}
