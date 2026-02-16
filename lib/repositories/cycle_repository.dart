import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import '../models/cycle.dart';
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

  /// Updates the global profile (phone, name, and optionally auth user id). Notifies listeners.
  void setGlobalProfile(String phone, String name, {String? authUserId}) {
    _currentUserPhone = phone;
    _currentUserName = name.trim();
    if (authUserId != null && authUserId.isNotEmpty) _currentUserId = authUserId;
    notifyListeners();
  }

  /// Syncs identity from Firebase user (uid, phone, displayName). Call when auth state becomes non-null.
  /// Writes user profile to Firestore (users/{uid}) and starts listening to groups + expenses.
  void setAuthFromFirebaseUser(String uid, String? phone, String? displayName) {
    if (uid.isNotEmpty) _currentUserId = uid;
    if (phone != null && phone.isNotEmpty) _currentUserPhone = phone;
    if (displayName != null && displayName.isNotEmpty) _currentUserName = displayName.trim();
    _userCache[uid] = {
      'displayName': _currentUserName,
      'phoneNumber': _currentUserPhone,
    };
    notifyListeners();
    if (_currentUserId.isNotEmpty) {
      _writeCurrentUserProfile();
      _startListening();
    }
  }

  Future<void> _writeCurrentUserProfile() async {
    try {
      await FirestoreService.instance.setUser(
        _currentUserId,
        displayName: _currentUserName,
        phoneNumber: _currentUserPhone,
      );
    } catch (e, st) {
      debugPrint('CycleRepository._writeCurrentUserProfile failed: $e');
      if (kDebugMode) debugPrint(st.toString());
    }
  }

  /// Clears auth-derived identity (e.g. on sign-out). Stops Firestore listeners.
  void clearAuth() {
    _stopListening();
    _groupsLoading = false;
    _currentUserId = '';
    _currentUserPhone = '';
    _currentUserName = '';
    _groups.clear();
    _membersById.clear();
    _expensesByCycleId.clear();
    _groupMeta.clear();
    _userCache.clear();
    notifyListeners();
  }

  final List<Group> _groups = [];
  final Map<String, Member> _membersById = {};
  /// cycleId -> list of expenses for that cycle (current cycle per group).
  final Map<String, List<Expense>> _expensesByCycleId = {};
  /// groupId -> { activeCycleId, cycleStatus } from Firestore.
  final Map<String, _GroupMeta> _groupMeta = {};
  final Map<String, Map<String, dynamic>> _userCache = {};

  StreamSubscription<List<QueryDocumentSnapshot<Map<String, dynamic>>>>? _groupsSub;
  final Map<String, StreamSubscription<List<QueryDocumentSnapshot<Map<String, dynamic>>>>> _expenseSubs = {};

  /// True while waiting for the first Firestore groups snapshot (for skeleton UX).
  bool get groupsLoading => _groupsLoading;
  bool _groupsLoading = false;

  void _startListening() {
    if (_currentUserId.isEmpty) return;
    _groupsSub?.cancel();
    _groupsLoading = true;
    notifyListeners();
    _groupsSub = FirestoreService.instance.groupsStream(_currentUserId).listen(_onGroupsSnapshot);
  }

  void _stopListening() {
    _groupsSub?.cancel();
    _groupsSub = null;
    _groupsLoading = false;
    for (final sub in _expenseSubs.values) {
      sub.cancel();
    }
    _expenseSubs.clear();
  }

  void _onGroupsSnapshot(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    _groupsLoading = false;
    final newIds = docs.map((d) => d.id).toSet();
    for (final id in _expenseSubs.keys.toList()) {
      if (!newIds.contains(id)) {
        _expenseSubs[id]?.cancel();
        _expenseSubs.remove(id);
      }
    }

    _groups.clear();
    _groupMeta.clear();
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

      _membersById.clear();
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
            );
          }
        }
        final groupData = docs.cast<QueryDocumentSnapshot<Map<String, dynamic>>>().where((d) => d.id == g.id);
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
        _expenseSubs[groupId] = FirestoreService.instance.expensesStream(groupId).listen((expDocs) {
          _onExpensesSnapshot(groupId, expDocs);
        });
      }
    }

    _loadUsersForMembers(docs);
    notifyListeners();
  }

  Future<void> _loadUsersForMembers(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
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

  void _onExpensesSnapshot(String groupId, List<QueryDocumentSnapshot<Map<String, dynamic>>> expDocs) {
    final meta = _groupMeta[groupId];
    if (meta == null) return;
    final cycleId = meta.activeCycleId;
    final list = expDocs.map((d) => _expenseFromFirestore(d.data(), d.id)).toList();
    _expensesByCycleId[cycleId] = list;
    _refreshGroupAmounts();
    notifyListeners();
  }

  Expense _expenseFromFirestore(Map<String, dynamic> data, String id) {
    final amount = (data['amount'] is num) ? (data['amount'] as num).toDouble() : 0.0;
    final payerId = data['payerId'] as String? ?? '';
    final splits = data['splits'] as Map<String, dynamic>?;
    String paidByPhone = _currentUserPhone;
    if (payerId == _currentUserId) {
      paidByPhone = _currentUserPhone;
    } else if (_userCache.containsKey(payerId)) {
      paidByPhone = _userCache[payerId]!['phoneNumber'] as String? ?? '';
    }
    final participantPhones = <String>[];
    final splitAmountsByPhone = <String, double>{};
    if (splits != null) {
      for (final entry in splits.entries) {
        final uid = entry.key;
        final amt = entry.value is num ? (entry.value as num).toDouble() : double.tryParse(entry.value?.toString() ?? '') ?? 0.0;
        final phone = uid == _currentUserId ? _currentUserPhone : (_userCache[uid]?['phoneNumber'] as String? ?? '');
        if (phone.isNotEmpty) {
          participantPhones.add(phone);
          splitAmountsByPhone[phone] = amt;
        }
      }
    }
    return Expense(
      id: id,
      description: data['description'] as String? ?? '',
      amount: amount,
      date: data['date'] as String? ?? 'Today',
      participantPhones: participantPhones,
      paidByPhone: paidByPhone,
      splitAmountsByPhone: splitAmountsByPhone.isEmpty ? null : splitAmountsByPhone,
      category: data['category'] as String? ?? '',
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

  void addGroup(Group group) {
    if (_currentUserId.isEmpty) return;
    final groupId = group.id;
    FirestoreService.instance.createGroup(groupId, groupName: group.name, creatorId: _currentUserId);
    _writeCurrentUserProfile();
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

  String getMemberDisplayName(String phone) {
    if (phone == currentUserPhone) {
      return _currentUserName.isNotEmpty ? _currentUserName : 'You';
    }
    for (final m in _membersById.values) {
      if (m.phone == phone) return m.name.isNotEmpty ? m.name : _formatPhone(phone);
    }
    return _formatPhone(phone);
  }

  static String _formatPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 11 && digits.startsWith('91')) return '+91 ${digits.substring(2, 7)} ${digits.substring(7)}';
    if (digits.length == 10) return '+91 ${digits.substring(0, 5)} ${digits.substring(5)}';
    return phone;
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

  /// Resolve phone to UID (current user or from cache).
  String? _uidForPhone(String phone) {
    if (phone == _currentUserPhone) return _currentUserId;
    for (final e in _userCache.entries) {
      if (e.value['phoneNumber'] == phone) return e.key;
    }
    return null;
  }

  void addExpense(String groupId, Expense expense) {
    final amountError = validateExpenseAmount(expense.amount);
    if (amountError != null) throw ArgumentError(amountError);
    final descError = validateExpenseDescription(expense.description);
    if (descError != null) throw ArgumentError(descError);

    final meta = _groupMeta[groupId];
    final cycleId = meta?.activeCycleId;
    if (cycleId == null) return;
    final payerId = _uidForPhone(expense.paidByPhone.isEmpty ? _currentUserPhone : expense.paidByPhone) ?? _currentUserId;
    final participants = expense.participantPhones.isNotEmpty
        ? expense.participantPhones
        : [expense.paidByPhone.isNotEmpty ? expense.paidByPhone : _currentUserPhone];
    final uids = <String>[];
    for (final p in participants) {
      final uid = _uidForPhone(p);
      if (uid != null) uids.add(uid);
    }
    if (uids.isEmpty) uids.add(_currentUserId);
    final perShare = expense.amount / uids.length;
    final splits = <String, double>{};
    for (final uid in uids) {
      splits[uid] = perShare;
    }
    final data = {
      'id': expense.id,
      'groupId': groupId,
      'amount': expense.amount,
      'payerId': payerId,
      'splitType': 'Even',
      'splits': splits.map((k, v) => MapEntry(k, v)),
      'description': expense.description,
      'date': expense.date,
      if (expense.category.isNotEmpty) 'category': expense.category,
    };
    FirestoreService.instance.addExpense(groupId, data);
  }

  /// Adds an expense from the Magic Bar confirmation flow. Ensures splits map contains
  /// every member of the split. splitType: Even | Exact | Exclude.
  void addExpenseFromMagicBar(
    String groupId, {
    required String id,
    required String description,
    required double amount,
    required String date,
    required String payerPhone,
    required String splitType,
    required List<String> participantPhones,
    List<String>? excludedPhones,
    Map<String, double>? exactAmountsByPhone,
    String category = '',
  }) {
    final amountError = validateExpenseAmount(amount);
    if (amountError != null) throw ArgumentError(amountError);
    final descError = validateExpenseDescription(description);
    if (descError != null) throw ArgumentError(descError);

    final meta = _groupMeta[groupId];
    final cycleId = meta?.activeCycleId;
    if (cycleId == null) return;
    final payerId = _uidForPhone(payerPhone.isEmpty ? _currentUserPhone : payerPhone) ?? _currentUserId;
    final members = getMembersForGroup(groupId);
    final allPhones = members.map((m) => m.phone).toList();

    List<String> phonesInSplit = [];
    Map<String, double> splitsByPhone = {};

    if (splitType == 'Exact' && exactAmountsByPhone != null && exactAmountsByPhone.isNotEmpty) {
      phonesInSplit = exactAmountsByPhone.keys.toList();
      for (final e in exactAmountsByPhone.entries) {
        splitsByPhone[e.key] = e.value;
      }
    } else if (splitType == 'Exclude' && excludedPhones != null && excludedPhones.isNotEmpty) {
      final excludedSet = excludedPhones.toSet();
      phonesInSplit = allPhones.where((p) => !excludedSet.contains(p)).toList();
      if (phonesInSplit.isEmpty) phonesInSplit = [payerPhone.isNotEmpty ? payerPhone : _currentUserPhone];
      final perShare = amount / phonesInSplit.length;
      for (final p in phonesInSplit) {
        splitsByPhone[p] = perShare;
      }
    } else {
      // Even (or fallback): split among participantPhones; if empty, payer only
      phonesInSplit = participantPhones.isNotEmpty
          ? participantPhones
          : [payerPhone.isNotEmpty ? payerPhone : _currentUserPhone];
      final perShare = amount / phonesInSplit.length;
      for (final p in phonesInSplit) {
        splitsByPhone[p] = perShare;
      }
    }

    final splits = <String, double>{};
    for (final phone in phonesInSplit) {
      final uid = _uidForPhone(phone);
      final share = splitsByPhone[phone] ?? 0.0;
      if (uid != null) splits[uid] = share;
    }
    if (splits.isEmpty) splits[payerId] = amount;

    final data = {
      'id': id,
      'groupId': groupId,
      'amount': amount,
      'payerId': payerId,
      'splitType': splitType,
      'splits': splits.map((k, v) => MapEntry(k, v)),
      'description': description,
      'date': date,
      if (category.isNotEmpty) 'category': category,
    };
    FirestoreService.instance.addExpense(groupId, data);
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
    final payerId = _uidForPhone(updatedExpense.paidByPhone.isEmpty ? _currentUserPhone : updatedExpense.paidByPhone) ?? _currentUserId;

    final Map<String, double> splits;
    final String splitType;
    if (updatedExpense.splitAmountsByPhone != null && updatedExpense.splitAmountsByPhone!.isNotEmpty) {
      splits = <String, double>{};
      for (final entry in updatedExpense.splitAmountsByPhone!.entries) {
        final uid = _uidForPhone(entry.key);
        if (uid != null) splits[uid] = entry.value;
      }
      if (splits.isEmpty) {
        splits[payerId] = updatedExpense.amount;
      }
      splitType = 'Exact';
    } else {
      final participants = updatedExpense.participantPhones.isNotEmpty
          ? updatedExpense.participantPhones
          : [updatedExpense.paidByPhone.isNotEmpty ? updatedExpense.paidByPhone : _currentUserPhone];
      final uids = <String>[];
      for (final p in participants) {
        final uid = _uidForPhone(p);
        if (uid != null) uids.add(uid);
      }
      if (uids.isEmpty) uids.add(_currentUserId);
      final perShare = updatedExpense.amount / uids.length;
      splits = {for (final uid in uids) uid: perShare};
      splitType = 'Even';
    }

    FirestoreService.instance.updateExpense(groupId, updatedExpense.id, {
      'amount': updatedExpense.amount,
      'description': updatedExpense.description,
      'date': updatedExpense.date,
      'payerId': payerId,
      'splitType': splitType,
      'splits': splits.map((k, v) => MapEntry(k, v)),
      if (updatedExpense.category.isNotEmpty) 'category': updatedExpense.category,
    });
  }

  void deleteExpense(String groupId, String expenseId) {
    FirestoreService.instance.deleteExpense(groupId, expenseId);
  }

  /// Deletes the group from Firestore. Only the creator can delete. Listeners will update when the groups stream emits.
  Future<void> deleteGroup(String groupId) async {
    if (!canDeleteGroup(groupId, _currentUserId)) return;
    await FirestoreService.instance.deleteGroup(groupId);
  }

  Map<String, double> calculateBalances(String groupId) {
    final cycle = getActiveCycle(groupId);
    final members = getMembersForGroup(groupId);
    final phones = members.map((m) => m.phone).toSet();
    final Map<String, double> net = {};
    for (final phone in phones) {
      net[phone] = 0.0;
    }
    for (final expense in cycle.expenses) {
      final payer = expense.paidByPhone.isNotEmpty ? expense.paidByPhone : currentUserPhone;
      net[payer] = (net[payer] ?? 0) + expense.amount;
      final participants = expense.participantPhones.isNotEmpty
          ? expense.participantPhones
          : [payer];
      if (expense.splitAmountsByPhone != null && expense.splitAmountsByPhone!.isNotEmpty) {
        for (final entry in expense.splitAmountsByPhone!.entries) {
          net[entry.key] = (net[entry.key] ?? 0) - entry.value;
        }
      } else {
        final perShare = expense.amount / participants.length;
        for (final phone in participants) {
          net[phone] = (net[phone] ?? 0) - perShare;
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
        '${getMemberDisplayName(debtor.phone)} owes ${getMemberDisplayName(creditor.phone)} ₹${amount.round()}',
      );
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
  Future<void> archiveAndRestart(String groupId) async {
    if (!isCreator(groupId, _currentUserId)) return;
    final meta = _groupMeta[groupId];
    if (meta == null) return;
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
  final String phone;
  double amount;
  _BalanceEntry(this.phone, this.amount);
}
