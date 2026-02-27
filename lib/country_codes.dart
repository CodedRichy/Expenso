/// Shared country list: E.164 dial code, ISO 3166 country code, display name, ISO 4217 currency.
/// Use for phone input (auth, invite) and for suggesting/defaulting currency by country.
class CountryEntry {
  final String dialCode;
  final String countryCode;
  final String name;
  final String currencyCode;
  final int maxPhoneDigits;

  const CountryEntry({
    required this.dialCode,
    required this.countryCode,
    required this.name,
    required this.currencyCode,
    this.maxPhoneDigits = 12,
  });

  Map<String, String> get asMap => {
        'code': dialCode,
        'country': countryCode,
        'name': name,
        'currencyCode': currencyCode,
      };
}

const List<CountryEntry> countryCodesWithCurrency = [
  CountryEntry(dialCode: '+91', countryCode: 'IN', name: 'India', currencyCode: 'INR', maxPhoneDigits: 10),
  CountryEntry(dialCode: '+1', countryCode: 'US', name: 'United States', currencyCode: 'USD', maxPhoneDigits: 10),
  CountryEntry(dialCode: '+44', countryCode: 'GB', name: 'United Kingdom', currencyCode: 'GBP', maxPhoneDigits: 11),
  CountryEntry(dialCode: '+971', countryCode: 'AE', name: 'United Arab Emirates', currencyCode: 'AED', maxPhoneDigits: 9),
  CountryEntry(dialCode: '+65', countryCode: 'SG', name: 'Singapore', currencyCode: 'SGD', maxPhoneDigits: 8),
  CountryEntry(dialCode: '+61', countryCode: 'AU', name: 'Australia', currencyCode: 'AUD', maxPhoneDigits: 9),
  CountryEntry(dialCode: '+49', countryCode: 'DE', name: 'Germany', currencyCode: 'EUR', maxPhoneDigits: 11),
  CountryEntry(dialCode: '+33', countryCode: 'FR', name: 'France', currencyCode: 'EUR', maxPhoneDigits: 9),
  CountryEntry(dialCode: '+81', countryCode: 'JP', name: 'Japan', currencyCode: 'JPY', maxPhoneDigits: 10),
  CountryEntry(dialCode: '+86', countryCode: 'CN', name: 'China', currencyCode: 'CNY', maxPhoneDigits: 11),
  CountryEntry(dialCode: '+82', countryCode: 'KR', name: 'South Korea', currencyCode: 'KRW', maxPhoneDigits: 10),
  CountryEntry(dialCode: '+55', countryCode: 'BR', name: 'Brazil', currencyCode: 'BRL', maxPhoneDigits: 11),
  CountryEntry(dialCode: '+52', countryCode: 'MX', name: 'Mexico', currencyCode: 'MXN', maxPhoneDigits: 10),
  CountryEntry(dialCode: '+7', countryCode: 'RU', name: 'Russia', currencyCode: 'RUB', maxPhoneDigits: 10),
  CountryEntry(dialCode: '+27', countryCode: 'ZA', name: 'South Africa', currencyCode: 'ZAR', maxPhoneDigits: 9),
];

String? currencyCodeForDialCode(String dialCode) {
  for (final c in countryCodesWithCurrency) {
    if (c.dialCode == dialCode) return c.currencyCode;
  }
  return null;
}

int maxPhoneDigitsForDialCode(String dialCode) {
  for (final c in countryCodesWithCurrency) {
    if (c.dialCode == dialCode) return c.maxPhoneDigits;
  }
  return 12;
}
