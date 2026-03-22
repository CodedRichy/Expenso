import 'dart:async';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../services/sync_status_service.dart';
import '../services/identity_service.dart';
import '../utils/id_utils.dart';
import '../utils/app_logger.dart';
import '../utils/phone_utils.dart';
import '../utils/expense_validation.dart';
import './base_repository.dart';
import './auth_repository.dart';

class _GroupMeta {
  final String activeCycleId;
  final String cycleStatus;
  final String settlementRhythm;
  final int settlementDay;

  _GroupMeta({
    required this.activeCycleId,
    required this.cycleStatus,
    required this.settlementRhythm,
    required this.settlementDay,
  });
}

class GroupRepository extends BaseRepository {
  GroupRepository._();
  static final GroupRepository _instance = GroupRepository._();
  static GroupRepository get instance => _instance;

  final List<Group> _groups = [];
  final Map<String, Member> _membersById = {};
  final List<GroupInvitation> _pendingInvitations = [];
  final Map<String, _GroupMeta> _groupMeta = {};
  
  bool _groupsLoading = false;
  bool _invitationsLoading = false;
  String? _streamError;

  StreamSubscription<List<DocView>>? _groupsSub;
  StreamSubscription<List<DocView>>? _invitationsSub;

  List<Group> get groups => List.unmodifiable(_groups);
  Map<String, Member> get membersById => Map.unmodifiable(_membersById);
  List<GroupInvitation> get pendingInvitations => List.unmodifiable(_pendingInvitations);
  bool get groupsLoading => _groupsLoading;
  bool get invitationsLoading => _invitationsLoading;
  String? get streamError => _streamError;

  void startListening() {
    final auth = AuthRepository.instance;
    if (auth.currentUserId.isEmpty) return;
    
    _streamError = null;
    _groupsSub?.cancel();
    _invitationsSub?.cancel();
    _groupsLoading = true;
    notify();

    _groupsSub = SupabaseService.instance
        .groupsStream(auth.currentUserId)
        .listen(
          _onGroupsSnapshot,
          onError: (e, st) {
            AppLogger.error('groupsStream error', name: 'GroupRepository', error: e, stackTrace: st);
            _groupsLoading = false;
            _streamError = e.toString();
            SyncStatusService.instance.markError(e.toString());
            notify();
          },
        );

    if (auth.currentUserPhone.isNotEmpty || auth.currentUserEmail.isNotEmpty) {
      _invitationsLoading = true;
      _invitationsSub = SupabaseService.instance
          .pendingInvitationsStream(phone: auth.currentUserPhone, email: auth.currentUserEmail)
          .listen(
            _onInvitationsSnapshot,
            onError: (e, st) {
              AppLogger.error('invitationsStream error', name: 'GroupRepository', error: e, stackTrace: st);
              _invitationsLoading = false;
              notify();
            },
          );
    }
  }

  void stopListening() {
    _groupsSub?.cancel();
    _groupsSub = null;
    _invitationsSub?.cancel();
    _invitationsSub = null;
    _groupsLoading = false;
    _groups.clear();
    _membersById.clear();
    _pendingInvitations.clear();
    _groupMeta.clear();
    notify();
  }

  void _onGroupsSnapshot(List<DocView> docs) {
    _groupsLoading = false;
    SyncStatusService.instance.markSynced();
    
    _groups.clear();
    _groupMeta.clear();
    // Keep members that might be needed or will be re-added
    
    for (final doc in docs) {
      final data = doc.data();
      final groupId = doc.id;
      final groupName = data['groupName'] as String? ?? '';
      final members = List<String>.from(data['members'] as List? ?? []);
      final creatorId = data['creatorId'] as String? ?? '';
      final currencyCode = data['currencyCode'] as String? ?? 'INR';
      final activeCycleId = data['activeCycleId'] as String? ?? IdUtils.generateCycleId();
      final cycleStatus = data['cycleStatus'] as String? ?? 'active';
      final pendingList = _extractPendingMembersList(data['pendingMembers']);

      final settlementRhythm = data['settlementRhythm'] as String? ?? 'weekly';
      final settlementDay = data['settlementDay'] as int? ?? 0;

      _groupMeta[groupId] = _GroupMeta(
        activeCycleId: activeCycleId,
        cycleStatus: cycleStatus,
        settlementRhythm: settlementRhythm,
        settlementDay: settlementDay,
      );

      final status = cycleStatus == 'settling' ? 'closing' : (cycleStatus == 'active' ? 'open' : 'settled');
      final statusLine = cycleStatus == 'settling' ? 'Cycle Settled - Pending Restart' : 'Cycle open';

      final memberIds = [
        ...members,
        ...pendingList.map((p) => 'p_${p['phone'] ?? ''}'),
      ];

      _groups.add(Group(
        id: groupId,
        name: groupName,
        status: status,
        amount: 0.0, // Will be updated by CycleRepository/Expense management
        statusLine: statusLine,
        creatorId: creatorId,
        memberIds: memberIds,
        currencyCode: currencyCode,
        inviteLinkToken: data['inviteLinkToken'] as String?,
        inviteLinkEnabled: data['inviteLinkEnabled'] as bool? ?? false,
      ));

      // Update membersById from user cache if available
      for (final uid in members) {
        final cached = AuthRepository.instance.getUserCache(uid);
        if (cached != null) {
          _membersById[uid] = Member(
            id: uid,
            phone: cached['phoneNumber'] as String? ?? '',
            name: cached['displayName'] as String? ?? '',
            photoURL: cached['photoURL'] as String?,
          );
        }
      }

      for (final p in pendingList) {
        final phone = p['phone'] ?? '';
        final name = p['name'] ?? '';
        if (phone.isEmpty) continue;
        final pid = 'p_$phone';
        _membersById[pid] = Member(id: pid, phone: phone, name: name);
      }
    }

    _loadUsersForMembers(docs);
    IdentityService.instance.buildFromGroups(_groups, _membersById, {}); // UserCache needs careful handling
    notify();
  }

  void _onInvitationsSnapshot(List<DocView> docs) {
    _invitationsLoading = false;
    _pendingInvitations.clear();
    for (final doc in docs) {
      final data = doc.data();
      _pendingInvitations.add(GroupInvitation(
        groupId: doc.id,
        groupName: data['groupName'] as String? ?? 'Unknown Group',
        creatorId: data['creatorId'] as String? ?? '',
      ));
    }
    notify();
  }

  List<Map<String, String>> _extractPendingMembersList(dynamic data) {
    if (data == null) return [];
    if (data is List) {
      return data.map((e) => Map<String, String>.from(e as Map)).toList();
    }
    if (data is Map) {
      final list = <Map<String, String>>[];
      data.forEach((k, v) {
        if (v is Map) {
          list.add({
            'phone': k.toString(),
            'name': v['name']?.toString() ?? '',
          });
        }
      });
      return list;
    }
    return [];
  }

  Future<void> _loadUsersForMembers(List<DocView> docs) async {
    final uids = <String>{};
    for (final doc in docs) {
      final members = List<String>.from(doc.data()['members'] as List? ?? []);
      uids.addAll(members);
    }
    for (final uid in uids) {
      final auth = AuthRepository.instance;
      if (auth.getUserCache(uid) != null) continue;
      try {
        final u = await SupabaseService.instance.getUser(uid);
        if (u != null) {
          auth.updateUserCache(uid, u);
          if (!_membersById.containsKey(uid)) {
            _membersById[uid] = Member(
              id: uid,
              phone: u['phoneNumber'] as String? ?? '',
              name: u['displayName'] as String? ?? '',
              photoURL: u['photoURL'] as String?,
            );
          }
        }
      } catch (e, st) {
        AppLogger.error('_loadUsersForMembers error', name: 'GroupRepository', error: e, stackTrace: st, metadata: {'uid': uid});
      }
    }
    notify();
  }

  Group? getGroup(String id) {
    try {
      return _groups.firstWhere((g) => g.id == id);
    } catch (_) {
      return null;
    }
  }

  String getActiveCycleId(String groupId) => _groupMeta[groupId]?.activeCycleId ?? '';
  String getCycleStatus(String groupId) => _groupMeta[groupId]?.cycleStatus ?? 'active';
  
  Future<void> addGroup(
    Group group, {
    String? settlementRhythm,
    int? settlementDay,
  }) async {
    final auth = AuthRepository.instance;
    if (auth.currentUserId.isEmpty) return;
    
    final nameError = validateGroupName(group.name);
    if (nameError != null) throw ArgumentError(nameError);
    
    try {
      await SupabaseService.instance.createGroup(
        group.id,
        groupName: group.name,
        creatorId: auth.currentUserId,
        settlementRhythm: settlementRhythm,
        settlementDay: settlementDay,
        currencyCode: group.currencyCode,
      );
    } catch (e, st) {
      AppLogger.error('addGroup failed', name: 'GroupRepository', error: e, stackTrace: st);
      rethrow;
    }
  }

  void addMemberToGroup(String groupId, Member member) {
    final auth = AuthRepository.instance;
    if (member.id.startsWith('p_') || (member.id.startsWith('m_') && member.id.length < 28)) {
      SupabaseService.instance.addPendingMemberToGroup(
        groupId,
        member.phone,
        member.name,
        invitedBy: auth.currentUserId,
      );
    } else {
      SupabaseService.instance.addMemberToGroup(groupId, member.id);
      auth.updateUserCache(member.id, {
        'displayName': member.name,
        'phoneNumber': member.phone,
      });
      _membersById[member.id] = member;
      notify();
    }
  }

  Future<void> acceptInvitation(String groupId) async {
    final auth = AuthRepository.instance;
    if (auth.currentUserId.isEmpty || auth.currentUserPhone.isEmpty) return;
    await SupabaseService.instance.acceptInvitation(
      groupId,
      auth.currentUserId,
      phone: auth.currentUserPhone,
      email: auth.currentUserEmail,
      userName: auth.currentUserName.isNotEmpty ? auth.currentUserName : 'Someone',
    );
    _pendingInvitations.removeWhere((i) => i.groupId == groupId);
    notify();
  }

  Future<void> declineInvitation(String groupId) async {
    final auth = AuthRepository.instance;
    if (auth.currentUserPhone.isEmpty) return;
    await SupabaseService.instance.declineInvitation(
      groupId,
      phone: auth.currentUserPhone,
      email: auth.currentUserEmail,
      userName: auth.currentUserName.isNotEmpty ? auth.currentUserName : 'Someone',
    );
    _pendingInvitations.removeWhere((i) => i.groupId == groupId);
    notify();
  }

  void removeMemberFromGroup(String groupId, String memberId) {
    if (memberId.startsWith('p_')) {
      final phone = memberId.substring(2);
      SupabaseService.instance.removePendingMemberFromGroup(groupId, phone);
      _membersById.remove(memberId);
      // Local removal from the specific group model instance should be handled by the stream or delegated call
      notify();
    } else {
      SupabaseService.instance.removeMemberFromGroup(groupId, memberId);
      notify();
    }
  }

  bool isCreator(String groupId, String userId) {
    final group = getGroup(groupId);
    return group != null && group.creatorId == userId;
  }

  String getMemberDisplayNameById(String uid) {
    final auth = AuthRepository.instance;
    if (uid.isEmpty) return '';
    if (uid == auth.currentUserId) {
      return auth.currentUserName.isNotEmpty ? auth.currentUserName : 'You';
    }
    
    final m = _membersById[uid];
    if (m != null) {
      final identity = IdentityService.instance.getIdentity(m.email ?? m.phone);
      if (identity != null && identity.displayName.isNotEmpty) return identity.displayName;
      return m.name.isNotEmpty ? m.name : (m.email ?? PhoneUtils.formatDisplay(m.phone));
    }

    final cached = auth.getUserCache(uid);
    if (cached != null) {
      final name = cached['displayName'] as String? ?? '';
      final phone = cached['phoneNumber'] as String? ?? '';
      if (phone.isNotEmpty) {
        final identity = IdentityService.instance.getIdentity(phone);
        if (identity != null && identity.displayName.isNotEmpty) return identity.displayName;
      }
      return name.isNotEmpty ? name : PhoneUtils.formatDisplay(phone);
    }
    return 'Unknown';
  }

  String getMemberDisplayName(String phoneOrUid) {
    final auth = AuthRepository.instance;
    if (phoneOrUid.isEmpty) return '';
    if (IdUtils.isAuthUid(phoneOrUid)) return getMemberDisplayNameById(phoneOrUid);
    
    if (phoneOrUid == auth.currentUserEmail || 
        (phoneOrUid.isNotEmpty && PhoneUtils.normalizeTo10Digits(phoneOrUid) == PhoneUtils.normalizeTo10Digits(auth.currentUserPhone))) {
      return auth.currentUserName.isNotEmpty ? auth.currentUserName : 'You';
    }

    final identity = IdentityService.instance.getIdentity(phoneOrUid);
    if (identity != null && identity.displayName.isNotEmpty) return identity.displayName;

    for (final m in _membersById.values) {
      if (PhoneUtils.normalizeTo10Digits(m.phone) == PhoneUtils.normalizeTo10Digits(phoneOrUid)) {
        return m.name.isNotEmpty ? m.name : PhoneUtils.formatDisplay(m.phone);
      }
    }
    return PhoneUtils.formatDisplay(phoneOrUid);
  }

  List<Member> getMembersForGroup(String groupId) {
    final group = getGroup(groupId);
    if (group == null) return [];
    return group.memberIds
        .map((id) => _membersById[id])
        .whereType<Member>()
        .toList();
  }
}
