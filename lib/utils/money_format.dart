import '../models/currency.dart';
import '../models/money_minor.dart';

String formatMoney(int amountMinor) {
  return formatMoneyWithCurrency(amountMinor, 'INR');
}

/// Formats [amountMinor] using the symbol for [currencyCode]. Uses correct decimal places.
String formatMoneyWithCurrency(int amountMinor, String currencyCode) {
  final display = MoneyConversion.minorToDisplay(amountMinor, currencyCode);
  final scale = CurrencyRegistry.minorUnitScale(currencyCode);
  final fixed = scale == 0
      ? display.round().toString()
      : display.toStringAsFixed(scale);
  final parts = fixed.split('.');
  final intPart = parts[0].replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );
  final formatted = parts.length > 1 ? '$intPart.${parts[1]}' : intPart;
  return '${CurrencyRegistry.symbol(currencyCode)}$formatted';
}
