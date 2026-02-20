import '../models/models.dart';

/// A single debt: [fromId] owes [toId] [amount].
class Debt {
  final String fromId;
  final String toId;
  final double amount;

  const Debt({
    required this.fromId,
    required this.toId,
    required this.amount,
  });
}

/// Computes who owes whom from expenses and members.
/// Net balance = Total Paid - Total Owed per member (by id); then matches debtors to creditors.
class SettlementEngine {
  SettlementEngine._();

  static const double _tolerance = 0.01;

  /// Returns net balance per member id: positive = owed to them (credit), negative = they owe (debt).
  static Map<String, double> computeNetBalances(List<Expense> expenses, List<Member> members) {
    final net = _buildNetBalances(expenses, members);
    return Map.unmodifiable(Map.from(net));
  }

  static Map<String, double> _buildNetBalances(List<Expense> expenses, List<Member> members) {
    final ids = members.where((m) => !m.id.startsWith('p_')).map((m) => m.id).toSet();
    final Map<String, double> net = {};
    for (final id in ids) {
      net[id] = 0.0;
    }

    for (final expense in expenses) {
      final payerId = expense.paidById.isNotEmpty ? expense.paidById : '';
      if (payerId.isNotEmpty && ids.contains(payerId)) {
        net[payerId] = (net[payerId] ?? 0) + expense.amount;
      }
      final participantIds = expense.participantIds.isNotEmpty
          ? expense.participantIds
          : ids.toList();
      if (expense.splitAmountsById != null && expense.splitAmountsById!.isNotEmpty) {
        for (final entry in expense.splitAmountsById!.entries) {
          if (!entry.key.startsWith('p_') && ids.contains(entry.key)) {
            net[entry.key] = (net[entry.key] ?? 0) - entry.value;
          }
        }
      } else {
        if (participantIds.isEmpty) continue;
        final perShare = expense.amount / participantIds.length;
        for (final uid in participantIds) {
          if (!uid.startsWith('p_') && ids.contains(uid)) {
            net[uid] = (net[uid] ?? 0) - perShare;
          }
        }
      }
    }
    return net;
  }

  /// Returns a list of [Debt] (fromId, toId, amount).
  static List<Debt> computeDebts(List<Expense> expenses, List<Member> members) {
    final net = _buildNetBalances(expenses, members);

    final debtors = net.entries
        .where((e) => e.value < -_tolerance)
        .map((e) => _BalanceEntry(e.key, -e.value))
        .toList();
    final creditors = net.entries
        .where((e) => e.value > _tolerance)
        .map((e) => _BalanceEntry(e.key, e.value))
        .toList();
    debtors.sort((a, b) => b.amount.compareTo(a.amount));
    creditors.sort((a, b) => b.amount.compareTo(a.amount));

    final List<Debt> result = [];
    int d = 0, c = 0;
    while (d < debtors.length && c < creditors.length) {
      final debtor = debtors[d];
      final creditor = creditors[c];
      final amount = (debtor.amount < creditor.amount ? debtor.amount : creditor.amount);
      if (amount < _tolerance) break;
      result.add(Debt(fromId: debtor.id, toId: creditor.id, amount: amount));
      debtor.amount -= amount;
      creditor.amount -= amount;
      if (debtor.amount < _tolerance) d++;
      if (creditor.amount < _tolerance) c++;
    }
    return result;
  }
}

class _BalanceEntry {
  final String id;
  double amount;
  _BalanceEntry(this.id, this.amount);
}
