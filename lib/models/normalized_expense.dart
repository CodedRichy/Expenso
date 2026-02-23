const double _tolerance = 0.01;

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
/// 
/// ## Money Invariants (enforced at construction)
/// - `sum(payerContributions) == amount` (within tolerance)
/// - `sum(participantShares) == amount` (within tolerance)
/// - All map keys are valid member IDs (no `p_` prefixes, non-empty)
/// - All amounts are non-negative and finite
/// 
/// ## Non-Invariants (NOT validated here)
/// - Description content (validated at UI/parsing layer)
/// - Category validity
/// - Date format
/// 
/// All person references are member IDs (UUIDs), never names.
/// "Everyone" semantics must be expanded to concrete IDs before construction.
class NormalizedExpense {
  final double amount;
  final String description;
  final String category;
  final String date;
  
  /// Who paid and how much. Supports multiple payers (future-proof).
  /// Keys are member IDs, values are positive contribution amounts.
  /// Sum must equal [amount].
  final Map<String, double> payerContributionsByMemberId;
  
  /// Who owes what share. Keys are member IDs, values are positive amounts owed.
  /// Sum must equal [amount].
  final Map<String, double> participantSharesByMemberId;

  NormalizedExpense._({
    required this.amount,
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
    required double amount,
    String description = '',
    String category = '',
    String date = '',
    required Map<String, double> payerContributionsByMemberId,
    required Map<String, double> participantSharesByMemberId,
  }) {
    if (amount <= 0 || amount.isNaN || amount.isInfinite) {
      throw NormalizedExpenseError('Amount must be positive and finite');
    }
    if (payerContributionsByMemberId.isEmpty) {
      throw NormalizedExpenseError('Must have at least one payer');
    }
    if (participantSharesByMemberId.isEmpty) {
      throw NormalizedExpenseError('Must have at least one participant');
    }

    for (final key in payerContributionsByMemberId.keys) {
      if (key.startsWith('p_')) {
        throw NormalizedExpenseError('Payer ID cannot be a pending member: $key');
      }
      if (key.isEmpty) {
        throw NormalizedExpenseError('Payer ID cannot be empty');
      }
    }
    for (final key in participantSharesByMemberId.keys) {
      if (key.startsWith('p_')) {
        throw NormalizedExpenseError('Participant ID cannot be a pending member: $key');
      }
      if (key.isEmpty) {
        throw NormalizedExpenseError('Participant ID cannot be empty');
      }
    }

    for (final value in payerContributionsByMemberId.values) {
      if (value < 0 || value.isNaN || value.isInfinite) {
        throw NormalizedExpenseError('Payer contribution must be non-negative and finite');
      }
    }
    for (final value in participantSharesByMemberId.values) {
      if (value < 0 || value.isNaN || value.isInfinite) {
        throw NormalizedExpenseError('Participant share must be non-negative and finite');
      }
    }

    final payerSum = payerContributionsByMemberId.values.fold(0.0, (a, b) => a + b);
    if ((payerSum - amount).abs() > _tolerance) {
      throw NormalizedExpenseError(
        'Payer contributions ($payerSum) must equal amount ($amount)',
      );
    }

    final participantSum = participantSharesByMemberId.values.fold(0.0, (a, b) => a + b);
    if ((participantSum - amount).abs() > _tolerance) {
      throw NormalizedExpenseError(
        'Participant shares ($participantSum) must equal amount ($amount)',
      );
    }

    return NormalizedExpense._(
      amount: amount,
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

  /// Creates a copy with optional field overrides.
  NormalizedExpense copyWith({
    double? amount,
    String? description,
    String? category,
    String? date,
    Map<String, double>? payerContributionsByMemberId,
    Map<String, double>? participantSharesByMemberId,
  }) {
    return NormalizedExpense(
      amount: amount ?? this.amount,
      description: description ?? this.description,
      category: category ?? this.category,
      date: date ?? this.date,
      payerContributionsByMemberId: payerContributionsByMemberId ?? this.payerContributionsByMemberId,
      participantSharesByMemberId: participantSharesByMemberId ?? this.participantSharesByMemberId,
    );
  }

  @override
  String toString() {
    return 'NormalizedExpense(amount: $amount, description: $description, '
        'payers: $payerContributionsByMemberId, participants: $participantSharesByMemberId)';
  }
}
