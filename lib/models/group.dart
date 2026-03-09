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
