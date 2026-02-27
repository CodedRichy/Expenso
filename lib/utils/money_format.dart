import 'dart:ui' as ui;

import 'package:intl/intl.dart';

import '../models/currency.dart';
import '../models/money_minor.dart';

String formatMoney(int amountMinor) {
  return formatMoneyWithCurrency(amountMinor, 'INR');
}

/// Formats [amount] (major units, e.g. 100.50) using the symbol for [currencyCode].
String formatMoneyFromMajor(double amount, String currencyCode) {
  final minor = MoneyConversion.parseToMinor(amount, currencyCode).amountMinor;
  return formatMoneyWithCurrency(minor, currencyCode);
}

/// Formats [amountMinor] using the symbol for [currencyCode].
/// Uses device locale for thousands/decimal separators when available (e.g. EU uses space, comma).
/// [locale] overrides device locale when provided (e.g. from BuildContext).
String formatMoneyWithCurrency(int amountMinor, String currencyCode, [String? locale]) {
  final display = MoneyConversion.minorToDisplay(amountMinor, currencyCode);
  final scale = CurrencyRegistry.minorUnitScale(currencyCode);
  final symbol = CurrencyRegistry.symbol(currencyCode);
  final localeStr = locale ?? ui.PlatformDispatcher.instance.locale.toString();

  try {
    final format = NumberFormat.currency(
      locale: localeStr,
      symbol: symbol,
      decimalDigits: scale,
    );
    return format.format(display);
  } catch (_) {
    final fixed = scale == 0
        ? display.round().toString()
        : display.toStringAsFixed(scale);
    final parts = fixed.split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    final formatted = parts.length > 1 ? '$intPart.${parts[1]}' : intPart;
    return '$symbol$formatted';
  }
}
