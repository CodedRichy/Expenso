// Shared data models for the Expenso app

class Group {
  final String id;
  final String name;
  final String status;
  final double amount;
  final String statusLine;
  final String creatorId;
  final List<String> memberIds;

  Group({
    required this.id,
    required this.name,
    required this.status,
    required this.amount,
    required this.statusLine,
    required this.creatorId,
    List<String>? memberIds,
  }) : memberIds = memberIds ?? [];
}

class Member {
  final String id;
  final String phone; // primary identifier
  final String name;  // optional display name

  Member({
    required this.id,
    required this.phone,
    this.name = '',
  });
}

class Expense {
  final String id;
  final String description;
  final double amount;
  final String date;
  final List<String> participantPhones;
  final String paidByPhone;
  /// Per-person share (phone -> amount). When non-null, balances use these; else equal split.
  final Map<String, double>? splitAmountsByPhone;

  Expense({
    required this.id,
    required this.description,
    required this.amount,
    required this.date,
    List<String>? participantPhones,
    this.paidByPhone = '',
    this.splitAmountsByPhone,
  }) : participantPhones = participantPhones ?? [];
}
