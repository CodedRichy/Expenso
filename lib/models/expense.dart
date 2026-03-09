class Expense {
  final String id;
  final String description;
  final double amount;
  final String date;
  final List<String> participantIds;
  final String paidById;

  /// UID of the user who originally created this expense. Used for permission checks.
  final String createdById;

  /// Per-person share (member id -> amount). When non-null, balances use these; else equal split.
  final Map<String, double>? splitAmountsById;
  final String category;
  final String splitType;

  /// When set (from Firestore amountMinor/splitsMinor), settlement uses integer path.
  final int? amountMinor;
  final Map<String, int>? splitAmountsByIdMinor;

  Expense({
    required this.id,
    required this.description,
    required this.amount,
    required this.date,
    List<String>? participantIds,
    this.paidById = '',
    this.createdById = '',
    this.splitAmountsById,
    this.category = '',
    this.splitType = 'Even',
    this.amountMinor,
    this.splitAmountsByIdMinor,
  }) : participantIds = participantIds ?? [];

  String get displayDate {
    final timestamp = int.tryParse(date);
    if (timestamp == null) {
      return date;
    }

    final expenseDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expenseDay = DateTime(
      expenseDate.year,
      expenseDate.month,
      expenseDate.day,
    );

    final diff = today.difference(expenseDay).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '$diff days ago';

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final month = months[expenseDate.month - 1];

    if (expenseDate.year == now.year) {
      return '$month ${expenseDate.day}';
    }
    return '$month ${expenseDate.day}, ${expenseDate.year}';
  }
}
