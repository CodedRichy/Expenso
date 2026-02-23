import 'money_minor.dart';

class NormalizedExpenseError extends Error {
  final String message;
  NormalizedExpenseError(this.message);
  @override
  String toString() => 'NormalizedExpenseError: $message';
}

/// Immutable, ID-only expense representation for accounting.
/// 
/// This model represents a fully-resolved accounting event.
/// It must be safe to replay at any time in the future.
/// 
/// ## Design Principles
/// - **UI-agnostic:** No UI concepts (slots, selections, confirmation state)
/// - **Timeless:** Can be reconstructed from storage without current group state
/// - **Replay-safe:** Produces identical LedgerDeltas regardless of when computed
/// - **Integer-only:** All money values use [MoneyMinor] (no floating-point)
/// - **Single-currency:** All amounts use the same currency
/// 
/// ## Money Invariants (enforced at construction)
/// - `sum(payerContributions.amountMinor) == total.amountMinor` (exact)
/// - `sum(participantShares.amountMinor) == total.amountMinor` (exact)
/// - All MoneyMinor instances share the same `currencyCode`
/// - All map keys are valid member IDs (no `p_` prefixes, non-empty)
/// - All amounts are non-negative
/// 
/// ## Non-Invariants (NOT validated here)
/// - Description content (validated at UI/parsing layer)
/// - Category validity
/// - Date format
/// 
/// All person references are member IDs (UUIDs), never names.
/// "Everyone" semantics must be expanded to concrete IDs before construction.
class NormalizedExpense {
  /// Total expense amount in minor units.
  final MoneyMinor total;
  
  final String description;
  final String category;
  final String date;
  
  /// Who paid and how much. Supports multiple payers (future-proof).
  /// Keys are member IDs, values are positive contribution amounts in minor units.
  /// Sum must equal [total].
  final Map<String, MoneyMinor> payerContributionsByMemberId;
  
  /// Who owes what share. Keys are member IDs, values are positive amounts owed in minor units.
  /// Sum must equal [total].
  final Map<String, MoneyMinor> participantSharesByMemberId;

  /// The currency code for this expense.
  String get currencyCode => total.currencyCode;

  NormalizedExpense._({
    required this.total,
    required this.description,
    required this.category,
    required this.date,
    required this.payerContributionsByMemberId,
    required this.participantSharesByMemberId,
  });

  /// Creates a NormalizedExpense with money invariant validation.
  /// 
  /// Throws [NormalizedExpenseError] if money invariants are violated.
  /// Does NOT validate description, category, or date (those are UI concerns).
  factory NormalizedExpense({
    required MoneyMinor total,
    String description = '',
    String category = '',
    String date = '',
    required Map<String, MoneyMinor> payerContributionsByMemberId,
    required Map<String, MoneyMinor> participantSharesByMemberId,
  }) {
    if (total.amountMinor <= 0) {
      throw NormalizedExpenseError('Amount must be positive');
    }
    if (payerContributionsByMemberId.isEmpty) {
      throw NormalizedExpenseError('Must have at least one payer');
    }
    if (participantSharesByMemberId.isEmpty) {
      throw NormalizedExpenseError('Must have at least one participant');
    }

    final currencyCode = total.currencyCode;

    for (final entry in payerContributionsByMemberId.entries) {
      if (entry.key.startsWith('p_')) {
        throw NormalizedExpenseError('Payer ID cannot be a pending member: ${entry.key}');
      }
      if (entry.key.isEmpty) {
        throw NormalizedExpenseError('Payer ID cannot be empty');
      }
      if (entry.value.currencyCode != currencyCode) {
        throw NormalizedExpenseError(
          'Payer contribution currency (${entry.value.currencyCode}) '
          'must match expense currency ($currencyCode)',
        );
      }
      if (entry.value.amountMinor < 0) {
        throw NormalizedExpenseError('Payer contribution must be non-negative');
      }
    }

    for (final entry in participantSharesByMemberId.entries) {
      if (entry.key.startsWith('p_')) {
        throw NormalizedExpenseError('Participant ID cannot be a pending member: ${entry.key}');
      }
      if (entry.key.isEmpty) {
        throw NormalizedExpenseError('Participant ID cannot be empty');
      }
      if (entry.value.currencyCode != currencyCode) {
        throw NormalizedExpenseError(
          'Participant share currency (${entry.value.currencyCode}) '
          'must match expense currency ($currencyCode)',
        );
      }
      if (entry.value.amountMinor < 0) {
        throw NormalizedExpenseError('Participant share must be non-negative');
      }
    }

    final payerSum = payerContributionsByMemberId.values
        .fold(0, (sum, m) => sum + m.amountMinor);
    if (payerSum != total.amountMinor) {
      throw NormalizedExpenseError(
        'Payer contributions ($payerSum) must equal total (${total.amountMinor})',
      );
    }

    final participantSum = participantSharesByMemberId.values
        .fold(0, (sum, m) => sum + m.amountMinor);
    if (participantSum != total.amountMinor) {
      throw NormalizedExpenseError(
        'Participant shares ($participantSum) must equal total (${total.amountMinor})',
      );
    }

    return NormalizedExpense._(
      total: total,
      description: description,
      category: category,
      date: date,
      payerContributionsByMemberId: Map.unmodifiable(payerContributionsByMemberId),
      participantSharesByMemberId: Map.unmodifiable(participantSharesByMemberId),
    );
  }

  /// The primary payer ID (first/only payer for single-payer expenses).
  String get primaryPayerId => payerContributionsByMemberId.keys.first;

  /// List of participant IDs.
  List<String> get participantIds => participantSharesByMemberId.keys.toList();

  /// Total amount in minor units (convenience getter).
  int get amountMinor => total.amountMinor;

  /// Creates a copy with optional field overrides.
  NormalizedExpense copyWith({
    MoneyMinor? total,
    String? description,
    String? category,
    String? date,
    Map<String, MoneyMinor>? payerContributionsByMemberId,
    Map<String, MoneyMinor>? participantSharesByMemberId,
  }) {
    return NormalizedExpense(
      total: total ?? this.total,
      description: description ?? this.description,
      category: category ?? this.category,
      date: date ?? this.date,
      payerContributionsByMemberId: payerContributionsByMemberId ?? this.payerContributionsByMemberId,
      participantSharesByMemberId: participantSharesByMemberId ?? this.participantSharesByMemberId,
    );
  }

  @override
  String toString() {
    return 'NormalizedExpense(total: $total, description: $description, '
        'payers: $payerContributionsByMemberId, participants: $participantSharesByMemberId)';
  }
}
