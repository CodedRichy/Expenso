class Group {
  final String id;
  final String name;
  final String status;
  final double amount;
  final String statusLine;
  final String creatorId;
  final List<String> memberIds;
  final String currencyCode;
  /// Random 16-char alphanumeric token for the invite link.
  /// Null if invite links have never been generated for this group.
  final String? inviteLinkToken;
  /// Whether invite links are currently active for this group.
  final bool inviteLinkEnabled;

  Group({
    required this.id,
    required this.name,
    required this.status,
    required this.amount,
    required this.statusLine,
    required this.creatorId,
    List<String>? memberIds,
    this.currencyCode = 'INR',
    this.inviteLinkToken,
    this.inviteLinkEnabled = false,
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
    final expenseDay = DateTime(expenseDate.year, expenseDate.month, expenseDate.day);
    
    final diff = today.difference(expenseDay).inDays;
    
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '$diff days ago';
    
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final month = months[expenseDate.month - 1];
    
    if (expenseDate.year == now.year) {
      return '$month ${expenseDate.day}';
    }
    return '$month ${expenseDate.day}, ${expenseDate.year}';
  }
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

/// A system message shown in the group activity feed (e.g. "Alice joined", "Bob deleted Dinner ₹500").
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
