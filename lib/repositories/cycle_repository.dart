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

  final List<Group> _groups = [
    Group(
      id: '1',
      name: 'Weekend Trip',
      status: 'closing',
      amount: 3240,
      statusLine: 'Cycle closes Sunday',
    ),
    Group(
      id: '2',
      name: 'Movie Night',
      status: 'open',
      amount: 1850,
      statusLine: 'Cycle open until Sunday',
    ),
    Group(
      id: '3',
      name: 'Office Lunch',
      status: 'settled',
      amount: 0,
      statusLine: 'All balances cleared',
    ),
  ];

  final List<Cycle> _cycles = [
    Cycle(
      id: 'c1',
      groupId: '1',
      status: CycleStatus.settling,
      startDate: 'Dec 1',
      expenses: [
        Expense(id: '1', description: 'Dinner at Bistro 42', amount: 1200, date: 'Today'),
        Expense(id: '2', description: 'Taxi ride', amount: 850, date: 'Today'),
        Expense(id: '3', description: 'Groceries', amount: 700, date: 'Yesterday'),
        Expense(id: '4', description: 'Fuel', amount: 490, date: 'Yesterday'),
      ],
    ),
    Cycle(
      id: 'c2',
      groupId: '2',
      status: CycleStatus.active,
      startDate: 'Dec 8',
      expenses: [],
    ),
    Cycle(
      id: 'c3',
      groupId: '3',
      status: CycleStatus.closed,
      startDate: 'Nov 17',
      endDate: 'Nov 23',
      expenses: [],
    ),
  ];

  List<Group> get groups => List.unmodifiable(_groups);

  Group? getGroup(String id) {
    try {
      return _groups.firstWhere((g) => g.id == id);
    } catch (_) {
      return null;
    }
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
      notifyListeners();
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

  /// Closes the current (active or settling) cycle and starts a new active cycle for the group.
  void settleAndRestartCycle(String groupId) {
    final idx = _cycles.indexWhere(
      (c) => c.groupId == groupId && c.status != CycleStatus.closed,
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
