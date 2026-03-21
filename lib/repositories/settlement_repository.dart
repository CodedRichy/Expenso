import 'dart:async';
import '../models/models.dart';
import '../services/supabase_service.dart';
import './base_repository.dart';
import './auth_repository.dart';

class SettlementRepository extends BaseRepository {
  SettlementRepository._();
  static final SettlementRepository _instance = SettlementRepository._();
  static SettlementRepository get instance => _instance;

  final Map<String, List<PaymentAttempt>> _paymentAttemptsByGroup = {};
  final Map<String, StreamSubscription<List<Map<String, dynamic>>>> _paymentAttemptSubs = {};
  final Map<String, String> _paymentAttemptCycleId = {};
  final Set<String> _fullySettledEmitted = {};

  List<PaymentAttempt> getPaymentAttempts(String groupId) =>
      List.unmodifiable(_paymentAttemptsByGroup[groupId] ?? []);

  void startListening(String groupId, String cycleId) {
    if (_paymentAttemptSubs.containsKey(groupId)) {
      if (_paymentAttemptCycleId[groupId] == cycleId) return;
      _paymentAttemptSubs[groupId]?.cancel();
    }

    _paymentAttemptCycleId[groupId] = cycleId;
    _paymentAttemptSubs[groupId] = SupabaseService.instance
        .paymentAttemptsStream(groupId, cycleId)
        .listen((docs) {
      final attempts = docs.map((doc) => PaymentAttempt.fromFirestore(doc['id'], doc)).toList();
      _paymentAttemptsByGroup[groupId] = attempts;
      notify();
    });
  }

  void stopListening(String groupId) {
    _paymentAttemptSubs[groupId]?.cancel();
    _paymentAttemptSubs.remove(groupId);
    _paymentAttemptCycleId.remove(groupId);
    _paymentAttemptsByGroup.remove(groupId);
    notify();
  }

  void stopAll() {
    for (final sub in _paymentAttemptSubs.values) {
      sub.cancel();
    }
    _paymentAttemptSubs.clear();
    _paymentAttemptCycleId.clear();
    _paymentAttemptsByGroup.clear();
    notify();
  }

  Future<String> createPaymentAttempt({
    required String groupId,
    required String cycleId,
    required double amount,
    required String fromMemberId,
    required String toMemberId,
    required String currencyCode,
    String? upiId,
  }) async {
    final auth = AuthRepository.instance;
    return await SupabaseService.instance.createPaymentAttempt(
      groupId: groupId,
      cycleId: cycleId,
      amount: amount,
      fromMemberId: fromMemberId,
      toMemberId: toMemberId,
      currencyCode: currencyCode,
      upiId: upiId,
      createdById: auth.currentUserId,
    );
  }

  Future<void> confirmPaymentReceived(String groupId, String attemptId) async {
    await SupabaseService.instance.updatePaymentAttemptStatus(
      groupId,
      attemptId,
      'confirmed_by_receiver',
    );
  }

  Future<void> confirmCashReceived(String groupId, String attemptId) async {
    await SupabaseService.instance.updatePaymentAttemptStatus(
      groupId,
      attemptId,
      'cash_confirmed',
    );
  }

  Future<void> markAssetTransfer(String groupId, String attemptId) async {
     await SupabaseService.instance.updatePaymentAttemptStatus(
      groupId,
      attemptId,
      'asset_transfer_pending',
    );
  }

  bool isFullySettledEmitted(String cycleId) => _fullySettledEmitted.contains(cycleId);
  void markFullySettledEmitted(String cycleId) => _fullySettledEmitted.add(cycleId);
  void clearFullySettledEmitted() => _fullySettledEmitted.clear();
}
