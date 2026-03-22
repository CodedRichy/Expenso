import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data_encryption_service.dart';

abstract class DocView {
  String get id;
  Map<String, dynamic> data();
}

class _SupabaseRowView implements DocView {
  _SupabaseRowView(this._data) : _id = (_data['id'] ?? '').toString();
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

  // No-op for now because Postgres schema is relational, can't easily encrypt payloads as strings.
  void setEncryptionService(DataEncryptionService? s) {}

  // =====================
  // MAPPERS
  // =====================
  Map<String, dynamic> _mapGroupRow(
    Map<String, dynamic> row, {
    List<String>? memberIds,
  }) {
    return {
      'id': row['id'],
      'groupName': row['name'],
      'creatorId': row['creator_id'],
      'activeCycleId': row['active_cycle_id'],
      'cycleStatus': row['status'],
      'currencyCode': row['currency_code'],
      'settlementRhythm': row['settlement_rhythm'],
      'settlementDay': row['settlement_day'],
      'pendingMembers': row['pending_members'],
      'inviteLinkToken': row['invite_link_token'],
      'inviteLinkEnabled': row['invite_link_enabled'],
      'members': memberIds ?? <String>[],
    };
  }

  Map<String, dynamic> _mapExpenseRow(Map<String, dynamic> row) {
    return {
      'id': row['id'],
      'groupId': row['group_id'],
      'cycleId': row['cycle_id'],
      'description': row['description'],
      'amount': row['amount'],
      'amountMinor': row['amount_minor'],
      'date': row['expense_date'],
      'dateSortKey': row['date_sort_key'],
      'category': row['category'],
      'splitType': row['split_type'],
      'payerId': row['paid_by_id'],
      'participantIds': row['participant_ids'],
      'splits': row['splits'],
      'splitsMinor': row['splits_minor'],
      'createdById': row['created_by_id'],
    };
  }

  Map<String, dynamic> _mapSystemMessageRow(Map<String, dynamic> row) {
    return {
      'id': row['id'],
      'groupId': row['group_id'],
      'type': row['type'],
      'userId': row['user_id'],
      'userName': row['user_name'],
      'detail': row['detail'],
      'prefix': row['prefix'],
      'timestamp': row['timestamp'],
    };
  }

  Map<String, dynamic> _mapSettlementEventRow(Map<String, dynamic> row) {
    return {
      'id': row['id'],
      'groupId': row['group_id'],
      'type': row['type'],
      'amountMinor': row['amount_minor'],
      'currencyCode': row['currency_code'],
      'paymentAttemptId': row['payment_attempt_id'],
      'pendingCount': row['pending_count'],
      'timestamp': row['timestamp'],
    };
  }

  Map<String, dynamic> _mapCycleRow(Map<String, dynamic> row) {
    return {
      'id': row['id'],
      'groupId': row['group_id'],
      'status': row['status'],
      'startDate': row['start_date'],
      'endDate': row['end_date'],
    };
  }

  Map<String, dynamic> _mapPaymentAttemptRow(Map<String, dynamic> row) {
    final status = (row['status'] ?? 'not_started').toString();
    final paidVia = row['paid_via'] as String?;
    return {
      'id': row['id'],
      'groupId': row['group_id'],
      'cycleId': row['cycle_id'],
      'fromMemberId': row['payer_id'],
      'toMemberId': row['payee_id'],
      'amountMinor': row['amount_minor'],
      'currencyCode': row['currency'] ?? 'INR',
      'status': status,
      'confirmedByPayer':
          row['confirmed_by_payer'] ??
          status == 'confirmed_by_payer' ||
          status == 'cash_pending',
      'confirmedByReceiver':
          row['confirmed_by_receiver'] ??
          status == 'confirmed_by_receiver' ||
          status == 'cash_confirmed',
      'disputed': row['disputed'] ?? status == 'disputed',
      'paidVia': paidVia,
      'createdAt': row['created_at'] ?? 0,
      'initiatedAt': row['initiated_at'],
      'confirmedAt': row['confirmed_at'],
      'upiTransactionId': row['upi_transaction_id'],
      'upiResponseCode': row['upi_response_code'],
    };
  }

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
    final data = <String, dynamic>{'id': uid};
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
      return {
        'displayName': res['display_name'],
        'phoneNumber': res['phone'],
        'email': res['email'],
        'photoURL': res['avatar_url'],
        'upiId': res['upi_id'],
        'currencyCode': res['currency_code'],
      };
    } catch (_) {
      return null;
    }
  }

  Stream<Map<String, dynamic>?> userStream(String uid) {
    return _db
        .from('users')
        .stream(primaryKey: ['id'])
        .eq('id', uid)
        .map((rows) {
          if (rows.isEmpty) return null;
          final row = rows.first;
          return {
            'displayName': row['display_name'],
            'phoneNumber': row['phone'],
            'email': row['email'],
            'photoURL': row['avatar_url'],
            'upiId': row['upi_id'],
            'currencyCode': row['currency_code'],
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
      'active_cycle_id': activeCycleId,
      'pending_members': pendingMembers,
      'status': 'active',
      'currency_code': currencyCode ?? 'INR',
      'settlement_rhythm': settlementRhythm ?? 'weekly',
      'settlement_day': settlementDay ?? 0,
    });
    await addMemberToGroup(groupId, creatorId);
  }

  Stream<List<DocView>> groupsStream(String uid) {
    return _db
        .from('group_members')
        .stream(primaryKey: ['group_id', 'user_id'])
        .eq('user_id', uid)
        .asyncMap((myMemberships) async {
          if (myMemberships.isEmpty) return <DocView>[];

          final groupIds =
              myMemberships
                  .map((e) => (e['group_id'] ?? '').toString())
                  .where((id) => id.isNotEmpty)
                  .toSet()
                  .toList();
          if (groupIds.isEmpty) return <DocView>[];

          final groups = await _db
              .from('groups')
              .select()
              .inFilter('id', groupIds);

          final allMembers = await _db
              .from('group_members')
              .select('group_id,user_id')
              .inFilter('group_id', groupIds);
          final membersByGroup = <String, List<String>>{};
          for (final row in allMembers) {
            final gid = (row['group_id'] ?? '').toString();
            final memberId = (row['user_id'] ?? '').toString();
            if (gid.isEmpty || memberId.isEmpty) continue;
            membersByGroup.putIfAbsent(gid, () => <String>[]).add(memberId);
          }

          return groups
              .map((g) => _SupabaseRowView(_mapGroupRow(g, memberIds: membersByGroup[g['id']])))
              .toList();
        });
  }

  Future<DocView> getGroup(String groupId) async {
    final group = await _db.from('groups').select().eq('id', groupId).single();
    final members = await _db
        .from('group_members')
        .select('user_id')
        .eq('group_id', groupId);
    final memberIds =
        members
            .map((e) => (e['user_id'] ?? '').toString())
            .where((id) => id.isNotEmpty)
            .toList();
    return _SupabaseRowView(_mapGroupRow(group, memberIds: memberIds));
  }

  Stream<List<DocView>> pendingInvitationsStream({String? phone, String? email}) {
    return _db.from('group_invitations').stream(primaryKey: ['id']).asyncMap((
      invites,
    ) async {
      final pendingInvites =
          invites.where((i) {
            final matchesPhone =
                phone != null &&
                phone.isNotEmpty &&
                i['invitee_phone'] == phone;
            final matchesEmail =
                email != null &&
                email.isNotEmpty &&
                i['invitee_email'] == email;
            return (matchesPhone || matchesEmail) && i['status'] == 'pending';
          }).toList();

      if (pendingInvites.isEmpty) return <DocView>[];

      final groupIds =
          pendingInvites
              .map((e) => (e['group_id'] ?? '').toString())
              .where((id) => id.isNotEmpty)
              .toSet()
              .toList();
      if (groupIds.isEmpty) return <DocView>[];

      final groups = await _db
          .from('groups')
          .select('id, name, creator_id')
          .inFilter('id', groupIds);
      return groups
          .map(
            (g) => _SupabaseRowView({
              'id': g['id'],
              'groupName': g['name'],
              'creatorId': g['creator_id'],
            }),
          )
          .toList();
    });
  }

  Future<void> acceptInvitation(
    String groupId,
    String uid, {
    String? phone,
    String? email,
    String? userName,
  }) async {
    var query = _db
        .from('group_invitations')
        .update({'status': 'accepted'})
        .eq('group_id', groupId);
    if (phone != null && phone.isNotEmpty) {
      query = query.eq('invitee_phone', phone);
    } else if (email != null && email.isNotEmpty) {
      query = query.eq('invitee_email', email);
    }
    await query;

    await addMemberToGroup(groupId, uid);
    if (userName != null && userName.isNotEmpty) {
      await addSystemMessage(groupId, type: 'join', userName: userName, odId: uid);
    }
  }

  Future<void> declineInvitation(
    String groupId, {
    String? phone,
    String? email,
    String? userName,
  }) async {
    var query = _db
        .from('group_invitations')
        .update({'status': 'declined'})
        .eq('group_id', groupId);
    if (phone != null && phone.isNotEmpty) {
      query = query.eq('invitee_phone', phone);
    } else if (email != null && email.isNotEmpty) {
      query = query.eq('invitee_email', email);
    }
    await query;
  }

  Future<void> addSystemMessage(
    String groupId, {
    required String type,
    String userName = '',
    String odId = '',
    String detail = '',
    String prefix = '',
  }) async {
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
    return _db
        .from('system_messages')
        .stream(primaryKey: ['id'])
        .eq('group_id', groupId)
        .order('timestamp')
        .map((rows) => rows.map(_mapSystemMessageRow).toList());
  }

  Future<void> addSettlementEvent(
    String groupId, {
    required String type,
    int? amountMinor,
    String? currencyCode,
    String? paymentAttemptId,
    int? pendingCount,
  }) async {
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
    return _db
        .from('settlement_events')
        .stream(primaryKey: ['id'])
        .eq('group_id', groupId)
        .order('timestamp')
        .map((rows) => rows.map(_mapSettlementEventRow).toList());
  }

  Future<List<Map<String, dynamic>>> getSettlementEvents(String groupId) async {
    final rows = await _db
        .from('settlement_events')
        .select()
        .eq('group_id', groupId)
        .order('timestamp');
    return rows.map(_mapSettlementEventRow).toList();
  }

  Future<void> deleteGroup(String groupId) async {
    await _db.from('groups').delete().eq('id', groupId);
  }

  Future<void> updateGroup(String groupId, Map<String, dynamic> updates) async {
    final mapped = <String, dynamic>{};
    if (updates.containsKey('cycleStatus')) mapped['status'] = updates['cycleStatus'];
    if (updates.containsKey('groupName')) mapped['name'] = updates['groupName'];
    if (updates.containsKey('activeCycleId')) mapped['active_cycle_id'] = updates['activeCycleId'];
    if (updates.containsKey('settlementRhythm')) mapped['settlement_rhythm'] = updates['settlementRhythm'];
    if (updates.containsKey('settlementDay')) mapped['settlement_day'] = updates['settlementDay'];
    if (updates.containsKey('inviteLinkToken')) mapped['invite_link_token'] = updates['inviteLinkToken'];
    if (updates.containsKey('inviteLinkEnabled')) mapped['invite_link_enabled'] = updates['inviteLinkEnabled'];
    if (mapped.isNotEmpty) {
      await _db.from('groups').update(mapped).eq('id', groupId);
    }
  }

  Future<void> addMemberToGroup(String groupId, String uid) async {
    await _db.from('group_members').upsert({'group_id': groupId, 'user_id': uid});
  }

  Future<void> addPendingMemberToGroup(
    String groupId,
    String? phone,
    String name, {
    String? email,
    String? invitedBy,
  }) async {
    await _db.from('group_invitations').upsert({
      'group_id': groupId,
      if (phone != null && phone.isNotEmpty) 'invitee_phone': phone,
      if (email != null && email.isNotEmpty) 'invitee_email': email,
      'inviter_id': invitedBy,
      'status': 'pending',
    });
  }

  Future<void> removeMemberFromGroup(String groupId, String uid) async {
    await _db
        .from('group_members')
        .delete()
        .eq('group_id', groupId)
        .eq('user_id', uid);
  }

  Future<void> removePendingMemberFromGroup(String groupId, String phone) async {
    await _db
        .from('group_invitations')
        .delete()
        .eq('group_id', groupId)
        .eq('invitee_phone', phone)
        .eq('status', 'pending');
  }

  // =====================
  // EXPENSES
  // =====================
  Future<void> addExpense(String groupId, Map<String, dynamic> expenseData) async {
    final id =
        (expenseData['id'] ?? DateTime.now().millisecondsSinceEpoch.toString())
            .toString();
    await _db.from('expenses').insert({
      'id': id,
      'group_id': groupId,
      'cycle_id': expenseData['cycleId'],
      'description': expenseData['description'],
      'amount': expenseData['amount'],
      'amount_minor': expenseData['amountMinor'],
      'expense_date': expenseData['date'],
      'date_sort_key': expenseData['dateSortKey'],
      'category': expenseData['category'],
      'split_type': expenseData['splitType'],
      'paid_by_id': expenseData['payerId'],
      'participant_ids': expenseData['participantIds'],
      'splits': expenseData['splits'],
      'splits_minor': expenseData['splitsMinor'],
      'created_by_id': expenseData['createdById'],
    });
  }

  Future<void> updateExpense(
    String groupId,
    String expenseId,
    Map<String, dynamic> updates,
  ) async {
    final mapped = <String, dynamic>{};
    if (updates.containsKey('amount')) mapped['amount'] = updates['amount'];
    if (updates.containsKey('amountMinor')) {
      mapped['amount_minor'] = updates['amountMinor'];
    }
    if (updates.containsKey('splitsMinor')) {
      mapped['splits_minor'] = updates['splitsMinor'];
    }
    if (updates.containsKey('description')) {
      mapped['description'] = updates['description'];
    }
    if (updates.containsKey('date')) mapped['expense_date'] = updates['date'];
    if (updates.containsKey('dateSortKey')) {
      mapped['date_sort_key'] = updates['dateSortKey'];
    }
    if (updates.containsKey('payerId')) mapped['paid_by_id'] = updates['payerId'];
    if (updates.containsKey('splitType')) {
      mapped['split_type'] = updates['splitType'];
    }
    if (updates.containsKey('participantIds')) {
      mapped['participant_ids'] = updates['participantIds'];
    }
    if (updates.containsKey('splits')) mapped['splits'] = updates['splits'];
    if (updates.containsKey('category')) mapped['category'] = updates['category'];
    if (mapped.isNotEmpty) {
      await _db.from('expenses').update(mapped).eq('id', expenseId);
    }
  }

  Future<void> markExpenseDeleted(
    String groupId,
    String expenseId, {
    String deletedById = '',
  }) async {
    await _db.from('deleted_expenses').insert({
      'expense_id': expenseId,
      'group_id': groupId,
      'deleted_by_id': deletedById,
    });
  }

  Future<void> deleteExpense(String groupId, String expenseId) async {
    await _db.from('expenses').delete().eq('id', expenseId);
  }

  Future<void> addExpenseRevision(
    String groupId, {
    required String expenseId,
    String? replacesExpenseId,
  }) async {
    await _db.from('expense_revisions').insert({
      'expense_id': expenseId,
      'group_id': groupId,
      'replaces_expense_id': replacesExpenseId,
    });
  }

  Stream<List<Map<String, dynamic>>> expenseRevisionsStream(String groupId) {
    return _db
        .from('expense_revisions')
        .stream(primaryKey: ['expense_id'])
        .eq('group_id', groupId)
        .map(
          (rows) => rows
              .map(
                (r) => {
                  'expenseId': r['expense_id'],
                  'replacesExpenseId': r['replaces_expense_id'],
                },
              )
              .toList(),
        );
  }

  Stream<Set<String>> deletedExpenseIdsStream(String groupId) {
    return _db
        .from('deleted_expenses')
        .stream(primaryKey: ['expense_id'])
        .eq('group_id', groupId)
        .map(
          (rows) => rows
              .map((e) => (e['expense_id'] ?? '').toString())
              .where((id) => id.isNotEmpty)
              .toSet(),
        );
  }

  Future<List<Map<String, dynamic>>> getExpenseRevisions(String groupId) async {
    final rows = await _db.from('expense_revisions').select().eq('group_id', groupId);
    return rows
        .map(
          (r) => {
            'expenseId': r['expense_id'],
            'replacesExpenseId': r['replaces_expense_id'],
          },
        )
        .toList();
  }

  Future<Set<String>> getDeletedExpenseIds(String groupId) async {
    final rows = await _db.from('deleted_expenses').select().eq('group_id', groupId);
    return rows
        .map((e) => (e['expense_id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  Stream<List<DocView>> expensesStream(String groupId) {
    return _db
        .from('expenses')
        .stream(primaryKey: ['id'])
        .eq('group_id', groupId)
        .map(
          (rows) => rows
              .map((e) => _SupabaseRowView(_mapExpenseRow(e)))
              .toList(),
        );
  }

  // =====================
  // CYCLES
  // =====================
  Future<void> archiveCycleExpenses(
    String groupId,
    String cycleId,
    String newCycleId, {
    required String startDate,
    required String endDate,
  }) async {
    await _db.from('cycles').insert({
      'id': cycleId,
      'group_id': groupId,
      'status': 'closed',
      'start_date': startDate,
      'end_date': endDate,
    });
    await _db
        .from('expenses')
        .update({'cycle_id': cycleId})
        .eq('group_id', groupId)
        .isFilter('cycle_id', null);
    await _db
        .from('groups')
        .update({'active_cycle_id': newCycleId, 'status': 'active'})
        .eq('id', groupId);
  }

  Future<List<DocView>> getSettledCycles(String groupId) async {
    final cycles = await _db
        .from('cycles')
        .select()
        .eq('group_id', groupId)
        .eq('status', 'closed')
        .order('end_date', ascending: false);
    return cycles
        .map((e) => _SupabaseRowView(_mapCycleRow(e)))
        .toList();
  }

  Stream<List<DocView>> settledCycleExpensesStream(String groupId, String cycleId) {
    return _db
        .from('expenses')
        .stream(primaryKey: ['id'])
        .eq('group_id', groupId)
        .eq('cycle_id', cycleId)
        .map(
          (rows) => rows
              .map((e) => _SupabaseRowView(_mapExpenseRow(e)))
              .toList(),
        );
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
    final now = DateTime.now().millisecondsSinceEpoch;
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
      'created_at': now,
      'updated_at': now,
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
    final update = <String, dynamic>{
      'status': status,
      if (initiatedAt != null) 'initiated_at': initiatedAt,
      if (confirmedAt != null) 'confirmed_at': confirmedAt,
      if (upiTransactionId != null) 'upi_transaction_id': upiTransactionId,
      if (upiResponseCode != null) 'upi_response_code': upiResponseCode,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };
    await _db
        .from('payment_attempts')
        .update(update)
        .eq('group_id', groupId)
        .eq('id', attemptId);
  }

  Stream<List<Map<String, dynamic>>> paymentAttemptsStream(
    String groupId,
    String cycleId,
  ) {
    return _db
        .from('payment_attempts')
        .stream(primaryKey: ['id'])
        .eq('group_id', groupId)
        .eq('cycle_id', cycleId)
        .map((rows) => rows.map(_mapPaymentAttemptRow).toList());
  }

  Future<List<DocView>> getSettledCycleExpenses(String groupId, String cycleId) async {
    final expenses = await _db
        .from('expenses')
        .select()
        .eq('group_id', groupId)
        .eq('cycle_id', cycleId);
    return expenses
        .map((e) => _SupabaseRowView(_mapExpenseRow(e)))
        .toList();
  }

  // =====================
  // FCM / INVITES
  // =====================
  Future<void> storeFcmToken(String uid, String token, String platform) async {
    await _db.from('fcm_tokens').upsert({
      'user_id': uid,
      'token': token,
      'platform': platform,
    });
  }

  Future<void> deleteFcmToken(String uid, String token) async {
    await _db.from('fcm_tokens').delete().eq('user_id', uid).eq('token', token);
  }

  Future<List<String>> getGroupFcmTokens(String groupId) async {
    final members = await _db
        .from('group_members')
        .select('user_id')
        .eq('group_id', groupId);
    final userIds =
        members
            .map((e) => (e['user_id'] ?? '').toString())
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList();
    if (userIds.isEmpty) return <String>[];
    final rows = await _db
        .from('fcm_tokens')
        .select('token')
        .inFilter('user_id', userIds);
    return rows
        .map((e) => (e['token'] ?? '').toString())
        .where((token) => token.isNotEmpty)
        .toList();
  }

  Future<List<String>> getMemberFcmTokens(String uid) async {
    final rows = await _db.from('fcm_tokens').select('token').eq('user_id', uid);
    return rows
        .map((e) => (e['token'] ?? '').toString())
        .where((token) => token.isNotEmpty)
        .toList();
  }

  Future<Map<String, String>?> resolveInviteLink(String groupId, String token) async {
    try {
      final res = await _db
          .from('groups')
          .select('id, name')
          .eq('id', groupId)
          .eq('invite_link_token', token)
          .eq('invite_link_enabled', true)
          .maybeSingle();
      if (res == null) return null;
      return {'groupId': res['id'] as String, 'groupName': res['name'] as String};
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
