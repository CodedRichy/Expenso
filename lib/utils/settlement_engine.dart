import '../models/models.dart';

/// A single debt: [fromPhone] owes [toPhone] [amount].
class Debt {
  final String fromPhone;
  final String toPhone;
  final double amount;

  const Debt({
    required this.fromPhone,
    required this.toPhone,
    required this.amount,
  });
}

/// Computes who owes whom from expenses and members.
/// Net balance = Total Paid - Total Owed per member; then matches debtors to creditors.
class SettlementEngine {
  SettlementEngine._();

  static const double _tolerance = 0.01;

  /// Returns net balance per phone: positive = owed to them (credit), negative = they owe (debt).
  /// Only includes members that appear in [members] (by phone).
  static Map<String, double> computeNetBalances(List<Expense> expenses, List<Member> members) {
    final net = _buildNetBalances(expenses, members);
    return Map.unmodifiable(Map.from(net));
  }

  static Map<String, double> _buildNetBalances(List<Expense> expenses, List<Member> members) {
    final phones = members.map((m) => m.phone).toSet();
    final Map<String, double> net = {};
    for (final phone in phones) {
      net[phone] = 0.0;
    }

    for (final expense in expenses) {
      final payer = expense.paidByPhone.isNotEmpty ? expense.paidByPhone : '';
      if (payer.isNotEmpty && phones.contains(payer)) {
        net[payer] = (net[payer] ?? 0) + expense.amount;
      }
      final participants = expense.participantPhones.isNotEmpty
          ? expense.participantPhones
          : (payer.isNotEmpty ? [payer] : <String>[]);
      if (expense.splitAmountsByPhone != null && expense.splitAmountsByPhone!.isNotEmpty) {
        for (final entry in expense.splitAmountsByPhone!.entries) {
          if (phones.contains(entry.key)) {
            net[entry.key] = (net[entry.key] ?? 0) - entry.value;
          }
        }
      } else {
        if (participants.isEmpty) continue;
        final perShare = expense.amount / participants.length;
        for (final phone in participants) {
          if (phones.contains(phone)) {
            net[phone] = (net[phone] ?? 0) - perShare;
          }
        }
      }
    }
    return net;
  }

  /// Given [expenses] and [members], returns a list of [Debt] (fromPhone, toPhone, amount).
  /// Only includes members that appear in [members] (by phone).
  static List<Debt> computeDebts(List<Expense> expenses, List<Member> members) {
    final net = _buildNetBalances(expenses, members);
    final phones = members.map((m) => m.phone).toSet();

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
      result.add(Debt(fromPhone: debtor.phone, toPhone: creditor.phone, amount: amount));
      debtor.amount -= amount;
      creditor.amount -= amount;
      if (debtor.amount < _tolerance) d++;
      if (creditor.amount < _tolerance) c++;
    }
    return result;
  }
}

class _BalanceEntry {
  final String phone;
  double amount;
  _BalanceEntry(this.phone, this.amount);
}
