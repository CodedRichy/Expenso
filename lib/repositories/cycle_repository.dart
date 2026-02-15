import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../models/cycle.dart';

class CycleRepository extends ChangeNotifier {
  CycleRepository._();

  static final CycleRepository _instance = CycleRepository._();

  static CycleRepository get instance => _instance;

  static String _formatDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}';
  }

  static String _nextCycleId() => 'c_${DateTime.now().millisecondsSinceEpoch}';

  /// Current user id; used as creator id when creating a group. Set from Firebase Auth UID when available.
  String get currentUserId => _currentUserId;
  String _currentUserId = 'dev_user_01';

  /// Current user phone; set after phone auth, used for auto-join as creator when creating a group.
  String get currentUserPhone => _currentUserPhone;
  String _currentUserPhone = '';

  /// Global display name for the current user; set in onboarding or via setGlobalProfile.
  String get currentUserName => _currentUserName;
  String _currentUserName = '';

  /// Updates the global profile (phone, name, and optionally auth user id). Notifies listeners.
  void setGlobalProfile(String phone, String name, {String? authUserId}) {
    _currentUserPhone = phone;
    _currentUserName = name.trim();
    if (authUserId != null && authUserId.isNotEmpty) _currentUserId = authUserId;
    notifyListeners();
  }

  final List<Group> _groups = [];
  final Map<String, Member> _membersById = {};
  final List<Cycle> _cycles = [];

  List<Group> get groups => List.unmodifiable(_groups);

  void addGroup(Group group) {
    final creatorMemberId = 'm_${group.id}_creator';
    final creatorMember = Member(
      id: creatorMemberId,
      phone: currentUserPhone,
      name: currentUserName,
    );
    _membersById[creatorMemberId] = creatorMember;
    final groupWithCreator = Group(
      id: group.id,
      name: group.name,
      status: group.status,
      amount: group.amount,
      statusLine: group.statusLine,
      creatorId: group.creatorId,
      memberIds: [creatorMemberId, ...group.memberIds],
    );
    _groups.add(groupWithCreator);
    notifyListeners();
  }

  Group? getGroup(String id) {
    try {
      return _groups.firstWhere((g) => g.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Sum of all expense amounts in the group's active cycle (pending amount).
  double getGroupPendingAmount(String groupId) {
    final cycle = getActiveCycle(groupId);
    final expenses = getExpenses(cycle.id);
    return expenses.fold<double>(0.0, (sum, e) => sum + e.amount);
  }

  List<Member> getMembersForGroup(String groupId) {
    final group = getGroup(groupId);
    if (group == null) return [];
    return group.memberIds
        .map((id) => _membersById[id])
        .whereType<Member>()
        .toList();
  }

  /// Returns display name for a member by phone. Priority: (1) current user → currentUserName or 'You';
  /// (2) any Member (across groups) with this phone → that member's name; (3) formatted phone.
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
    if (digits.length == 10) return '+91 ${digits.substring(0, 5)} ${digits.substring(5)}';
    return phone;
  }

  void addMemberToGroup(String groupId, Member member) {
    final group = getGroup(groupId);
    if (group == null) return;
    _membersById[member.id] = member;
    final idx = _groups.indexWhere((g) => g.id == groupId);
    if (idx < 0) return;
    _groups[idx] = Group(
      id: group.id,
      name: group.name,
      status: group.status,
      amount: group.amount,
      statusLine: group.statusLine,
      creatorId: group.creatorId,
      memberIds: [...group.memberIds, member.id],
    );
    notifyListeners();
  }

  void removeMemberFromGroup(String groupId, String memberId) {
    final group = getGroup(groupId);
    if (group == null) return;
    final idx = _groups.indexWhere((g) => g.id == groupId);
    if (idx < 0) return;
    _groups[idx] = Group(
      id: group.id,
      name: group.name,
      status: group.status,
      amount: group.amount,
      statusLine: group.statusLine,
      creatorId: group.creatorId,
      memberIds: group.memberIds.where((id) => id != memberId).toList(),
    );
    _membersById.remove(memberId);
    notifyListeners();
  }

  /// True if [userId] is the creator of the group.
  bool isCreator(String groupId, String userId) {
    final group = getGroup(groupId);
    return group != null && group.creatorId == userId;
  }

  /// True if [userId] can edit expenses in the group's current cycle.
  /// When cycle is settling, no one (including leader) can edit. Otherwise creator can always edit; non-creators only when active.
  bool canEditCycle(String groupId, String userId) {
    final cycle = getActiveCycle(groupId);
    if (cycle.status == CycleStatus.settling) return false;
    if (isCreator(groupId, userId)) return true;
    return cycle.status == CycleStatus.active;
  }

  /// True if [userId] can delete the group (creator only).
  bool canDeleteGroup(String groupId, String userId) {
    return isCreator(groupId, userId);
  }

  /// Returns the one non-closed cycle for the group; creates one if none exists.
  Cycle getActiveCycle(String groupId) {
    try {
      return _cycles.firstWhere(
        (c) => c.groupId == groupId && c.status != CycleStatus.closed,
      );
    } catch (_) {
      final now = DateTime.now();
      final newCycle = Cycle(
        id: _nextCycleId(),
        groupId: groupId,
        status: CycleStatus.active,
        startDate: _formatDate(now),
        expenses: [],
      );
      _cycles.add(newCycle);
      return newCycle;
    }
  }

  List<Expense> getExpenses(String cycleId) {
    for (final cycle in _cycles) {
      if (cycle.id == cycleId) return List.unmodifiable(cycle.expenses);
    }
    return [];
  }

  void addExpense(String groupId, Expense expense) {
    final cycle = getActiveCycle(groupId);
    cycle.expenses.add(expense);
    notifyListeners();
  }

  /// Returns the expense in the group's current (active or settling) cycle, or null.
  Expense? getExpense(String groupId, String expenseId) {
    final cycle = getActiveCycle(groupId);
    try {
      return cycle.expenses.firstWhere((e) => e.id == expenseId);
    } catch (_) {
      return null;
    }
  }

  /// Replaces the expense with the same id in the active cycle and notifies listeners.
  void updateExpense(String groupId, Expense updatedExpense) {
    final cycle = getActiveCycle(groupId);
    final index = cycle.expenses.indexWhere((e) => e.id == updatedExpense.id);
    if (index < 0) return;
    cycle.expenses[index] = updatedExpense;
    notifyListeners();
  }

  /// Removes the expense from the active cycle and notifies listeners.
  void deleteExpense(String groupId, String expenseId) {
    final cycle = getActiveCycle(groupId);
    cycle.expenses.removeWhere((e) => e.id == expenseId);
    notifyListeners();
  }

  /// Net balance per phone: positive = owed money, negative = owes money.
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
      final perShare = expense.amount / participants.length;

      for (final phone in participants) {
        net[phone] = (net[phone] ?? 0) - perShare;
      }
    }

    return net;
  }

  /// Who owes whom: list of strings like 'Rishi owes Prasi ₹500'.
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

  /// Phase 1 (Freeze): Sets the current cycle's status to settling. No new cycle created; expenses are read-only.
  void settleAndRestartCycle(String groupId) {
    final idx = _cycles.indexWhere(
      (c) => c.groupId == groupId && c.status != CycleStatus.closed,
    );
    if (idx < 0) return;
    final old = _cycles[idx];
    _cycles[idx] = Cycle(
      id: old.id,
      groupId: old.groupId,
      status: CycleStatus.settling,
      expenses: List.from(old.expenses),
      startDate: old.startDate,
      endDate: old.endDate,
    );
    notifyListeners();
  }

  /// Phase 2 (Archive & Restart): Closes the settling cycle and starts a new active cycle at ₹0.
  void archiveAndRestart(String groupId) {
    final idx = _cycles.indexWhere(
      (c) => c.groupId == groupId && c.status == CycleStatus.settling,
    );
    if (idx < 0) return;

    final now = DateTime.now();
    final endStr = _formatDate(now);
    final old = _cycles[idx];
    final closedCycle = Cycle(
      id: old.id,
      groupId: old.groupId,
      status: CycleStatus.closed,
      expenses: List.from(old.expenses),
      startDate: old.startDate,
      endDate: endStr,
    );
    _cycles[idx] = closedCycle;

    final newCycle = Cycle(
      id: _nextCycleId(),
      groupId: groupId,
      status: CycleStatus.active,
      startDate: endStr,
      expenses: [],
    );
    _cycles.add(newCycle);
    notifyListeners();
  }

  /// Returns all closed cycles for the group, newest first (by endDate).
  List<Cycle> getHistory(String groupId) {
    final closed = _cycles
        .where((c) => c.groupId == groupId && c.status == CycleStatus.closed)
        .toList();
    closed.sort((a, b) {
      final aEnd = a.endDate ?? '';
      final bEnd = b.endDate ?? '';
      return bEnd.compareTo(aEnd);
    });
    return closed;
  }
}

class _BalanceEntry {
  final String phone;
  double amount;
  _BalanceEntry(this.phone, this.amount);
}
