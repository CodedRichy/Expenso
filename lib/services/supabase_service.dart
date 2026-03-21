import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/money_minor.dart';
import '../utils/app_logger.dart';

/// Equivalent to DocView in FirestoreService, but for Supabase JSON rows.
abstract class SupabaseRowView {
  String get id;
  Map<String, dynamic> data();
}

class _SupabaseRowView implements SupabaseRowView {
  _SupabaseRowView(this._data) : _id = _data['id'] as String;
  final Map<String, dynamic> _data;
  final String _id;

  @override
  String get id => _id;

  @override
  Map<String, dynamic> data() => _data;
}

/// Service to interact with Supabase Postgres, replacing FirestoreService.
/// This is a scaffold containing the core translation methods.
class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  SupabaseClient get _db => Supabase.instance.client;

  // ==========================================
  // USERS
  // ==========================================

  Future<void> setUser(
    String uid, {
    String? displayName,
    String? phoneNumber,
    String? photoURL,
    String? upiId,
    String? currencyCode,
  }) async {
    final Map<String, dynamic> data = {};
    if (displayName != null) data['display_name'] = displayName;
    if (phoneNumber != null) data['phone'] = phoneNumber;
    if (photoURL != null) data['avatar_url'] = photoURL;
    if (upiId != null) data['upi_id'] = upiId;
    if (currencyCode != null) data['currency_code'] = currencyCode;

    if (data.isEmpty) return;
    
    // Upsert user profile
    data['id'] = uid;
    await _db.from('users').upsert(data);
  }

  Future<Map<String, dynamic>?> getUser(String uid) async {
    try {
      final data = await _db.from('users').select().eq('id', uid).single();
      return data;
    } catch (e) {
      AppLogger.error('getUser failed', name: 'SupabaseService', error: e);
      return null;
    }
  }

  Stream<Map<String, dynamic>?> userStream(String uid) {
    return _db
        .from('users')
        .stream(primaryKey: ['id'])
        .eq('id', uid)
        .map((list) => list.isNotEmpty ? list.first : null);
  }

  // ==========================================
  // GROUPS
  // ==========================================

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
    final groupData = {
      'id': groupId,
      'name': groupName,
      'status': 'active',
      'creator_id': creatorId,
      'currency_code': currencyCode ?? 'INR',
    };

    // Note: In Postgres, this needs to be a transaction to insert group and members.
    // For now, doing sequentially.
    await _db.from('groups').insert(groupData);
    await addMemberToGroup(groupId, creatorId);
  }

  Future<void> addMemberToGroup(String groupId, String uid) async {
    await _db.from('group_members').upsert({
      'group_id': groupId,
      'user_id': uid,
    });
  }

  Stream<List<SupabaseRowView>> groupsStream(String uid) {
    // Requires a view or subquery in Supabase to stream groups for a user.
    // Simplifying to listening to group_members and joining for now.
    // A more advanced Realtime setup might require a custom Postgres function.
    return _db
        .from('group_members')
        .stream(primaryKey: ['group_id', 'user_id'])
        .eq('user_id', uid)
        .asyncMap((members) async {
          if (members.isEmpty) return [];
          final groupIds = members.map((e) => e['group_id']).toList();
          final groups = await _db.from('groups').select().inFilter('id', groupIds);
          return groups.map((g) => _SupabaseRowView(g)).toList();
        });
  }

  // TODO: Implement remaining methods from FirestoreService
  // cycle streams, expense creation, settlement events, etc.
}
