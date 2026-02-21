import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import '../models/cycle.dart';
import '../services/data_encryption_service.dart';
import '../services/firestore_service.dart';
import '../utils/expense_validation.dart';

class CycleRepository extends ChangeNotifier {
  CycleRepository._();

  static final CycleRepository _instance = CycleRepository._();

  static CycleRepository get instance => _instance;

  static String _formatDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}';
  }

  static int _dateStringToSortKey(String date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (date) {
      case 'Today':
        return today.millisecondsSinceEpoch;
      case 'Yesterday':
        return today.subtract(const Duration(days: 1)).millisecondsSinceEpoch;
      default:
        final parsed = DateTime.tryParse(date);
        if (parsed != null) return parsed.millisecondsSinceEpoch;
        final match = RegExp(r'(\w+)\s+(\d+)').firstMatch(date);
        if (match != null) {
          const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
          final monthName = match.group(1)!;
          final day = int.tryParse(match.group(2)!);
          final month = months.indexOf(monthName) + 1;
          if (month >= 1 && month <= 12 && day != null && day >= 1 && day <= 31) {
            var d = DateTime(now.year, month, day);
            if (d.isAfter(today.add(const Duration(days: 1)))) {
              d = DateTime(now.year - 1, month, day);
            }
            return d.millisecondsSinceEpoch;
          }
        }
        return today.millisecondsSinceEpoch;
    }
  }

  static String _nextCycleId() => 'c_${DateTime.now().millisecondsSinceEpoch}';

  /// Current user id; used as creator id when creating a group. From Firebase Auth UID only (no mock).
  String get currentUserId => _currentUserId;
  String _currentUserId = '';

  /// Current user phone; set after phone auth, used for auto-join as creator when creating a group.
  String get currentUserPhone => _currentUserPhone;
  String _currentUserPhone = '';

  /// Global display name for the current user; set in onboarding or via setGlobalProfile.
  String get currentUserName => _currentUserName;
  String _currentUserName = '';

  /// True if the current user is the creator of the group (for Settle & Restart, etc.).
  bool isCurrentUserCreator(String groupId) => isCreator(groupId, _currentUserId);

  /// Current user profile photo URL (from Firestore). Same value used for NLP display name matching.
  String? get currentUserPhotoURL => _userCache[_currentUserId]?['photoURL'] as String?;

  /// Current user UPI ID for payments.
  String? get currentUserUpiId => _userCache[_currentUserId]?['upiId'] as String?;

  /// Updates the global profile (phone, name, and optionally auth user id). Notifies listeners.
  /// Persists to Firestore when [_currentUserId] is set so displayName stays in sync with Groq fuzzy matching.
  void setGlobalProfile(String phone, String name, {String? authUserId}) {
    _currentUserPhone = phone;
    _currentUserName = name.trim();
    if (authUserId != null && authUserId.isNotEmpty) _currentUserId = authUserId;
    if (_currentUserId.isNotEmpty) {
      _writeCurrentUserProfile().catchError((e, st) {
        debugPrint('CycleRepository.setGlobalProfile write failed: $e');
        if (kDebugMode) debugPrint(st.toString());
      });
    }
    notifyListeners();
  }

  /// Sets in-memory identity from Firebase user. Call during build; does not notify.
  /// Use _continueAuthFromFirebaseUser() after the frame for Firestore write/listen.
  void setAuthFromFirebaseUserSync(String uid, String? phone, String? displayName) {
    if (uid.isNotEmpty) _currentUserId = uid;
    if (phone != null && phone.isNotEmpty) _currentUserPhone = phone;
    if (displayName != null && displayName.isNotEmpty) _currentUserName = displayName.trim();
    _userCache[uid] = {
      'displayName': _currentUserName,
      'phoneNumber': _currentUserPhone,
    };
  }

  /// Runs Firestore write, profile load, and listeners. Call after build (e.g. addPostFrameCallback).
  Future<void> continueAuthFromFirebaseUser() async {
    if (_currentUserId.isEmpty) return;
    _encryption = DataEncryptionService(region: 'asia-south1');
    try {
      await _encryption!.ensureUserKey();
    } catch (e) {
      debugPrint('CycleRepository encryption key fetch failed: $e');
      _encryption = null;
    }
    FirestoreService.instance.setEncryptionService(_encryption);
    _writeCurrentUserProfile().catchError((e, st) {
      debugPrint('CycleRepository.continueAuthFromFirebaseUser write failed: $e');
      if (kDebugMode) debugPrint(st.toString());
    });
    _loadCurrentUserProfileFromFirestore();
    _startListening();
    notifyListeners();
  }

  /// Refreshes current user profile (photoURL, upiId) from Firestore. Call when opening Profile so avatar persists after app restart.
  Future<void> refreshCurrentUserProfile() async {
    if (_currentUserId.isEmpty) return;
    await _loadCurrentUserProfileFromFirestore();
  }

  Future<void> _loadCurrentUserProfileFromFirestore() async {
    try {
      final u = await FirestoreService.instance.getUser(_currentUserId);
      if (u != null && _userCache.containsKey(_currentUserId)) {
        final cur = Map<String, dynamic>.from(_userCache[_currentUserId]!);
        if (u['photoURL'] != null) cur['photoURL'] = u['photoURL'];
        if (u['upiId'] != null) cur['upiId'] = u['upiId'];
        _userCache[_currentUserId] = cur;
        notifyListeners();
      }
    } catch (e, st) {
      debugPrint('CycleRepository._loadCurrentUserProfileFromFirestore failed: $e');
      if (kDebugMode) debugPrint(st.toString());
    }
  }

  Future<void> _writeCurrentUserProfile() async {
    final cache = _userCache[_currentUserId];
    await FirestoreService.instance.setUser(
      _currentUserId,
      displayName: _currentUserName,
      phoneNumber: _currentUserPhone,
      photoURL: cache?['photoURL'] as String?,
      upiId: cache?['upiId'] as String?,
    );
  }

  /// Updates current user photo URL (e.g. after upload). Persists to Firestore.
  /// Throws if the Firestore write fails so the UI can show an error.
  Future<void> updateCurrentUserPhotoURL(String? photoURL) async {
    if (_currentUserId.isEmpty) return;
    _userCache[_currentUserId] ??= <String, dynamic>{};
    final previous = _userCache[_currentUserId]!['photoURL'];
    _userCache[_currentUserId]!['photoURL'] = photoURL;
    try {
      await _writeCurrentUserProfile();
      notifyListeners();
    } catch (e, st) {
      _userCache[_currentUserId]!['photoURL'] = previous;
      notifyListeners();
      debugPrint('CycleRepository.updateCurrentUserPhotoURL write failed: $e');
      if (kDebugMode) debugPrint(st.toString());
      rethrow;
    }
  }

  /// Updates current user UPI ID. Persists to Firestore.
  Future<void> updateCurrentUserUpiId(String? upiId) async {
    if (_currentUserId.isEmpty) return;
    _userCache[_currentUserId] ??= <String, dynamic>{};
    _userCache[_currentUserId]!['upiId'] = upiId;
    await _writeCurrentUserProfile();
    notifyListeners();
  }

  /// Returns profile photo URL for a member (by uid). Null for pending members or when not set.
  String? getMemberPhotoURL(String memberId) {
    if (memberId.startsWith('p_')) return null;
    return _userCache[memberId]?['photoURL'] as String?;
  }

  DataEncryptionService? _encryption;

  /// Clears auth-derived identity (e.g. on sign-out). Stops Firestore listeners.
  void clearAuth() {
    _stopListening();
    _encryption?.clearKeys();
    _encryption = null;
    FirestoreService.instance.setEncryptionService(null);
    _groupsLoading = false;
    _currentUserId = '';
    _currentUserPhone = '';
    _currentUserName = '';
    _groups.clear();
    _membersById.clear();
    _expensesByCycleId.clear();
    _groupMeta.clear();
    _userCache.clear();
    _clearLastAdded();
    _streamError = null;
    notifyListeners();
  }

  String? _lastAddedGroupId;
  String? _lastAddedExpenseId;
  String? _lastAddedDescription;
  double? _lastAddedAmount;

  String? get lastAddedGroupId => _lastAddedGroupId;
  String? get lastAddedExpenseId => _lastAddedExpenseId;
  String? get lastAddedDescription => _lastAddedDescription;
  double? get lastAddedAmount => _lastAddedAmount;

  void _setLastAdded(String groupId, String expenseId, String description, double amount) {
    _lastAddedGroupId = groupId;
    _lastAddedExpenseId = expenseId;
    _lastAddedDescription = description;
    _lastAddedAmount = amount;
  }

  void _clearLastAdded() {
    _lastAddedGroupId = null;
    _lastAddedExpenseId = null;
    _lastAddedDescription = null;
    _lastAddedAmount = null;
  }

  void clearLastAdded() => _clearLastAdded();

  final List<Group> _groups = [];
  final Map<String, Member> _membersById = {};
  /// cycleId -> list of expenses for that cycle (current cycle per group).
  final Map<String, List<Expense>> _expensesByCycleId = {};
  /// groupId -> { activeCycleId, cycleStatus } from Firestore.
  final Map<String, _GroupMeta> _groupMeta = {};
  final Map<String, Map<String, dynamic>> _userCache = {};

  StreamSubscription<List<DocView>>? _groupsSub;
  StreamSubscription<List<DocView>>? _invitationsSub;
  final Map<String, StreamSubscription<List<DocView>>> _expenseSubs = {};
  final Map<String, StreamSubscription<List<Map<String, dynamic>>>> _systemMessageSubs = {};

  /// Pending group invitations for the current user.
  final List<GroupInvitation> _pendingInvitations = [];
  List<GroupInvitation> get pendingInvitations => List.unmodifiable(_pendingInvitations);

  /// System messages per group (groupId -> list of messages).
  final Map<String, List<SystemMessage>> _systemMessagesByGroup = {};
  List<SystemMessage> getSystemMessages(String groupId) =>
      List.unmodifiable(_systemMessagesByGroup[groupId] ?? []);

  /// True while waiting for the first Firestore groups snapshot (for skeleton UX).
  bool get groupsLoading => _groupsLoading;
  bool _groupsLoading = false;

  String? _streamError;
  String? get streamError => _streamError;
  void clearStreamError() {
    if (_streamError == null) return;
    _streamError = null;
    notifyListeners();
  }

  void _startListening() {
    if (_currentUserId.isEmpty) return;
    _streamError = null;
    _groupsSub?.cancel();
    _invitationsSub?.cancel();
    _groupsLoading = true;
    notifyListeners();
    _groupsSub = FirestoreService.instance.groupsStream(_currentUserId).listen(
      _onGroupsSnapshot,
      onError: (e, st) {
        debugPrint('CycleRepository groupsStream error: $e');
        if (kDebugMode && st != null) debugPrint(st.toString());
        _groupsLoading = false;
        _streamError = e.toString();
        notifyListeners();
      },
    );
    if (_currentUserPhone.isNotEmpty) {
      _invitationsSub = FirestoreService.instance.pendingInvitationsStream(_currentUserPhone).listen(
        _onInvitationsSnapshot,
        onError: (e, st) {
          debugPrint('CycleRepository invitationsStream error: $e');
          if (kDebugMode && st != null) debugPrint(st.toString());
        },
      );
    }
  }

  void _onInvitationsSnapshot(List<DocView> docs) {
    _pendingInvitations.clear();
    for (final doc in docs) {
      final data = doc.data();
      _pendingInvitations.add(GroupInvitation(
        groupId: doc.id,
        groupName: data['groupName'] as String? ?? 'Unknown Group',
        creatorId: data['creatorId'] as String? ?? '',
      ));
    }
    notifyListeners();
  }

  /// DEBUG: Add dummy invitations for testing. Call removeDummyInvitation() to remove.
  void addDummyInvitation() {
    if (_pendingInvitations.any((i) => i.groupId == 'dummy_test_group_1')) return;
    _pendingInvitations.addAll(const [
      GroupInvitation(
        groupId: 'dummy_test_group_1',
        groupName: 'Weekend Trip',
        creatorId: 'alice_uid',
      ),
      GroupInvitation(
        groupId: 'dummy_test_group_2',
        groupName: 'Roommates',
        creatorId: 'bob_uid',
      ),
      GroupInvitation(
        groupId: 'dummy_test_group_3',
        groupName: 'Office Lunch',
        creatorId: 'carol_uid',
      ),
      GroupInvitation(
        groupId: 'dummy_test_group_4',
        groupName: 'Birthday Party',
        creatorId: 'dave_uid',
      ),
    ]);
    notifyListeners();
  }

  /// DEBUG: Remove all dummy invitations.
  void removeDummyInvitation() {
    _pendingInvitations.removeWhere((i) => i.groupId.startsWith('dummy_test_group'));
    notifyListeners();
  }

  /// DEBUG: Add a dummy group for testing. Call removeDummyGroup() to remove.
  void addDummyGroup() {
    if (_groups.any((g) => g.id == 'dummy_weekend_trip')) return;
    _groups.insert(0, Group(
      id: 'dummy_weekend_trip',
      name: 'Weekend Trip',
      status: 'active',
      amount: 2400,
      statusLine: '+₹800',
      creatorId: 'alice_uid',
      memberIds: ['alice_uid', 'bob_uid', 'carol_uid', _currentUserId],
    ));
    _membersById['alice_uid'] = Member(id: 'alice_uid', phone: '9876543210', name: 'Alice');
    _membersById['bob_uid'] = Member(id: 'bob_uid', phone: '9876543211', name: 'Bob');
    _membersById['carol_uid'] = Member(id: 'carol_uid', phone: '9876543212', name: 'Carol');
    _groupMeta['dummy_weekend_trip'] = _GroupMeta(
      activeCycleId: 'dummy_cycle',
      cycleStatus: 'active',
    );
    _expensesByCycleId['dummy_cycle'] = [
      Expense(
        id: 'exp1',
        description: 'Hotel booking',
        amount: 1200,
        date: 'Today',
        paidById: 'alice_uid',
        participantIds: ['alice_uid', 'bob_uid', 'carol_uid', _currentUserId],
      ),
      Expense(
        id: 'exp2',
        description: 'Dinner',
        amount: 800,
        date: 'Today',
        paidById: _currentUserId,
        participantIds: ['alice_uid', 'bob_uid', 'carol_uid', _currentUserId],
      ),
      Expense(
        id: 'exp3',
        description: 'Fuel',
        amount: 400,
        date: 'Yesterday',
        paidById: 'bob_uid',
        participantIds: ['alice_uid', 'bob_uid', 'carol_uid', _currentUserId],
      ),
    ];
    notifyListeners();
  }

  /// DEBUG: Remove the dummy group.
  void removeDummyGroup() {
    _groups.removeWhere((g) => g.id == 'dummy_weekend_trip');
    _membersById.remove('alice_uid');
    _membersById.remove('bob_uid');
    _membersById.remove('carol_uid');
    _groupMeta.remove('dummy_weekend_trip');
    _expensesByCycleId.remove('dummy_cycle');
    notifyListeners();
  }

  void _stopListening() {
    _groupsSub?.cancel();
    _groupsSub = null;
    _invitationsSub?.cancel();
    _invitationsSub = null;
    _groupsLoading = false;
    _pendingInvitations.clear();
    for (final sub in _expenseSubs.values) {
      sub.cancel();
    }
    _expenseSubs.clear();
    for (final sub in _systemMessageSubs.values) {
      sub.cancel();
    }
    _systemMessageSubs.clear();
    _systemMessagesByGroup.clear();
  }

  void restartListening() {
    clearStreamError();
    _stopListening();
    _startListening();
  }

  void _onGroupsSnapshot(List<DocView> docs) {
    _groupsLoading = false;
    final newIds = docs.map((d) => d.id).toSet();
    for (final id in _expenseSubs.keys.toList()) {
      if (!newIds.contains(id)) {
        _expenseSubs[id]?.cancel();
        _expenseSubs.remove(id);
      }
    }
    for (final id in _systemMessageSubs.keys.toList()) {
      if (!newIds.contains(id)) {
        _systemMessageSubs[id]?.cancel();
        _systemMessageSubs.remove(id);
        _systemMessagesByGroup.remove(id);
      }
    }

    _groups.clear();
    _groupMeta.clear();
    _membersById.clear();
    for (final doc in docs) {
      final data = doc.data();
      final groupId = doc.id;
      final groupName = data['groupName'] as String? ?? '';
      final members = List<String>.from(data['members'] as List? ?? []);
      final creatorId = data['creatorId'] as String? ?? '';
      final activeCycleId = data['activeCycleId'] as String? ?? _nextCycleId();
      final cycleStatus = data['cycleStatus'] as String? ?? 'active';
      final pendingList = (data['pendingMembers'] as List?)
          ?.map((e) => Map<String, String>.from((e as Map).map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''))))
          .toList() ?? <Map<String, String>>[];

      _groupMeta[groupId] = _GroupMeta(activeCycleId: activeCycleId, cycleStatus: cycleStatus);
      final status = cycleStatus == 'settling' ? 'closing' : (cycleStatus == 'active' ? 'open' : 'settled');
      final expenses = _expensesByCycleId[activeCycleId] ?? [];
      final pendingAmount = expenses.fold<double>(0.0, (s, e) => s + e.amount);
      final statusLine = cycleStatus == 'settling' ? 'Cycle Settled - Pending Restart' : 'Cycle open';

      final memberIds = <String>[
        ...members,
        ...pendingList.map((p) => 'p_${p['phone'] ?? ''}'),
      ];
      _groups.add(Group(
        id: groupId,
        name: groupName,
        status: status,
        amount: pendingAmount,
        statusLine: statusLine,
        creatorId: creatorId,
        memberIds: memberIds,
      ));

      for (final g in _groups) {
        final meta = _groupMeta[g.id];
        if (meta == null) continue;
        for (final uid in g.memberIds.where((id) => !id.startsWith('p_'))) {
          if (!_membersById.containsKey(uid) && _userCache.containsKey(uid)) {
            final u = _userCache[uid]!;
            _membersById[uid] = Member(
              id: uid,
              phone: u['phoneNumber'] as String? ?? '',
              name: u['displayName'] as String? ?? '',
              photoURL: u['photoURL'] as String?,
            );
          }
        }
        final groupData = docs.where((d) => d.id == g.id);
        if (groupData.isEmpty) continue;
        final d = groupData.first.data();
        final pending = (d['pendingMembers'] as List?)
            ?.map((e) => Map<String, String>.from((e as Map).map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''))))
            .toList() ?? <Map<String, String>>[];
        for (final p in pending) {
          final phone = p['phone'] ?? '';
          final name = p['name'] ?? '';
          if (phone.isEmpty) continue;
          final pid = 'p_$phone';
          _membersById[pid] = Member(id: pid, phone: phone, name: name);
        }
      }

      if (!_expenseSubs.containsKey(groupId)) {
        _expenseSubs[groupId] = FirestoreService.instance.expensesStream(groupId).listen(
          (expDocs) => _onExpensesSnapshot(groupId, expDocs),
          onError: (e, st) {
            debugPrint('CycleRepository expensesStream($groupId) error: $e');
            if (kDebugMode && st != null) debugPrint(st.toString());
            _streamError = e.toString();
            notifyListeners();
          },
        );
      }
      if (!_systemMessageSubs.containsKey(groupId)) {
        _systemMessageSubs[groupId] = FirestoreService.instance.systemMessagesStream(groupId).listen(
          (msgs) => _onSystemMessagesSnapshot(groupId, msgs),
          onError: (e, st) {
            debugPrint('CycleRepository systemMessagesStream($groupId) error: $e');
          },
        );
      }
    }

    _loadUsersForMembers(docs);
    notifyListeners();
  }

  Future<void> _loadUsersForMembers(List<DocView> docs) async {
    final uids = <String>{};
    for (final doc in docs) {
      final members = List<String>.from(doc.data()['members'] as List? ?? []);
      uids.addAll(members);
    }
    for (final uid in uids) {
      if (_userCache.containsKey(uid)) continue;
      try {
        final u = await FirestoreService.instance.getUser(uid);
        if (u != null) {
          _userCache[uid] = u;
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
        debugPrint('CycleRepository._loadUsersForMembers error for uid $uid: $e');
        if (kDebugMode) debugPrint(st.toString());
      }
    }
    notifyListeners();
  }

  void _onExpensesSnapshot(String groupId, List<DocView> expDocs) {
    final meta = _groupMeta[groupId];
    if (meta == null) return;
    final cycleId = meta.activeCycleId;
    final list = expDocs.map((d) => _expenseFromFirestore(d.data(), d.id)).toList();
    _expensesByCycleId[cycleId] = list;
    _refreshGroupAmounts();
    notifyListeners();
  }

  void _onSystemMessagesSnapshot(String groupId, List<Map<String, dynamic>> msgs) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    
    _systemMessagesByGroup[groupId] = msgs.map((m) {
      final ts = m['timestamp'] as int? ?? 0;
      final dt = DateTime.fromMillisecondsSinceEpoch(ts);
      String dateStr;
      if (dt.year == today.year && dt.month == today.month && dt.day == today.day) {
        dateStr = 'Today';
      } else if (dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day) {
        dateStr = 'Yesterday';
      } else {
        dateStr = _formatDate(dt);
      }
      return SystemMessage(
        id: m['id'] as String? ?? '',
        type: m['type'] as String? ?? '',
        userId: m['userId'] as String? ?? '',
        userName: m['userName'] as String? ?? '',
        date: dateStr,
        timestamp: ts,
      );
    }).toList();
    notifyListeners();
  }

  String _phoneForUid(String uid) {
    if (uid == _currentUserId) return _currentUserPhone;
    return _membersById[uid]?.phone ?? _userCache[uid]?['phoneNumber'] as String? ?? '';
  }

  Expense _expenseFromFirestore(Map<String, dynamic> data, String id) {
    final amount = (data['amount'] is num) ? (data['amount'] as num).toDouble() : 0.0;
    final payerId = data['payerId'] as String? ?? '';
    final splits = data['splits'] as Map<String, dynamic>?;
    final participantIdsRaw = data['participantIds'] as List<dynamic>?;
    final participantIds = participantIdsRaw
            ?.map((e) => e?.toString())
            .where((s) => s != null && s.isNotEmpty)
            .cast<String>()
            .toList() ??
        splits?.keys.toList() ??
        [];
    final splitAmountsById = <String, double>{};
    for (final uid in participantIds) {
      final amt = splits != null && splits.containsKey(uid)
          ? ((splits[uid] is num) ? (splits[uid] as num).toDouble() : double.tryParse(splits[uid]?.toString() ?? '') ?? 0.0)
          : 0.0;
      splitAmountsById[uid] = amt;
    }
    if (splitAmountsById.isEmpty && splits != null) {
      for (final entry in splits.entries) {
        splitAmountsById[entry.key as String] = (entry.value is num)
            ? (entry.value as num).toDouble()
            : double.tryParse(entry.value?.toString() ?? '') ?? 0.0;
      }
    }
    final splitType = (data['splitType'] as String?)?.trim().isNotEmpty == true
        ? (data['splitType'] as String).trim()
        : 'Even';
    return Expense(
      id: id,
      description: data['description'] as String? ?? '',
      amount: amount,
      date: data['date'] as String? ?? 'Today',
      participantIds: participantIds,
      paidById: payerId,
      splitAmountsById: splitAmountsById.isEmpty ? null : splitAmountsById,
      category: data['category'] as String? ?? '',
      splitType: splitType,
    );
  }

  void _refreshGroupAmounts() {
    for (var i = 0; i < _groups.length; i++) {
      final g = _groups[i];
      final meta = _groupMeta[g.id];
      if (meta == null) continue;
      final expenses = _expensesByCycleId[meta.activeCycleId] ?? [];
      final amount = expenses.fold<double>(0.0, (s, e) => s + e.amount);
      final status = meta.cycleStatus == 'settling' ? 'closing' : (meta.cycleStatus == 'active' ? 'open' : 'settled');
      final statusLine = meta.cycleStatus == 'settling' ? 'Cycle Settled - Pending Restart' : 'Cycle open';
      _groups[i] = Group(
        id: g.id,
        name: g.name,
        status: status,
        amount: amount,
        statusLine: statusLine,
        creatorId: g.creatorId,
        memberIds: g.memberIds,
      );
    }
  }

  List<Group> get groups => List.unmodifiable(_groups);

  Future<void> addGroup(
    Group group, {
    String? settlementRhythm,
    int? settlementDay,
  }) async {
    if (_currentUserId.isEmpty) return;
    final groupId = group.id;
    try {
      await FirestoreService.instance.createGroup(
        groupId,
        groupName: group.name,
        creatorId: _currentUserId,
        settlementRhythm: settlementRhythm,
        settlementDay: settlementDay,
      );
    } catch (e, st) {
      debugPrint('CycleRepository.addGroup createGroup failed: $e');
      if (kDebugMode) debugPrint(st.toString());
      rethrow;
    }
    _writeCurrentUserProfile().catchError((e, st) {
      debugPrint('CycleRepository.addGroup profile write failed: $e');
      if (kDebugMode) debugPrint(st.toString());
    });
  }

  Group? getGroup(String id) {
    try {
      return _groups.firstWhere((g) => g.id == id);
    } catch (_) {
      return null;
    }
  }

  double getGroupPendingAmount(String groupId) {
    final cycle = getActiveCycle(groupId);
    final expenses = getExpenses(cycle.id);
    return expenses.fold<double>(0.0, (total, e) => total + e.amount);
  }

  List<Member> getMembersForGroup(String groupId) {
    final group = getGroup(groupId);
    if (group == null) return [];
    return group.memberIds
        .map((id) => _membersById[id])
        .whereType<Member>()
        .toList();
  }

  String getMemberDisplayNameById(String uid) {
    if (uid.isEmpty) return '';
    if (uid == _currentUserId) return _currentUserName.isNotEmpty ? _currentUserName : 'You';
    final m = _membersById[uid];
    if (m != null) return m.name.isNotEmpty ? m.name : _formatPhone(m.phone);
    final u = _userCache[uid];
    if (u != null) {
      final name = u['displayName'] as String? ?? '';
      final phone = u['phoneNumber'] as String? ?? '';
      return name.isNotEmpty ? name : _formatPhone(phone);
    }
    return 'Unknown';
  }

  String getMemberDisplayName(String phoneOrUid) {
    if (phoneOrUid.isEmpty) return '';
    if (_looksLikeUid(phoneOrUid)) return getMemberDisplayNameById(phoneOrUid);
    if (_normalizePhone(phoneOrUid) == _normalizePhone(_currentUserPhone)) {
      return _currentUserName.isNotEmpty ? _currentUserName : 'You';
    }
    for (final m in _membersById.values) {
      if (_normalizePhone(m.phone) == _normalizePhone(phoneOrUid)) {
        return m.name.isNotEmpty ? m.name : _formatPhone(m.phone);
      }
    }
    return _formatPhone(phoneOrUid);
  }

  static bool _looksLikeUid(String s) {
    if (s.length < 20 || s.length > 128) return false;
    return RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(s);
  }

  static String _formatPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 11 && digits.startsWith('91')) return '+91 ${digits.substring(2, 7)} ${digits.substring(7)}';
    if (digits.length == 10) return '+91 ${digits.substring(0, 5)} ${digits.substring(5)}';
    return phone;
  }

  static String _normalizePhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 11 && digits.startsWith('91')) return digits.substring(digits.length - 10);
    if (digits.length >= 10) return digits.substring(digits.length - 10);
    return digits;
  }

  void addMemberToGroup(String groupId, Member member) {
    if (member.id.startsWith('p_') || (member.id.startsWith('m_') && member.id.length < 28)) {
      FirestoreService.instance.addPendingMemberToGroup(groupId, member.phone, member.name);
      _refreshGroupPendingMembersLocally(groupId, member);
    } else {
      FirestoreService.instance.addMemberToGroup(groupId, member.id);
      _userCache[member.id] = {'displayName': member.name, 'phoneNumber': member.phone};
      _membersById[member.id] = member;
      notifyListeners();
    }
  }

  void _refreshGroupPendingMembersLocally(String groupId, Member newPending) {
    final idx = _groups.indexWhere((g) => g.id == groupId);
    if (idx < 0) return;
    final g = _groups[idx];
    final pid = 'p_${newPending.phone}';
    if (g.memberIds.contains(pid)) return;
    _membersById[pid] = newPending;
    _groups[idx] = Group(
      id: g.id,
      name: g.name,
      status: g.status,
      amount: g.amount,
      statusLine: g.statusLine,
      creatorId: g.creatorId,
      memberIds: [...g.memberIds, pid],
    );
    notifyListeners();
  }

  /// Accept a group invitation: moves current user from pending to members.
  Future<void> acceptInvitation(String groupId) async {
    if (_currentUserId.isEmpty || _currentUserPhone.isEmpty) return;
    await FirestoreService.instance.acceptInvitation(
      groupId,
      _currentUserId,
      _currentUserPhone,
      userName: _currentUserName.isNotEmpty ? _currentUserName : 'Someone',
    );
    _pendingInvitations.removeWhere((i) => i.groupId == groupId);
    notifyListeners();
  }

  /// Decline a group invitation: removes current user from pending members.
  Future<void> declineInvitation(String groupId) async {
    if (_currentUserPhone.isEmpty) return;
    await FirestoreService.instance.declineInvitation(
      groupId,
      _currentUserPhone,
      userName: _currentUserName.isNotEmpty ? _currentUserName : 'Someone',
    );
    _pendingInvitations.removeWhere((i) => i.groupId == groupId);
    notifyListeners();
  }

  void removeMemberFromGroup(String groupId, String memberId) {
    if (memberId.startsWith('p_')) {
      final phone = memberId.substring(2);
      FirestoreService.instance.removePendingMemberFromGroup(groupId, phone);
      _membersById.remove(memberId);
      final idx = _groups.indexWhere((g) => g.id == groupId);
      if (idx >= 0) {
        final g = _groups[idx];
        _groups[idx] = Group(
          id: g.id,
          name: g.name,
          status: g.status,
          amount: g.amount,
          statusLine: g.statusLine,
          creatorId: g.creatorId,
          memberIds: g.memberIds.where((id) => id != memberId).toList(),
        );
      }
      notifyListeners();
    } else {
      FirestoreService.instance.removeMemberFromGroup(groupId, memberId);
      notifyListeners();
    }
  }

  bool isCreator(String groupId, String userId) {
    final group = getGroup(groupId);
    return group != null && group.creatorId == userId;
  }

  bool canEditCycle(String groupId, String userId) {
    final meta = _groupMeta[groupId];
    if (meta == null) return false;
    if (meta.cycleStatus == 'settling') return false;
    if (isCreator(groupId, userId)) return true;
    return meta.cycleStatus == 'active';
  }

  bool canDeleteGroup(String groupId, String userId) {
    return isCreator(groupId, userId);
  }

  Cycle getActiveCycle(String groupId) {
    final meta = _groupMeta[groupId];
    final group = getGroup(groupId);
    if (meta != null && group != null) {
      final status = meta.cycleStatus == 'settling' ? CycleStatus.settling : CycleStatus.active;
      final expenses = _expensesByCycleId[meta.activeCycleId] ?? [];
      return Cycle(
        id: meta.activeCycleId,
        groupId: groupId,
        status: status,
        startDate: _formatDate(DateTime.now()),
        expenses: expenses,
      );
    }
    final now = DateTime.now();
    final newCycleId = _nextCycleId();
    return Cycle(
      id: newCycleId,
      groupId: groupId,
      status: CycleStatus.active,
      startDate: _formatDate(now),
      expenses: [],
    );
  }

  List<Expense> getExpenses(String cycleId) {
    final list = _expensesByCycleId[cycleId];
    return list != null ? List.unmodifiable(list) : [];
  }

  /// Resolve phone to UID (current user or from cache). Uses normalized phone so formats match.
  String? _uidForPhone(String phone) {
    if (phone.isEmpty) return null;
    final n = _normalizePhone(phone);
    if (n == _normalizePhone(_currentUserPhone)) return _currentUserId;
    for (final e in _userCache.entries) {
      final cached = e.value['phoneNumber'] as String? ?? '';
      if (_normalizePhone(cached) == n) return e.key;
    }
    for (final m in _membersById.values) {
      if (_normalizePhone(m.phone) == n) return m.id.startsWith('p_') ? null : m.id;
    }
    return null;
  }

  Future<void> addExpense(String groupId, Expense expense) async {
    final amountError = validateExpenseAmount(expense.amount);
    if (amountError != null) throw ArgumentError(amountError);
    final descError = validateExpenseDescription(expense.description);
    if (descError != null) throw ArgumentError(descError);

    final meta = _groupMeta[groupId];
    final cycleId = meta?.activeCycleId;
    if (cycleId == null) {
      throw ArgumentError('No active cycle. Start a new cycle to add expenses.');
    }
    final payerId = expense.paidById.isNotEmpty ? expense.paidById : _currentUserId;
    final members = getMembersForGroup(groupId);
    final realMemberIds = members.where((m) => !m.id.startsWith('p_')).map((m) => m.id).toList();
    final participantIds = expense.participantIds.isNotEmpty
        ? expense.participantIds
        : (realMemberIds.isNotEmpty ? realMemberIds : [_currentUserId]);
    final splits = <String, double>{};
    if (expense.splitAmountsById != null && expense.splitAmountsById!.isNotEmpty) {
      for (final e in expense.splitAmountsById!.entries) {
        if (!e.key.startsWith('p_')) splits[e.key] = e.value;
      }
    }
    if (splits.isEmpty) {
      final perShare = expense.amount / participantIds.length;
      for (final uid in participantIds) {
        if (!uid.startsWith('p_')) splits[uid] = perShare;
      }
    }
    if (splits.isEmpty) splits[payerId] = expense.amount;
    final uids = splits.keys.toList();
    final data = {
      'id': expense.id,
      'groupId': groupId,
      'amount': expense.amount,
      'payerId': payerId,
      'splitType': expense.splitType.isNotEmpty ? expense.splitType : 'Even',
      'participantIds': uids,
      'splits': splits.map((k, v) => MapEntry(k, v)),
      'description': expense.description,
      'date': expense.date,
      'dateSortKey': _dateStringToSortKey(expense.date),
      if (expense.category.isNotEmpty) 'category': expense.category,
    };
    await FirestoreService.instance.addExpense(groupId, data);
    _setLastAdded(groupId, expense.id, expense.description, expense.amount);
  }

  /// Adds an expense from the Magic Bar confirmation flow. All person references by member id.
  Future<void> addExpenseFromMagicBar(
    String groupId, {
    required String id,
    required String description,
    required double amount,
    required String date,
    required String payerId,
    required String splitType,
    required List<String> participantIds,
    List<String>? excludedIds,
    Map<String, double>? exactAmountsById,
    String category = '',
  }) async {
    final amountError = validateExpenseAmount(amount);
    if (amountError != null) throw ArgumentError(amountError);
    final descError = validateExpenseDescription(description);
    if (descError != null) throw ArgumentError(descError);

    final meta = _groupMeta[groupId];
    final cycleId = meta?.activeCycleId;
    if (cycleId == null) {
      throw ArgumentError('No active cycle. Start a new cycle to add expenses.');
    }
    final effectivePayerId = payerId.isNotEmpty ? payerId : _currentUserId;
    final members = getMembersForGroup(groupId);
    final allIds = members.where((m) => !m.id.startsWith('p_')).map((m) => m.id).toList();

    List<String> idsInSplit = [];
    Map<String, double> splitsById = {};

    if (splitType == 'Exact' && exactAmountsById != null && exactAmountsById.isNotEmpty) {
      idsInSplit = exactAmountsById.keys.where((k) => !k.startsWith('p_')).toList();
      for (final e in exactAmountsById.entries) {
        if (!e.key.startsWith('p_')) splitsById[e.key] = e.value;
      }
    } else if (splitType == 'Exclude' && excludedIds != null && excludedIds.isNotEmpty) {
      final excludedSet = excludedIds.toSet();
      idsInSplit = allIds.where((id) => !excludedSet.contains(id)).toList();
      if (idsInSplit.isEmpty) idsInSplit = [effectivePayerId];
      final perShare = amount / idsInSplit.length;
      for (final uid in idsInSplit) {
        splitsById[uid] = perShare;
      }
    } else {
      idsInSplit = participantIds.isNotEmpty
          ? participantIds.where((id) => !id.startsWith('p_')).toList()
          : allIds;
      if (idsInSplit.isEmpty) idsInSplit = [effectivePayerId];
      final perShare = amount / idsInSplit.length;
      for (final uid in idsInSplit) {
        splitsById[uid] = perShare;
      }
    }

    final splits = <String, double>{};
    for (final uid in idsInSplit) {
      splits[uid] = splitsById[uid] ?? 0.0;
    }
    if (splits.isEmpty) splits[effectivePayerId] = amount;

    final writtenParticipantIds = splits.keys.toList();
    final data = {
      'id': id,
      'groupId': groupId,
      'amount': amount,
      'payerId': effectivePayerId,
      'splitType': splitType,
      'participantIds': writtenParticipantIds,
      'splits': splits.map((k, v) => MapEntry(k, v)),
      'description': description,
      'date': date,
      'dateSortKey': _dateStringToSortKey(date),
      if (category.isNotEmpty) 'category': category,
    };
    await FirestoreService.instance.addExpense(groupId, data);
    _setLastAdded(groupId, id, description, amount);
  }

  Expense? getExpense(String groupId, String expenseId) {
    final meta = _groupMeta[groupId];
    if (meta == null) return null;
    final list = _expensesByCycleId[meta.activeCycleId];
    if (list == null) return null;
    try {
      return list.firstWhere((e) => e.id == expenseId);
    } catch (_) {
      return null;
    }
  }

  void updateExpense(String groupId, Expense updatedExpense) {
    final amountError = validateExpenseAmount(updatedExpense.amount);
    if (amountError != null) throw ArgumentError(amountError);
    final descError = validateExpenseDescription(updatedExpense.description);
    if (descError != null) throw ArgumentError(descError);

    final meta = _groupMeta[groupId];
    if (meta == null) return;
    final payerId = updatedExpense.paidById.isNotEmpty ? updatedExpense.paidById : _currentUserId;

    final Map<String, double> splits;
    final String splitType;
    List<String> participantIds;
    if (updatedExpense.splitAmountsById != null && updatedExpense.splitAmountsById!.isNotEmpty) {
      splits = Map.from(updatedExpense.splitAmountsById!);
      if (splits.isEmpty) splits[payerId] = updatedExpense.amount;
      splitType = updatedExpense.splitType;
      participantIds = splits.keys.toList();
    } else {
      final ids = updatedExpense.participantIds.isNotEmpty
          ? updatedExpense.participantIds
          : [payerId];
      final perShare = updatedExpense.amount / ids.length;
      splits = {for (final uid in ids) uid: perShare};
      splitType = updatedExpense.splitType;
      participantIds = ids;
    }

    FirestoreService.instance.updateExpense(groupId, updatedExpense.id, {
      'amount': updatedExpense.amount,
      'description': updatedExpense.description,
      'date': updatedExpense.date,
      'dateSortKey': _dateStringToSortKey(updatedExpense.date),
      'payerId': payerId,
      'splitType': splitType,
      'participantIds': participantIds,
      'splits': splits.map((k, v) => MapEntry(k, v)),
      if (updatedExpense.category.isNotEmpty) 'category': updatedExpense.category,
    });
  }

  void deleteExpense(String groupId, String expenseId) {
    FirestoreService.instance.deleteExpense(groupId, expenseId);
    if (_lastAddedGroupId == groupId && _lastAddedExpenseId == expenseId) _clearLastAdded();
  }

  /// Deletes the group from Firestore. Only the creator can delete.
  /// Cancels the group's expense subscription first so no pending writes can recreate an empty group doc after delete.
  /// Removes the group from local state after delete so the UI updates.
  Future<void> deleteGroup(String groupId) async {
    if (!canDeleteGroup(groupId, _currentUserId)) {
      throw StateError('Only the group creator can delete this group.');
    }
    _expenseSubs[groupId]?.cancel();
    _expenseSubs.remove(groupId);
    await FirestoreService.instance.deleteGroup(groupId);
    _removeGroupLocally(groupId);
  }

  /// Removes a group from in-memory state so the list updates immediately after delete.
  void _removeGroupLocally(String groupId) {
    final meta = _groupMeta[groupId];
    _groups.removeWhere((g) => g.id == groupId);
    _groupMeta.remove(groupId);
    _expenseSubs[groupId]?.cancel();
    _expenseSubs.remove(groupId);
    if (meta != null) {
      _expensesByCycleId.remove(meta.activeCycleId);
    }
    notifyListeners();
  }

  Map<String, double> calculateBalances(String groupId) {
    final cycle = getActiveCycle(groupId);
    final members = getMembersForGroup(groupId);
    final Map<String, double> net = {};
    for (final m in members) {
      if (!m.id.startsWith('p_')) net[m.id] = 0.0;
    }
    for (final expense in cycle.expenses) {
      final payerId = expense.paidById.isNotEmpty ? expense.paidById : _currentUserId;
      if (net.containsKey(payerId)) net[payerId] = (net[payerId] ?? 0) + expense.amount;
      final participantIds = expense.participantIds.isNotEmpty
          ? expense.participantIds
          : members.where((m) => !m.id.startsWith('p_')).map((m) => m.id).toList();
      if (expense.splitAmountsById != null && expense.splitAmountsById!.isNotEmpty) {
        for (final entry in expense.splitAmountsById!.entries) {
          if (entry.key.startsWith('p_')) continue;
          if (net.containsKey(entry.key)) net[entry.key] = (net[entry.key] ?? 0) - entry.value;
        }
      } else {
        if (participantIds.isEmpty) continue;
        final perShare = expense.amount / participantIds.length;
        for (final uid in participantIds) {
          if (uid.startsWith('p_')) continue;
          if (net.containsKey(uid)) net[uid] = (net[uid] ?? 0) - perShare;
        }
      }
    }
    return net;
  }

  List<String> getSettlementInstructions(String groupId) {
    final balances = calculateBalances(groupId);
    final debtors = balances.entries
        .where((e) => e.value < -0.01)
        .map((e) => _BalanceEntry(e.key, -e.value))
        .toList();
    final creditors = balances.entries
        .where((e) => e.value > 0.01)
        .map((e) => _BalanceEntry(e.key, e.value))
        .toList();
    debtors.sort((a, b) => b.amount.compareTo(a.amount));
    creditors.sort((a, b) => b.amount.compareTo(a.amount));
    final List<String> result = [];
    int d = 0, c = 0;
    while (d < debtors.length && c < creditors.length) {
      final debtor = debtors[d];
      final creditor = creditors[c];
      final amount = (debtor.amount < creditor.amount ? debtor.amount : creditor.amount);
      if (amount < 0.01) break;
      result.add(
        '${getMemberDisplayNameById(debtor.id)} owes ${getMemberDisplayNameById(creditor.id)} ₹${amount.round()}',
      );
      debtor.amount -= amount;
      creditor.amount -= amount;
      if (debtor.amount < 0.01) d++;
      if (creditor.amount < 0.01) c++;
    }
    return result;
  }

  /// Settlement transfers for the current user as debtor: (creditor, amount) pairs and total.
  /// Empty list and 0 if current user owes nothing.
  List<SettlementTransfer> getSettlementTransfersForCurrentUser(String groupId) {
    final balances = calculateBalances(groupId);
    final debtors = balances.entries
        .where((e) => e.value < -0.01)
        .map((e) => _BalanceEntry(e.key, -e.value))
        .toList();
    final creditors = balances.entries
        .where((e) => e.value > 0.01)
        .map((e) => _BalanceEntry(e.key, e.value))
        .toList();
    debtors.sort((a, b) => b.amount.compareTo(a.amount));
    creditors.sort((a, b) => b.amount.compareTo(a.amount));
    final List<SettlementTransfer> result = [];
    int d = 0, c = 0;
    while (d < debtors.length && c < creditors.length) {
      final debtor = debtors[d];
      final creditor = creditors[c];
      final amount = (debtor.amount < creditor.amount ? debtor.amount : creditor.amount);
      if (amount < 0.01) break;
      if (debtor.id == _currentUserId) {
        result.add(SettlementTransfer(
          creditorPhone: _phoneForUid(creditor.id),
          creditorDisplayName: getMemberDisplayNameById(creditor.id),
          amount: amount,
        ));
      }
      debtor.amount -= amount;
      creditor.amount -= amount;
      if (debtor.amount < 0.01) d++;
      if (creditor.amount < 0.01) c++;
    }
    return result;
  }

  /// Phase 1 (Freeze): Sets the current cycle's status to settling. Creator-only.
  /// Makes the group passive immediately (cycle settling) and writes to Firestore.
  void settleAndRestartCycle(String groupId) {
    if (!isCreator(groupId, _currentUserId)) return;
    final meta = _groupMeta[groupId];
    if (meta == null) return;
    FirestoreService.instance.updateGroup(groupId, {'cycleStatus': 'settling'});
    _groupMeta[groupId] = _GroupMeta(activeCycleId: meta.activeCycleId, cycleStatus: 'settling');
    _refreshGroupAmounts();
    notifyListeners();
  }

  /// Archive & Restart: Moves current cycle expenses to settled_cycles, then starts new cycle. Creator-only.
  /// Works whether cycle is 'active' (e.g. from Settle now dialog) or 'settling' (e.g. after Pay via UPI).
  /// Throws if not creator or group meta missing so the UI can show an error.
  Future<void> archiveAndRestart(String groupId) async {
    if (!isCreator(groupId, _currentUserId)) {
      throw StateError('Only the group creator can settle and start a new cycle.');
    }
    final meta = _groupMeta[groupId];
    if (meta == null) {
      throw StateError('Group data not loaded. Pull to refresh or try again.');
    }
    final now = DateTime.now();
    final endStr = _formatDate(now);
    final startStr = meta.activeCycleId.startsWith('c_')
        ? _formatDate(DateTime.fromMillisecondsSinceEpoch(int.tryParse(meta.activeCycleId.substring(2)) ?? 0))
        : endStr;
    await FirestoreService.instance.archiveCycleExpenses(
      groupId,
      meta.activeCycleId,
      startDate: startStr,
      endDate: endStr,
    );
    final newCycleId = _nextCycleId();
    await FirestoreService.instance.updateGroup(groupId, {
      'activeCycleId': newCycleId,
      'cycleStatus': 'active',
    });
    _groupMeta[groupId] = _GroupMeta(activeCycleId: newCycleId, cycleStatus: 'active');
    _expensesByCycleId.remove(meta.activeCycleId);
    _expensesByCycleId[newCycleId] = [];
    _refreshGroupAmounts();
    notifyListeners();
  }

  /// Returns all closed cycles for the group, newest first (from Firestore settled_cycles).
  Future<List<Cycle>> getHistory(String groupId) async {
    try {
      final settledDocs = await FirestoreService.instance.getSettledCycles(groupId);
      final List<Cycle> closed = [];
      for (final doc in settledDocs) {
        final data = doc.data() ?? {};
        final cycleId = doc.id;
        final startDate = data['startDate'] as String? ?? '';
        final endDate = data['endDate'] as String? ?? '';
        final expenseDocs = await FirestoreService.instance.getSettledCycleExpenses(groupId, cycleId);
        final expenses = expenseDocs.map((d) => _expenseFromFirestore(d.data(), d.id)).toList();
        closed.add(Cycle(
          id: cycleId,
          groupId: groupId,
          status: CycleStatus.closed,
          startDate: startDate,
          endDate: endDate,
          expenses: expenses,
        ));
      }
      return closed;
    } catch (e, st) {
      debugPrint('CycleRepository.getHistory failed for $groupId: $e');
      if (kDebugMode) debugPrint(st.toString());
      return [];
    }
  }
}

class _GroupMeta {
  final String activeCycleId;
  final String cycleStatus;
  _GroupMeta({required this.activeCycleId, required this.cycleStatus});
}

class _BalanceEntry {
  final String id;
  double amount;
  _BalanceEntry(this.id, this.amount);
}
