import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'data_encryption_service.dart';

abstract class DocView {
  String get id;
  Map<String, dynamic> data();
}

class _SupabaseRowView implements DocView {
  _SupabaseRowView(this._data) : _id = _data['id'] as String;
  final Map<String, dynamic> _data;
  final String _id;

  @override
  String get id => _id;

  @override
  Map<String, dynamic> data() => _data;
}

class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  SupabaseClient get _db => Supabase.instance.client;

  // No-op for now because Postgres schema is relational, can't easily encrypt payloads as strings
  void setEncryptionService(DataEncryptionService? s) {}

  // =====================
  // USERS
  // =====================
  Future<void> setUser(
    String uid, {
    String? displayName,
    String? phoneNumber,
    String? email,
    String? photoURL,
    String? upiId,
    String? currencyCode,
  }) async {
    final Map<String, dynamic> data = {'id': uid};
    if (displayName != null) data['display_name'] = displayName;
    if (phoneNumber != null) data['phone'] = phoneNumber;
    if (email != null) data['email'] = email;
    if (photoURL != null) data['avatar_url'] = photoURL;
    if (upiId != null) data['upi_id'] = upiId;
    if (currencyCode != null) data['currency_code'] = currencyCode;

    await _db.from('users').upsert(data);
  }

  Future<Map<String, dynamic>?> getUser(String uid) async {
    try {
      final res = await _db.from('users').select().eq('id', uid).single();
      // Translate keys from snake_case to match legacy Firestore app usage
      return {
        'displayName': res['display_name'],
        'phoneNumber': res['phone'],
        'email': res['email'],
        'photoURL': res['avatar_url'],
        'upiId': res['upi_id'],
        'currencyCode': res['currency_code'],
      };
    } catch (e) {
      return null;
    }
  }

  Stream<Map<String, dynamic>?> userStream(String uid) {
    return _db.from('users').stream(primaryKey: ['id']).eq('id', uid).map((list) {
      if (list.isEmpty) return null;
      final res = list.first;
      return {
        'displayName': res['display_name'],
        'phoneNumber': res['phone'],
        'email': res['email'],
        'photoURL': res['avatar_url'],
        'upiId': res['upi_id'],
        'currencyCode': res['currency_code'],
      };
    });
  }

  // =====================
  // GROUPS
  // =====================
  Future<void> createGroup(
    String groupId, {
    required String groupName,
    required String creatorId,
    String? activeCycleId,
    List<Map<String, String>>? pendingMembers,
    String? settlementRhythm,
    int? settlementDay,
    String? currencyCode,
  }) async {
    await _db.from('groups').insert({
      'id': groupId,
      'name': groupName,
      'creator_id': creatorId,
      'status': 'active',
      'currency_code': currencyCode ?? 'INR',
      'settlement_rhythm': settlementRhythm ?? 'weekly',
      'settlement_day': settlementDay ?? 0,
    });
    await addMemberToGroup(groupId, creatorId);
  }

  Stream<List<DocView>> groupsStream(String uid) {
    // Requires a join in a real production app. 
    // Here we listen to group_members and fetch groups upon changes.
    return _db.from('group_members').stream(primaryKey: ['group_id', 'user_id']).eq('user_id', uid).asyncMap((members) async {
      if (members.isEmpty) return [];
      final groupIds = members.map((e) => e['group_id']).toList();
      final groups = await _db.from('groups').select().inFilter('id', groupIds);
      return groups.map((g) {
        return _SupabaseRowView({
          'id': g['id'],
          'groupName': g['name'],
          'creatorId': g['creator_id'],
          'cycleStatus': g['status'],
          'currencyCode': g['currency_code'],
          'settlementRhythm': g['settlement_rhythm'],
          'settlementDay': g['settlement_day'],
          'members': members.map((e) => e['user_id']).toList(), // Simple mock
        });
      }).toList();
    });
  }

  Future<dynamic> getGroup(String groupId) async {
    // This used to return DocumentSnapshot. We return a Map to simulate it in repositories.
    final data = await _db.from('groups').select().eq('id', groupId).single();
    return _SupabaseRowView({
          'id': data['id'],
          'groupName': data['name'],
          'creatorId': data['creator_id'],
          'cycleStatus': data['status'],
          'currencyCode': data['currency_code'],
          'settlementRhythm': data['settlement_rhythm'],
          'settlementDay': data['settlement_day'],
        });
  }

  Stream<List<DocView>> pendingInvitationsStream({String? phone, String? email}) {
    return _db.from('group_invitations')
        .stream(primaryKey: ['id'])
        .asyncMap((invites) async {
          // Filter by phone/email and status locally
          final pendingInvites = invites.where((i) {
            final matchesPhone = phone != null && phone.isNotEmpty && i['invitee_phone'] == phone;
            final matchesEmail = email != null && email.isNotEmpty && i['invitee_email'] == email;
            return (matchesPhone || matchesEmail) && i['status'] == 'pending';
          }).toList();
          if (pendingInvites.isEmpty) return [];
          final groupIds = pendingInvites.map((e) => e['group_id']).toList();
          final groups = await _db.from('groups').select('id, name, creator_id').inFilter('id', groupIds);
          return groups.map((g) => _SupabaseRowView({
            'id': g['id'],
            'groupName': g['name'],
            'creatorId': g['creator_id'],
          })).toList();
        });
  }

  Future<void> acceptInvitation(String groupId, String uid, {String? phone, String? email, String? userName}) async {
    final query = _db.from('group_invitations')
        .update({'status': 'accepted'})
        .eq('group_id', groupId);
    
    if (phone != null && phone.isNotEmpty) {
      await query.eq('invitee_phone', phone);
    } else if (email != null && email.isNotEmpty) {
      await query.eq('invitee_email', email);
    }
    await addMemberToGroup(groupId, uid);
    if (userName != null) {
      await addSystemMessage(groupId, type: 'join', userName: userName, odId: uid);
    }
  }

  Future<void> declineInvitation(String groupId, {String? phone, String? email, String? userName}) async {
    final query = _db.from('group_invitations')
        .update({'status': 'declined'})
        .eq('group_id', groupId);

    if (phone != null && phone.isNotEmpty) {
      await query.eq('invitee_phone', phone);
    } else if (email != null && email.isNotEmpty) {
      await query.eq('invitee_email', email);
    }
  }

  Future<void> addSystemMessage(String groupId, {required String type, String userName = '', String odId = '', String detail = '', String prefix = ''}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.from('system_messages').insert({
      'id': 'sys_$now',
      'group_id': groupId,
      'type': type,
      'user_id': odId,
      'user_name': userName,
      'detail': detail,
      'prefix': prefix,
      'timestamp': now,
    });
  }

  Stream<List<Map<String, dynamic>>> systemMessagesStream(String groupId) {
    return _db.from('system_messages').stream(primaryKey: ['id']).eq('group_id', groupId).order('timestamp');
  }

  Future<void> addSettlementEvent(String groupId, {required String type, int? amountMinor, String? currencyCode, String? paymentAttemptId, int? pendingCount}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.from('settlement_events').insert({
      'id': 'se_$now',
      'group_id': groupId,
      'type': type,
      'amount_minor': amountMinor,
      'currency_code': currencyCode,
      'payment_attempt_id': paymentAttemptId,
      'pending_count': pendingCount,
      'timestamp': now,
    });
  }

  Stream<List<Map<String, dynamic>>> settlementEventsStream(String groupId) {
    return _db.from('settlement_events').stream(primaryKey: ['id']).eq('group_id', groupId).order('timestamp');
  }

  Future<List<Map<String, dynamic>>> getSettlementEvents(String groupId) async {
    return await _db.from('settlement_events').select().eq('group_id', groupId).order('timestamp');
  }

  Future<void> deleteGroup(String groupId) async {
    await _db.from('groups').delete().eq('id', groupId);
  }

  Future<void> updateGroup(String groupId, Map<String, dynamic> updates) async {
    final mapped = <String, dynamic>{};
    if(updates.containsKey('cycleStatus')) mapped['status'] = updates['cycleStatus'];
    if(updates.containsKey('groupName')) mapped['name'] = updates['groupName'];
    if (mapped.isNotEmpty) await _db.from('groups').update(mapped).eq('id', groupId);
  }

  Future<void> addMemberToGroup(String groupId, String uid) async {
    await _db.from('group_members').upsert({'group_id': groupId, 'user_id': uid});
  }

  Future<void> addPendingMemberToGroup(String groupId, String? phone, String name, {String? email, String? invitedBy}) async {
    await _db.from('group_invitations').upsert({
      'group_id': groupId,
      if (phone != null) 'invitee_phone': phone,
      if (email != null) 'invitee_email': email,
      'inviter_id': invitedBy,
      'status': 'pending',
    });
  }

  Future<void> removeMemberFromGroup(String groupId, String uid) async {
    await _db.from('group_members').delete().eq('group_id', groupId).eq('user_id', uid);
  }

  Future<void> removePendingMemberFromGroup(String groupId, String phone) async {}

  // =====================
  // EXPENSES
  // =====================
  Future<void> addExpense(String groupId, Map<String, dynamic> expenseData) async {
    final id = expenseData['id'] ?? DateTime.now().millisecondsSinceEpoch.toString();
    await _db.from('expenses').insert({
      'id': id,
      'group_id': groupId,
      'description': expenseData['description'],
      'amount': expenseData['amount'],
      'amount_minor': expenseData['amountMinor'],
      'expense_date': expenseData['date'],
      'category': expenseData['category'],
      'split_type': expenseData['splitType'],
      'paid_by_id': expenseData['paidById'],
      'created_by_id': expenseData['createdById'],
    });
  }

  Future<void> updateExpense(String groupId, String expenseId, Map<String, dynamic> updates) async {
    await _db.from('expenses').update(updates).eq('id', expenseId);
  }

  Future<void> markExpenseDeleted(String groupId, String expenseId, {String deletedById = ''}) async {
    await _db.from('deleted_expenses').insert({
      'expense_id': expenseId,
      'group_id': groupId,
      'deleted_by_id': deletedById,
    });
  }

  Future<void> deleteExpense(String groupId, String expenseId) async {
    await _db.from('expenses').delete().eq('id', expenseId);
  }

  Future<void> addExpenseRevision(String groupId, {required String expenseId, String? replacesExpenseId}) async {
    await _db.from('expense_revisions').insert({
      'expense_id': expenseId,
      'group_id': groupId,
      'replaces_expense_id': replacesExpenseId,
    });
  }

  Stream<List<Map<String, dynamic>>> expenseRevisionsStream(String groupId) {
    return _db.from('expense_revisions').stream(primaryKey: ['expense_id']).eq('group_id', groupId);
  }

  Stream<Set<String>> deletedExpenseIdsStream(String groupId) {
    return _db.from('deleted_expenses').stream(primaryKey: ['expense_id']).eq('group_id', groupId).map((list) => list.map((e) => e['expense_id'] as String).toSet());
  }

  Future<List<Map<String, dynamic>>> getExpenseRevisions(String groupId) async {
    return await _db.from('expense_revisions').select().eq('group_id', groupId);
  }

  Future<Set<String>> getDeletedExpenseIds(String groupId) async {
    final res = await _db.from('deleted_expenses').select().eq('group_id', groupId);
    return res.map((e) => e['expense_id'] as String).toSet();
  }

  Stream<List<DocView>> expensesStream(String groupId) {
    return _db.from('expenses').stream(primaryKey: ['id']).eq('group_id', groupId).map((list) {
      return list.map((e) => _SupabaseRowView(e)).toList();
    });
  }

  // =====================
  // CYCLES
  // =====================
  Future<void> archiveCycleExpenses(String groupId, String cycleId, String newCycleId, {required String startDate, required String endDate}) async {
    await _db.from('cycles').insert({
      'id': cycleId,
      'group_id': groupId,
      'status': 'closed',
      'start_date': startDate,
      'end_date': endDate,
    });
    await _db.from('expenses').update({'cycle_id': cycleId}).eq('group_id', groupId).isFilter('cycle_id', null);
  }

  Future<List<DocView>> getSettledCycles(String groupId) async {
    final cycles = await _db.from('cycles').select().eq('group_id', groupId).eq('status', 'closed');
    return cycles.map((e) => _SupabaseRowView(e)).toList();
  }

  Stream<List<DocView>> settledCycleExpensesStream(String groupId, String cycleId) {
    return _db.from('expenses').stream(primaryKey: ['id']).eq('cycle_id', cycleId).map((list) => list.map((e) => _SupabaseRowView(e)).toList());
  }

  // =====================
  // PAYMENT ATTEMPTS
  // =====================
  Future<String> createPaymentAttempt({
    required String groupId,
    required String cycleId,
    required double amount,
    required String fromMemberId,
    required String toMemberId,
    required String currencyCode,
    String? upiId,
    required String createdById,
  }) async {
    final aid = 'pa_${DateTime.now().millisecondsSinceEpoch}';
    final amountMinor = (amount * 100).round();
    await _db.from('payment_attempts').insert({
      'id': aid,
      'group_id': groupId,
      'cycle_id': cycleId,
      'payer_id': fromMemberId,
      'payee_id': toMemberId,
      'amount_minor': amountMinor,
      'currency': currencyCode,
      'status': 'not_started',
      'upi_id': upiId,
      'created_by_id': createdById,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    });
    return aid;
  }

  Future<void> updatePaymentAttemptStatus(
    String groupId,
    String attemptId,
    String status, {
    int? initiatedAt,
    int? confirmedAt,
    String? upiTransactionId,
    String? upiResponseCode,
  }) async {
    await _db.from('payment_attempts').update({
      'status': status,
      if (initiatedAt != null) 'initiated_at': initiatedAt,
      if (confirmedAt != null) 'confirmed_at': confirmedAt,
      if (upiTransactionId != null) 'upi_transaction_id': upiTransactionId,
      if (upiResponseCode != null) 'upi_response_code': upiResponseCode,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }).eq('id', attemptId);
  }

  Stream<List<Map<String, dynamic>>> paymentAttemptsStream(String groupId, String cycleId) {
    return _db.from('payment_attempts').stream(primaryKey: ['id']).eq('group_id', groupId).map((list) => list.where((e) => e['cycle_id'] == cycleId).toList());
  }

  Future<List<DocView>> getSettledCycleExpenses(String groupId, String cycleId) async {
    final expenses = await _db.from('expenses').select().eq('cycle_id', cycleId);
    return expenses.map((e) => _SupabaseRowView(e)).toList();
  }

  // =====================
  // FCM / INVITES
  // =====================
  Future<void> storeFcmToken(String uid, String token, String platform) async {
    await _db.from('fcm_tokens').upsert({'user_id': uid, 'token': token, 'platform': platform});
  }

  Future<void> deleteFcmToken(String uid, String token) async {
    await _db.from('fcm_tokens').delete().eq('user_id', uid).eq('token', token);
  }

  Future<List<String>> getGroupFcmTokens(String groupId) async { return []; }

  Future<List<String>> getMemberFcmTokens(String uid) async { return []; }

  Future<Map<String, String>?> resolveInviteLink(String groupId, String token) async {
    try {
      // Find group where id and invite_token match, and links are enabled
      final res = await _db.from('groups')
          .select('id, name')
          .eq('id', groupId)
          .eq('invite_link_token', token)
          .eq('invite_link_enabled', true)
          .maybeSingle();

      if (res == null) return null;

      return {
        'groupId': res['id'] as String,
        'groupName': res['name'] as String,
      };
    } catch (e) {
      debugPrint('resolveInviteLink error: $e');
      return null;
    }
  }

  Future<void> revokeInviteToken(String groupId) async {
    await _db.from('groups').update({
      'invite_link_enabled': false,
      'invite_link_token': null,
    }).eq('id', groupId);
  }

  Future<void> generateInviteToken(String groupId) async {
    final token = DateTime.now().millisecondsSinceEpoch.toString();
    await _db.from('groups').update({
      'invite_link_enabled': true,
      'invite_link_token': token,
    }).eq('id', groupId);
  }

}
