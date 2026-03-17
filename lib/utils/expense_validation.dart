/// Maximum allowed expense amount (10 lakh / 1 million in major units).
const double maxExpenseAmount = 1000000.0;

/// Maximum length for expense descriptions.
const int maxDescriptionLength = 200;

/// Maximum length for group names.
const int maxGroupNameLength = 100;

/// Strips HTML tags and script content from user input.
/// Prevents XSS when values are rendered in the admin dashboard.
String sanitizeTextInput(String input) {
  // Remove <script>...</script> blocks (case-insensitive, multiline)
  var cleaned = input.replaceAll(RegExp(r'<script[^>]*>.*?</script>', caseSensitive: false, dotAll: true), '');
  // Remove all remaining HTML tags
  cleaned = cleaned.replaceAll(RegExp(r'<[^>]*>'), '');
  return cleaned.trim();
}

/// Returns an error message if the amount is invalid, otherwise null.
String? validateExpenseAmount(double amount) {
  if (amount.isNaN || amount.isInfinite) return 'Amount is not a valid number.';
  if (amount <= 0) return 'Amount must be greater than 0.';
  if (amount > maxExpenseAmount) return 'Amount cannot exceed ${maxExpenseAmount.toStringAsFixed(0)}.';
  return null;
}

/// Returns an error message if the description is invalid, otherwise null.
String? validateExpenseDescription(String description) {
  final trimmed = description.trim();
  if (trimmed.isEmpty) return 'Description cannot be empty.';
  if (trimmed.length > maxDescriptionLength) {
    return 'Description must be $maxDescriptionLength characters or less.';
  }
  return null;
}

/// Returns an error message if the group name is invalid, otherwise null.
String? validateGroupName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return 'Group name cannot be empty.';
  if (trimmed.length > maxGroupNameLength) {
    return 'Group name must be $maxGroupNameLength characters or less.';
  }
  return null;
}
