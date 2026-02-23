import 'currency.dart';

/// Immutable value object representing money in minor units (e.g., paise, cents).
/// 
/// This is the core type for all accounting math. Using integers eliminates
/// floating-point errors that can occur with currency calculations.
/// 
/// ## Design Principles
/// - **Integer-only:** [amountMinor] is already scaled (no decimals)
/// - **Currency-aware:** Carries [currencyCode] for validation
/// - **Immutable:** Cannot be modified after creation
/// - **No formatting:** Display logic lives outside this class
/// 
/// ## Examples
/// ```dart
/// // 100.50 INR = 10050 paise
/// final price = MoneyMinor(10050, 'INR');
/// 
/// // 1000 JPY (no minor units)
/// final yenPrice = MoneyMinor(1000, 'JPY');
/// 
/// // 1.500 KWD = 1500 fils
/// final dinarPrice = MoneyMinor(1500, 'KWD');
/// ```
class MoneyMinor {
  /// Amount in minor units (paise, cents, fils, etc.)
  /// 
  /// For currencies with no minor units (JPY, KRW), this equals the major unit amount.
  final int amountMinor;

  /// ISO 4217 currency code (e.g., "INR", "USD", "JPY")
  final String currencyCode;

  const MoneyMinor(this.amountMinor, this.currencyCode);

  /// Creates a zero amount in the given currency.
  const MoneyMinor.zero(this.currencyCode) : amountMinor = 0;

  /// Returns true if this amount is zero.
  bool get isZero => amountMinor == 0;

  /// Returns true if this amount is positive (> 0).
  bool get isPositive => amountMinor > 0;

  /// Returns true if this amount is negative (< 0).
  bool get isNegative => amountMinor < 0;

  /// Returns a new MoneyMinor with the negated amount.
  MoneyMinor operator -() => MoneyMinor(-amountMinor, currencyCode);

  /// Adds two MoneyMinor values. Currencies must match.
  MoneyMinor operator +(MoneyMinor other) {
    _assertSameCurrency(other);
    return MoneyMinor(amountMinor + other.amountMinor, currencyCode);
  }

  /// Subtracts two MoneyMinor values. Currencies must match.
  MoneyMinor operator -(MoneyMinor other) {
    _assertSameCurrency(other);
    return MoneyMinor(amountMinor - other.amountMinor, currencyCode);
  }

  void _assertSameCurrency(MoneyMinor other) {
    if (currencyCode != other.currencyCode) {
      throw ArgumentError(
        'Cannot perform arithmetic on different currencies: '
        '$currencyCode vs ${other.currencyCode}',
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MoneyMinor &&
          runtimeType == other.runtimeType &&
          amountMinor == other.amountMinor &&
          currencyCode == other.currencyCode;

  @override
  int get hashCode => amountMinor.hashCode ^ currencyCode.hashCode;

  @override
  String toString() => 'MoneyMinor($amountMinor $currencyCode)';
}

/// Utility functions for converting between display values and MoneyMinor.
/// 
/// These live outside the core MoneyMinor class to keep accounting logic
/// separate from parsing/formatting concerns.
class MoneyConversion {
  MoneyConversion._();

  /// Converts a display amount (double) to MoneyMinor.
  /// 
  /// Rounding is performed using half-up rounding.
  /// 
  /// Examples:
  /// - parseToMinor(100.50, 'INR') → MoneyMinor(10050, 'INR')
  /// - parseToMinor(1000, 'JPY') → MoneyMinor(1000, 'JPY')
  /// - parseToMinor(1.500, 'KWD') → MoneyMinor(1500, 'KWD')
  static MoneyMinor parseToMinor(double amount, String currencyCode) {
    final scale = CurrencyRegistry.minorUnitScale(currencyCode);
    final multiplier = _pow10(scale);
    final minorAmount = (amount * multiplier).round();
    return MoneyMinor(minorAmount, currencyCode);
  }

  /// Converts MoneyMinor to a display amount (double).
  /// 
  /// Use this only for display purposes, never for accounting math.
  /// 
  /// Examples:
  /// - toDisplay(MoneyMinor(10050, 'INR')) → 100.50
  /// - toDisplay(MoneyMinor(1000, 'JPY')) → 1000.0
  /// - toDisplay(MoneyMinor(1500, 'KWD')) → 1.500
  static double toDisplay(MoneyMinor money) {
    final scale = CurrencyRegistry.minorUnitScale(money.currencyCode);
    final multiplier = _pow10(scale);
    return money.amountMinor / multiplier;
  }

  /// Converts an integer minor amount to a display amount (double).
  static double minorToDisplay(int amountMinor, String currencyCode) {
    final scale = CurrencyRegistry.minorUnitScale(currencyCode);
    final multiplier = _pow10(scale);
    return amountMinor / multiplier;
  }

  static int _pow10(int exponent) {
    int result = 1;
    for (int i = 0; i < exponent; i++) {
      result *= 10;
    }
    return result;
  }
}

/// Splits a total amount among participants, handling remainder deterministically.
/// 
/// ## Remainder Strategy
/// The remainder (due to integer division) is assigned to the first participant
/// in the list. This is deterministic and documented.
/// 
/// ## Example
/// Splitting 100 paise among 3 people:
/// - Base share: 100 ÷ 3 = 33 paise each
/// - Remainder: 100 - (33 × 3) = 1 paise
/// - Result: [34, 33, 33] (first person gets the remainder)
class MoneySplitter {
  MoneySplitter._();

  /// Splits a total amount evenly among participants.
  /// 
  /// Returns a map of participant ID to their share in minor units.
  /// The remainder is assigned to the first participant (deterministic).
  static Map<String, int> splitEvenly({
    required int totalMinor,
    required List<String> participantIds,
    required String currencyCode,
  }) {
    if (participantIds.isEmpty) {
      throw ArgumentError('Cannot split among zero participants');
    }

    final count = participantIds.length;
    final baseShare = totalMinor ~/ count;
    final remainder = totalMinor - (baseShare * count);

    final result = <String, int>{};
    for (var i = 0; i < count; i++) {
      final id = participantIds[i];
      result[id] = (i == 0) ? baseShare + remainder : baseShare;
    }
    return result;
  }

  /// Distributes a total amount according to weights (shares/percentages).
  /// 
  /// The remainder is assigned to the participant with the largest weight.
  /// 
  /// [weights] is a map of participant ID to their relative weight.
  /// All weights must be non-negative, and at least one must be positive.
  static Map<String, int> splitByWeights({
    required int totalMinor,
    required Map<String, double> weights,
    required String currencyCode,
  }) {
    if (weights.isEmpty) {
      throw ArgumentError('Cannot split with no weights');
    }

    final totalWeight = weights.values.fold(0.0, (a, b) => a + b);
    if (totalWeight <= 0) {
      throw ArgumentError('Total weight must be positive');
    }

    final computed = <String, int>{};
    int allocated = 0;

    for (final entry in weights.entries) {
      final share = (totalMinor * entry.value / totalWeight).floor();
      computed[entry.key] = share;
      allocated += share;
    }

    final remainder = totalMinor - allocated;
    if (remainder > 0) {
      final largestWeightId = weights.entries
          .reduce((a, b) => a.value >= b.value ? a : b)
          .key;
      computed[largestWeightId] = computed[largestWeightId]! + remainder;
    }

    return computed;
  }

  /// Assigns exact amounts, validating that they sum to the total.
  /// 
  /// Returns the amounts as-is if they sum exactly to [totalMinor].
  /// Throws if the sum doesn't match.
  static Map<String, int> assignExact({
    required int totalMinor,
    required Map<String, int> amounts,
    required String currencyCode,
  }) {
    final sum = amounts.values.fold(0, (a, b) => a + b);
    if (sum != totalMinor) {
      throw ArgumentError(
        'Exact amounts ($sum) must equal total ($totalMinor)',
      );
    }
    return Map.unmodifiable(amounts);
  }
}
