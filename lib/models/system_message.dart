class SystemMessage {
  final String id;
  final String type; // 'joined', 'declined', 'left', 'created', 'expense_edited', 'expense_deleted'
  final String userId;
  final String userName;
  final String date;
  final int timestamp;

  /// Short detail string for audit entries (e.g. '"Dinner" → "Dinner + dessert", ₹500 → ₹600').
  final String detail;

  /// Display prefix (e.g. 'Rishi (admin) edited'). Falls back to type-based rendering if empty.
  final String prefix;

  const SystemMessage({
    required this.id,
    required this.type,
    required this.userId,
    required this.userName,
    required this.date,
    required this.timestamp,
    this.detail = '',
    this.prefix = '',
  });
}
