/// Currency metadata using ISO 4217 standard.
/// 
/// This model provides currency-specific information needed for
/// correct integer-based accounting math.
/// 
/// ## Design Principles
/// - **Metadata-driven:** Currency behavior is declarative, not hardcoded
/// - **Extensible:** New currencies can be added without touching accounting logic
/// - **Immutable:** Currency definitions never change at runtime
class Currency {
  /// ISO 4217 currency code (e.g., "INR", "USD", "JPY")
  final String code;

  /// Number of decimal places in the minor unit.
  /// 
  /// Examples:
  /// - INR, USD, EUR: 2 (100 paise/cents per unit)
  /// - JPY, KRW: 0 (no minor unit)
  /// - KWD, BHD: 3 (1000 fils per dinar)
  final int minorUnitScale;

  const Currency({
    required this.code,
    required this.minorUnitScale,
  });

  /// The multiplier to convert major units to minor units.
  /// 
  /// Examples:
  /// - minorUnitScale 2: multiplier = 100
  /// - minorUnitScale 0: multiplier = 1
  /// - minorUnitScale 3: multiplier = 1000
  int get multiplier {
    int result = 1;
    for (int i = 0; i < minorUnitScale; i++) {
      result *= 10;
    }
    return result;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Currency &&
          runtimeType == other.runtimeType &&
          code == other.code &&
          minorUnitScale == other.minorUnitScale;

  @override
  int get hashCode => code.hashCode ^ minorUnitScale.hashCode;

  @override
  String toString() => 'Currency($code, scale: $minorUnitScale)';
}

/// Registry of supported currencies.
/// 
/// This is the single source of truth for currency metadata.
/// To add a new currency, add it here. No other changes needed.
class CurrencyRegistry {
  CurrencyRegistry._();

  static const Currency inr = Currency(code: 'INR', minorUnitScale: 2);
  static const Currency usd = Currency(code: 'USD', minorUnitScale: 2);
  static const Currency eur = Currency(code: 'EUR', minorUnitScale: 2);
  static const Currency gbp = Currency(code: 'GBP', minorUnitScale: 2);
  static const Currency jpy = Currency(code: 'JPY', minorUnitScale: 0);
  static const Currency krw = Currency(code: 'KRW', minorUnitScale: 0);
  static const Currency kwd = Currency(code: 'KWD', minorUnitScale: 3);
  static const Currency bhd = Currency(code: 'BHD', minorUnitScale: 3);
  static const Currency aed = Currency(code: 'AED', minorUnitScale: 2);
  static const Currency sgd = Currency(code: 'SGD', minorUnitScale: 2);
  static const Currency aud = Currency(code: 'AUD', minorUnitScale: 2);
  static const Currency cny = Currency(code: 'CNY', minorUnitScale: 2);
  static const Currency brl = Currency(code: 'BRL', minorUnitScale: 2);
  static const Currency mxn = Currency(code: 'MXN', minorUnitScale: 2);
  static const Currency rub = Currency(code: 'RUB', minorUnitScale: 2);
  static const Currency zar = Currency(code: 'ZAR', minorUnitScale: 2);

  static const List<Currency> _all = [
    inr, usd, eur, gbp, jpy, krw, kwd, bhd,
    aed, sgd, aud, cny, brl, mxn, rub, zar,
  ];

  static const Currency defaultCurrency = inr;

  /// Returns the Currency for the given code, or null if not found.
  static Currency? lookup(String code) {
    final upperCode = code.toUpperCase();
    for (final c in _all) {
      if (c.code == upperCode) return c;
    }
    return null;
  }

  /// Returns the Currency for the given code, or throws if not found.
  static Currency require(String code) {
    final currency = lookup(code);
    if (currency == null) {
      throw ArgumentError('Unknown currency code: $code');
    }
    return currency;
  }

  /// Returns the minor unit scale for a currency code.
  /// 
  /// Defaults to 2 if currency is unknown (safe default for most currencies).
  static int minorUnitScale(String code) {
    return lookup(code)?.minorUnitScale ?? 2;
  }

  /// List of all supported currency codes.
  static List<String> get supportedCodes => _all.map((c) => c.code).toList();
}
