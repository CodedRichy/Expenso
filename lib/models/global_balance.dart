class GroupContribution {
  final String groupId;
  final String groupName;
  final int balanceMinor;

  const GroupContribution({
    required this.groupId,
    required this.groupName,
    required this.balanceMinor,
  });

  double get balanceDisplay => balanceMinor / 100;
}

class GlobalBalance {
  final String contactPhone;
  final String contactName;
  final String? contactPhotoURL;
  final int netBalanceMinor;
  final List<GroupContribution> breakdown;

  const GlobalBalance({
    required this.contactPhone,
    required this.contactName,
    this.contactPhotoURL,
    required this.netBalanceMinor,
    required this.breakdown,
  });

  double get netBalanceDisplay => netBalanceMinor / 100;

  bool get theyOweYou => netBalanceMinor > 0;
  bool get youOweThem => netBalanceMinor < 0;
  bool get settled => netBalanceMinor == 0;

  int get groupCount => breakdown.length;
}
