// Validation helpers for expense data. Used before persisting to Firestore.

/// Returns an error message if the amount is invalid, otherwise null.
String? validateExpenseAmount(double amount) {
  if (amount.isNaN) return 'Amount is not a valid number.';
  if (amount <= 0) return 'Amount must be greater than 0.';
  return null;
}

/// Returns an error message if the description is invalid, otherwise null.
String? validateExpenseDescription(String description) {
  final trimmed = description.trim();
  if (trimmed.isEmpty) return 'Description cannot be empty.';
  return null;
}
