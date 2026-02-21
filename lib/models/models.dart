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
  /// Profile photo URL (Firebase Storage). Null for pending members or when not set.
  final String? photoURL;

  Member({
    required this.id,
    required this.phone,
    this.name = '',
    this.photoURL,
  });
}

class Expense {
  final String id;
  final String description;
  final double amount;
  final String date;
  final List<String> participantIds;
  final String paidById;
  /// Per-person share (member id -> amount). When non-null, balances use these; else equal split.
  final Map<String, double>? splitAmountsById;
  final String category;
  final String splitType;

  Expense({
    required this.id,
    required this.description,
    required this.amount,
    required this.date,
    List<String>? participantIds,
    this.paidById = '',
    this.splitAmountsById,
    this.category = '',
    this.splitType = 'Even',
  }) : participantIds = participantIds ?? [];
}

/// One transfer from current user (debtor) to a creditor for settlement.
class SettlementTransfer {
  final String creditorPhone;
  final String creditorDisplayName;
  final double amount;

  const SettlementTransfer({
    required this.creditorPhone,
    required this.creditorDisplayName,
    required this.amount,
  });
}

/// A pending group invitation for the current user.
class GroupInvitation {
  final String groupId;
  final String groupName;
  final String creatorId;

  const GroupInvitation({
    required this.groupId,
    required this.groupName,
    required this.creatorId,
  });
}

/// A system message shown in the group activity feed (e.g. "Alice joined", "Bob declined").
class SystemMessage {
  final String id;
  final String type; // 'joined', 'declined', 'left', 'created'
  final String userId;
  final String userName;
  final String date;
  final int timestamp;

  const SystemMessage({
    required this.id,
    required this.type,
    required this.userId,
    required this.userName,
    required this.date,
    required this.timestamp,
  });
}
