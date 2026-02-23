import '../models/models.dart';
import '../models/money_minor.dart';
import 'ledger_delta.dart';

/// A single debt: [fromId] owes [toId] [amount] in minor units.
class Debt {
  final String fromId;
  final String toId;
  final MoneyMinor amount;

  const Debt({
    required this.fromId,
    required this.toId,
    required this.amount,
  });

  /// Convenience getter for amount in minor units.
  int get amountMinor => amount.amountMinor;

  /// Convenience getter for currency code.
  String get currencyCode => amount.currencyCode;
}

/// Computes who owes whom from expenses and members.
/// 
/// All accounting uses integer arithmetic only - no floating-point.
/// Net balance = Total Paid - Total Owed per member (by id); then matches debtors to creditors.
///
/// DEPLOYMENT GATE (MONEY_PHASE2):
/// Before deploying, Firestore must be verified to contain no expenses with
/// empty or invalid paidById. If such data exists, it must be backfilled or
/// quarantined. This is a deployment responsibility, not app logic.
/// 
/// Invariant I7: An expense with no valid payer produces no credit.
/// - Empty paidById: skipped entirely (no deltas)
/// - Pending member paidById (p_ prefix): skipped entirely
/// - Unknown paidById: credit lost (no fallback, no inference)
class SettlementEngine {
  SettlementEngine._();

  /// Computes net balances from a list of ledger deltas (integer-based).
  /// 
  /// This is the canonical, pure computation path.
  /// Positive = owed to member (credit), negative = member owes (debt).
  /// 
  /// Asserts that all deltas have the same currency.
  static Map<String, int> computeNetBalancesFromDeltas(
    List<LedgerDelta> deltas,
    String currencyCode,
  ) {
    final Map<String, int> net = {};
    
    for (final delta in deltas) {
      if (delta.memberId.isEmpty || delta.memberId.startsWith('p_')) continue;
      if (delta.currencyCode != currencyCode) {
        throw ArgumentError(
          'Currency mismatch: expected $currencyCode, got ${delta.currencyCode}',
        );
      }
      net[delta.memberId] = (net[delta.memberId] ?? 0) + delta.deltaMinor;
    }
    
    return Map.unmodifiable(net);
  }

  /// Computes debts from a list of ledger deltas (integer-based).
  /// 
  /// Uses the greedy algorithm to minimize number of transactions.
  /// No tolerance logic - exact integer arithmetic.
  static List<Debt> computeDebtsFromDeltas(
    List<LedgerDelta> deltas,
    String currencyCode,
  ) {
    final net = computeNetBalancesFromDeltas(deltas, currencyCode);
    return _computeDebtsFromNetBalances(net, currencyCode);
  }

  /// Converts an Expense to LedgerDeltas for the canonical computation path.
  /// 
  /// Uses the legacy adapter to handle double-based storage.
  /// Assumes INR currency if not specified.
  static List<LedgerDelta> expenseToDeltas(Expense expense, {String currencyCode = 'INR'}) {
    if (expense.amount <= 0 || expense.amount.isNaN || expense.amount.isInfinite) {
      return [];
    }

    final payerId = expense.paidById;
    if (payerId.isEmpty || payerId.startsWith('p_')) {
      return [];
    }

    return expenseToLedgerDeltasLegacy(
      expenseId: expense.id,
      amount: expense.amount,
      payerId: payerId,
      splitAmountsById: expense.splitAmountsById ?? {},
      currencyCode: currencyCode,
      timestamp: DateTime.now(),
    );
  }

  /// Converts a list of Expenses to LedgerDeltas.
  static List<LedgerDelta> expensesToDeltas(List<Expense> expenses, {String currencyCode = 'INR'}) {
    final deltas = <LedgerDelta>[];
    for (final expense in expenses) {
      deltas.addAll(expenseToDeltas(expense, currencyCode: currencyCode));
    }
    return deltas;
  }

  /// Returns net balance per member id in minor units.
  /// Positive = owed to them (credit), negative = they owe (debt).
  /// 
  /// This method converts from legacy double-based expenses to integer-based balances.
  static Map<String, int> computeNetBalances(
    List<Expense> expenses,
    List<Member> members,
    {String currencyCode = 'INR'}
  ) {
    final deltas = expensesToDeltas(expenses, currencyCode: currencyCode);
    
    final ids = members.where((m) => !m.id.startsWith('p_')).map((m) => m.id).toSet();
    final Map<String, int> net = {};
    for (final id in ids) {
      net[id] = 0;
    }
    
    for (final delta in deltas) {
      if (ids.contains(delta.memberId)) {
        net[delta.memberId] = (net[delta.memberId] ?? 0) + delta.deltaMinor;
      }
    }
    
    return Map.unmodifiable(net);
  }

  /// Returns a list of [Debt] (fromId, toId, amount in minor units).
  static List<Debt> computeDebts(
    List<Expense> expenses,
    List<Member> members,
    {String currencyCode = 'INR'}
  ) {
    final net = computeNetBalances(expenses, members, currencyCode: currencyCode);
    return _computeDebtsFromNetBalances(net, currencyCode);
  }

  static List<Debt> _computeDebtsFromNetBalances(Map<String, int> net, String currencyCode) {
    final debtors = net.entries
        .where((e) => e.value < 0)
        .map((e) => _BalanceEntry(e.key, -e.value))
        .toList();
    final creditors = net.entries
        .where((e) => e.value > 0)
        .map((e) => _BalanceEntry(e.key, e.value))
        .toList();
    debtors.sort((a, b) => b.amount.compareTo(a.amount));
    creditors.sort((a, b) => b.amount.compareTo(a.amount));

    final List<Debt> result = [];
    int d = 0, c = 0;
    while (d < debtors.length && c < creditors.length) {
      final debtor = debtors[d];
      final creditor = creditors[c];
      final amount = debtor.amount < creditor.amount ? debtor.amount : creditor.amount;
      if (amount <= 0) break;
      result.add(Debt(
        fromId: debtor.id,
        toId: creditor.id,
        amount: MoneyMinor(amount, currencyCode),
      ));
      debtor.amount -= amount;
      creditor.amount -= amount;
      if (debtor.amount <= 0) d++;
      if (creditor.amount <= 0) c++;
    }
    return result;
  }

  // ============================================================
  // LEGACY ADAPTERS (for backward compatibility during migration)
  // ============================================================

  /// Legacy: Returns net balances as doubles (for UI compatibility).
  /// 
  /// Converts integer balances to display amounts.
  /// TODO: Remove once UI is updated to use integer amounts.
  static Map<String, double> computeNetBalancesAsDouble(
    List<Expense> expenses,
    List<Member> members,
    {String currencyCode = 'INR'}
  ) {
    final netMinor = computeNetBalances(expenses, members, currencyCode: currencyCode);
    return Map.fromEntries(
      netMinor.entries.map((e) => MapEntry(
        e.key,
        MoneyConversion.minorToDisplay(e.value, currencyCode),
      )),
    );
  }

  /// Legacy: Returns debts with double amounts (for UI compatibility).
  /// 
  /// TODO: Remove once UI is updated to use integer amounts.
  static List<({String fromId, String toId, double amount})> computeDebtsAsDouble(
    List<Expense> expenses,
    List<Member> members,
    {String currencyCode = 'INR'}
  ) {
    final debts = computeDebts(expenses, members, currencyCode: currencyCode);
    return debts.map((d) => (
      fromId: d.fromId,
      toId: d.toId,
      amount: MoneyConversion.minorToDisplay(d.amountMinor, currencyCode),
    )).toList();
  }

}

class _BalanceEntry {
  final String id;
  int amount;
  _BalanceEntry(this.id, this.amount);
}
