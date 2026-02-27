/// Shared country list: E.164 dial code, ISO 3166 country code, display name, ISO 4217 currency.
/// Use for phone input (auth, invite) and for suggesting/defaulting currency by country.
class CountryEntry {
  final String dialCode;
  final String countryCode;
  final String name;
  final String currencyCode;

  const CountryEntry({
    required this.dialCode,
    required this.countryCode,
    required this.name,
    required this.currencyCode,
  });

  Map<String, String> get asMap => {
        'code': dialCode,
        'country': countryCode,
        'name': name,
        'currencyCode': currencyCode,
      };
}

const List<CountryEntry> countryCodesWithCurrency = [
  CountryEntry(dialCode: '+91', countryCode: 'IN', name: 'India', currencyCode: 'INR'),
  CountryEntry(dialCode: '+1', countryCode: 'US', name: 'United States', currencyCode: 'USD'),
  CountryEntry(dialCode: '+44', countryCode: 'GB', name: 'United Kingdom', currencyCode: 'GBP'),
  CountryEntry(dialCode: '+971', countryCode: 'AE', name: 'UAE', currencyCode: 'AED'),
  CountryEntry(dialCode: '+65', countryCode: 'SG', name: 'Singapore', currencyCode: 'SGD'),
  CountryEntry(dialCode: '+61', countryCode: 'AU', name: 'Australia', currencyCode: 'AUD'),
  CountryEntry(dialCode: '+49', countryCode: 'DE', name: 'Germany', currencyCode: 'EUR'),
  CountryEntry(dialCode: '+33', countryCode: 'FR', name: 'France', currencyCode: 'EUR'),
  CountryEntry(dialCode: '+81', countryCode: 'JP', name: 'Japan', currencyCode: 'JPY'),
  CountryEntry(dialCode: '+86', countryCode: 'CN', name: 'China', currencyCode: 'CNY'),
  CountryEntry(dialCode: '+82', countryCode: 'KR', name: 'South Korea', currencyCode: 'KRW'),
  CountryEntry(dialCode: '+55', countryCode: 'BR', name: 'Brazil', currencyCode: 'BRL'),
  CountryEntry(dialCode: '+52', countryCode: 'MX', name: 'Mexico', currencyCode: 'MXN'),
  CountryEntry(dialCode: '+7', countryCode: 'RU', name: 'Russia', currencyCode: 'RUB'),
  CountryEntry(dialCode: '+27', countryCode: 'ZA', name: 'South Africa', currencyCode: 'ZAR'),
];

String? currencyCodeForDialCode(String dialCode) {
  for (final c in countryCodesWithCurrency) {
    if (c.dialCode == dialCode) return c.currencyCode;
  }
  return null;
}
