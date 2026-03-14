class CurrencyService {
  static const Map<String, double> _rates = {
    'INR': 1.0,
    'USD': 0.012,
    'EUR': 0.011,
    'GBP': 0.0094,
  };

  static double convert(double amount, String fromCode, String toCode) {
    if (fromCode == toCode) return amount;
    double fromRate = _rates[fromCode] ?? 1.0;
    double toRate = _rates[toCode] ?? 1.0;
    
    // amount in base format (conceptually INR here)
    double baseAmount = amount / fromRate;
    return baseAmount * toRate;
  }
  
  static String format(double amount, String currencyCode) {
    switch (currencyCode) {
      case 'USD':
        return '\$${amount.toStringAsFixed(2)}';
      case 'EUR':
        return '€${amount.toStringAsFixed(2)}';
      case 'GBP':
        return '£${amount.toStringAsFixed(2)}';
      case 'INR':
      default:
        return '₹${amount.toStringAsFixed(2)}';
    }
  }
}
