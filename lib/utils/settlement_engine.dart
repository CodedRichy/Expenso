import '../models/models.dart';
import '../models/money_minor.dart';
import 'package:flutter/foundation.dart';
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

  int get amountMinor => amount.amountMinor;

  String get currencyCode => amount.currencyCode;
}

/// A payment instruction: [fromMemberId] pays [toMemberId] [amount].
/// 
/// Used by [SettlementEngine.computePaymentRoutes] to output the minimal
/// set of payments needed to settle all balances.
class PaymentRoute {
  final String fromMemberId;
  final String toMemberId;
  final MoneyMinor amount;

  const PaymentRoute({
    required this.fromMemberId,
    required this.toMemberId,
    required this.amount,
  });

  int get amountMinor => amount.amountMinor;

  String get currencyCode => amount.currencyCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PaymentRoute &&
          fromMemberId == other.fromMemberId &&
          toMemberId == other.toMemberId &&
          amountMinor == other.amountMinor &&
          currencyCode == other.currencyCode;

  @override
  int get hashCode => Object.hash(fromMemberId, toMemberId, amountMinor, currencyCode);

  @override
  String toString() =>
      'PaymentRoute($fromMemberId -> $toMemberId: ${amount.amountMinor} ${amount.currencyCode})';
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
  /// When the expense has [amountMinor] and [splitAmountsByIdMinor] (from Firestore
  /// write-path bridge), uses the integer path. Otherwise uses the legacy double adapter.
  /// Skips the expense if splitAmountsById is missing/empty or sum does not match amount (within 0.01).
  static List<LedgerDelta> expenseToDeltas(Expense expense, {String currencyCode = 'INR'}) {
    if (expense.amount <= 0 || expense.amount.isNaN || expense.amount.isInfinite) {
      return [];
    }

    final payerId = expense.paidById;
    if (payerId.isEmpty || payerId.startsWith('p_')) {
      return [];
    }

    final splits = expense.splitAmountsById;
    if (splits == null || splits.isEmpty) {
      if (kDebugMode) debugPrint('SettlementEngine: expense ${expense.id} has no splitAmountsById, skipping');
      return [];
    }
    final sum = splits.values.fold<double>(0, (a, b) => a + b);
    if (sum.isNaN || sum.isInfinite) {
      if (kDebugMode) debugPrint('SettlementEngine: expense ${expense.id} has invalid split sum (NaN/Infinite), skipping');
      return [];
    }
    final diff = (sum - expense.amount).abs();
    if (diff > 0.01) {
      if (kDebugMode) debugPrint('SettlementEngine: expense ${expense.id} split sum $sum != amount ${expense.amount}, skipping');
      return [];
    }

    final timestamp = _timestampFromExpenseDate(expense.date);

    if (expense.amountMinor != null &&
        expense.splitAmountsByIdMinor != null &&
        expense.splitAmountsByIdMinor!.isNotEmpty) {
      return expenseToLedgerDeltas(
        expenseId: expense.id,
        amountMinor: expense.amountMinor!,
        payerId: payerId,
        splitAmountsByIdMinor: expense.splitAmountsByIdMinor!,
        currencyCode: currencyCode,
        timestamp: timestamp,
      );
    }

    return expenseToLedgerDeltasLegacy(
      expenseId: expense.id,
      amount: expense.amount,
      payerId: payerId,
      splitAmountsById: expense.splitAmountsById!,
      currencyCode: currencyCode,
      timestamp: timestamp,
    );
  }

  static DateTime _timestampFromExpenseDate(String date) {
    final ms = int.tryParse(date);
    if (ms != null) return DateTime.fromMillisecondsSinceEpoch(ms);
    return DateTime.now();
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

  /// Computes minimal payment routes from net balances using a greedy algorithm.
  /// 
  /// Takes a map of member IDs to net balances (positive = credit, negative = debt)
  /// and returns the minimal set of payment instructions to settle all balances.
  /// 
  /// The greedy algorithm sorts debtors and creditors by amount (descending),
  /// then repeatedly matches the largest debtor to the largest creditor.
  /// This produces at most n-1 transactions for n members with non-zero balances.
  /// 
  /// Example:
  /// ```dart
  /// final netBalances = {'alice': 10000, 'bob': -6000, 'carol': -4000}; // minor units
  /// final routes = SettlementEngine.computePaymentRoutes(netBalances, 'INR');
  /// // routes: [bob -> alice: 6000, carol -> alice: 4000]
  /// ```
  static List<PaymentRoute> computePaymentRoutes(
    Map<String, int> netBalances,
    String currencyCode,
  ) {
    final debtors = netBalances.entries
        .where((e) => e.value < 0)
        .map((e) => _BalanceEntry(e.key, -e.value))
        .toList();
    final creditors = netBalances.entries
        .where((e) => e.value > 0)
        .map((e) => _BalanceEntry(e.key, e.value))
        .toList();

    debtors.sort((a, b) => b.amount.compareTo(a.amount));
    creditors.sort((a, b) => b.amount.compareTo(a.amount));

    final List<PaymentRoute> routes = [];
    int d = 0, c = 0;

    while (d < debtors.length && c < creditors.length) {
      final debtor = debtors[d];
      final creditor = creditors[c];
      final transferAmount = debtor.amount < creditor.amount 
          ? debtor.amount 
          : creditor.amount;

      if (transferAmount <= 0) break;

      routes.add(PaymentRoute(
        fromMemberId: debtor.id,
        toMemberId: creditor.id,
        amount: MoneyMinor(transferAmount, currencyCode),
      ));

      debtor.amount -= transferAmount;
      creditor.amount -= transferAmount;

      if (debtor.amount <= 0) d++;
      if (creditor.amount <= 0) c++;
    }

    return routes;
  }

  /// Returns only the payments that a specific member needs to make.
  /// 
  /// Filters [routes] to include only those where [memberId] is the payer
  /// (fromMemberId). Use this to show each user only their outgoing payments.
  static List<PaymentRoute> getPaymentsForMember(
    String memberId,
    List<PaymentRoute> routes,
  ) {
    return routes.where((r) => r.fromMemberId == memberId).toList();
  }

  /// Returns payments that a specific member will receive.
  /// 
  /// Filters [routes] to include only those where [memberId] is the recipient
  /// (toMemberId). Use this to show incoming payments.
  static List<PaymentRoute> getPaymentsToMember(
    String memberId,
    List<PaymentRoute> routes,
  ) {
    return routes.where((r) => r.toMemberId == memberId).toList();
  }

  // ============================================================
  // LEGACY ADAPTERS (for backward compatibility during migration)
  // ============================================================

  /// Legacy: Returns net balances as doubles (for UI compatibility).
  /// Deferred migration to integer amounts: see docs/internal/V4_TESTING_ISSUES.md G4.
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
  /// Deferred migration to integer amounts: see docs/internal/V4_TESTING_ISSUES.md G4.
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

  // ============================================================
  // GOD MODE: Cross-Group Optimization
  // ============================================================

  /// Computes optimized payment routes from global net balances.
  /// 
  /// This is the "God Mode" feature: given net balances aggregated across
  /// all groups (keyed by phone number in E.164 format), computes the
  /// minimum number of transactions to settle all debts.
  /// 
  /// Example: If across all groups:
  /// - Alice is owed ₹500 by Bob
  /// - Bob is owed ₹500 by Carol
  /// Instead of 2 transactions, suggest: Carol pays Alice ₹500 directly.
  /// 
  /// Input: Map of phone (E.164) -> net balance in minor units
  /// (positive = owed to them, negative = they owe)
  /// 
  /// Output: List of optimized payment routes (fromPhone, toPhone, amount)
  static List<OptimizedRoute> computeOptimizedGlobalRoutes(
    Map<String, int> globalNetBalances,
    String currencyCode,
  ) {
    final debtors = globalNetBalances.entries
        .where((e) => e.value < 0)
        .map((e) => _BalanceEntry(e.key, -e.value))
        .toList();
    final creditors = globalNetBalances.entries
        .where((e) => e.value > 0)
        .map((e) => _BalanceEntry(e.key, e.value))
        .toList();

    debtors.sort((a, b) => b.amount.compareTo(a.amount));
    creditors.sort((a, b) => b.amount.compareTo(a.amount));

    final routes = <OptimizedRoute>[];
    int d = 0, c = 0;

    while (d < debtors.length && c < creditors.length) {
      final debtor = debtors[d];
      final creditor = creditors[c];
      final transferAmount = debtor.amount < creditor.amount
          ? debtor.amount
          : creditor.amount;

      if (transferAmount <= 0) break;

      routes.add(OptimizedRoute(
        fromPhone: debtor.id,
        toPhone: creditor.id,
        amountMinor: transferAmount,
        currencyCode: currencyCode,
      ));

      debtor.amount -= transferAmount;
      creditor.amount -= transferAmount;

      if (debtor.amount <= 0) d++;
      if (creditor.amount <= 0) c++;
    }

    return routes;
  }

  /// Compares original per-group routes vs optimized global routes.
  /// 
  /// Returns (originalCount, optimizedCount, savingsCount)
  static (int, int, int) compareOptimization(
    int originalRouteCount,
    List<OptimizedRoute> optimizedRoutes,
  ) {
    final optimizedCount = optimizedRoutes.length;
    final savings = originalRouteCount - optimizedCount;
    return (originalRouteCount, optimizedCount, savings > 0 ? savings : 0);
  }

}

/// An optimized payment route for cross-group settlement.
/// Uses phone numbers (E.164) as identifiers instead of member IDs.
class OptimizedRoute {
  final String fromPhone;
  final String toPhone;
  final int amountMinor;
  final String currencyCode;

  const OptimizedRoute({
    required this.fromPhone,
    required this.toPhone,
    required this.amountMinor,
    required this.currencyCode,
  });

  double get amountDisplay => amountMinor / 100;
}

class _BalanceEntry {
  final String id;
  int amount;
  _BalanceEntry(this.id, this.amount);
}
