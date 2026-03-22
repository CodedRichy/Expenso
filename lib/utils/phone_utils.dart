/// Utility for consistent phone number normalization and formatting.
///
/// Ensures E.164 consistency across the app while providing human-readable
/// formatting for display.
class PhoneUtils {
  PhoneUtils._();

  /// Normalizes a raw phone string to digits only.
  static String normalize(String phone) {
    return phone.replaceAll(RegExp(r'\D'), '');
  }

  /// Normalizes to exactly 10 digits (strips country code).
  /// Aligned with legacy CycleRepository._normalizePhone.
  static String normalizeTo10Digits(String phone) {
    final digits = normalize(phone);
    if (digits.length >= 10) return digits.substring(digits.length - 10);
    return digits;
  }

  /// Formats a phone number for display.
  ///
  /// Currently optimized for Indian numbers (91 country code).
  static String formatDisplay(String phone) {
    final digits = normalize(phone);
    if (digits.length == 12 && digits.startsWith('91')) {
      return '+91 ${digits.substring(2, 7)} ${digits.substring(7)}';
    }
    if (digits.length == 10) {
      return '+91 ${digits.substring(0, 5)} ${digits.substring(5)}';
    }
    return phone;
  }

  /// Formats a phone number as E.164 (roughly) for database keys.
  /// Returns as-is if it appears to be an email address.
  static String formatE164(String input) {
    if (input.contains('@')) return input.trim();
    if (input.startsWith('+')) {
      final digits = normalize(input);
      return '+$digits';
    }
    final digits = normalize(input);
    if (digits.length == 10) return '+91$digits';
    if (digits.length == 12 && digits.startsWith('91')) return '+$digits';
    return '+$digits';
  }
}
