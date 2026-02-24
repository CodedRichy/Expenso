enum PaymentAttemptStatus {
  notStarted,
  initiated,
  confirmedByPayer,
  confirmedByReceiver,
  disputed,
  cashPending,
  cashConfirmed,
}

extension PaymentAttemptStatusX on PaymentAttemptStatus {
  String get firestoreValue {
    switch (this) {
      case PaymentAttemptStatus.notStarted:
        return 'not_started';
      case PaymentAttemptStatus.initiated:
        return 'initiated';
      case PaymentAttemptStatus.confirmedByPayer:
        return 'confirmed_by_payer';
      case PaymentAttemptStatus.confirmedByReceiver:
        return 'confirmed_by_receiver';
      case PaymentAttemptStatus.disputed:
        return 'disputed';
      case PaymentAttemptStatus.cashPending:
        return 'cash_pending';
      case PaymentAttemptStatus.cashConfirmed:
        return 'cash_confirmed';
    }
  }

  static PaymentAttemptStatus fromFirestore(String? value) {
    switch (value) {
      case 'initiated':
        return PaymentAttemptStatus.initiated;
      case 'confirmed_by_payer':
        return PaymentAttemptStatus.confirmedByPayer;
      case 'confirmed_by_receiver':
        return PaymentAttemptStatus.confirmedByReceiver;
      case 'disputed':
        return PaymentAttemptStatus.disputed;
      case 'cash_pending':
        return PaymentAttemptStatus.cashPending;
      case 'cash_confirmed':
        return PaymentAttemptStatus.cashConfirmed;
      default:
        return PaymentAttemptStatus.notStarted;
    }
  }

  String get displayLabel {
    switch (this) {
      case PaymentAttemptStatus.notStarted:
        return 'Not started';
      case PaymentAttemptStatus.initiated:
        return 'Payment initiated';
      case PaymentAttemptStatus.confirmedByPayer:
        return 'Marked as paid';
      case PaymentAttemptStatus.confirmedByReceiver:
        return 'Confirmed received';
      case PaymentAttemptStatus.disputed:
        return 'Disputed';
      case PaymentAttemptStatus.cashPending:
        return 'Cash payment pending';
      case PaymentAttemptStatus.cashConfirmed:
        return 'Cash received';
    }
  }

  bool get isPending => this == PaymentAttemptStatus.initiated;
  bool get isConfirmedByPayer => this == PaymentAttemptStatus.confirmedByPayer;
  bool get isConfirmedByReceiver => this == PaymentAttemptStatus.confirmedByReceiver;
  bool get isDisputed => this == PaymentAttemptStatus.disputed;
  bool get isCashPending => this == PaymentAttemptStatus.cashPending;
  bool get isCashConfirmed => this == PaymentAttemptStatus.cashConfirmed;
  bool get isSettled => isConfirmedByPayer || isConfirmedByReceiver || isCashConfirmed;
  bool get isFullyConfirmed => isConfirmedByReceiver || isCashConfirmed;
  bool get isAwaitingReceiverAction => isConfirmedByPayer || isCashPending;
}

class PaymentAttempt {
  final String id;
  final String groupId;
  final String cycleId;
  final String fromMemberId;
  final String toMemberId;
  final int amountMinor;
  final String currencyCode;
  final PaymentAttemptStatus status;
  final int createdAt;
  final int? initiatedAt;
  final int? confirmedAt;
  final String? upiTransactionId;
  final String? upiResponseCode;

  const PaymentAttempt({
    required this.id,
    required this.groupId,
    required this.cycleId,
    required this.fromMemberId,
    required this.toMemberId,
    required this.amountMinor,
    required this.currencyCode,
    required this.status,
    required this.createdAt,
    this.initiatedAt,
    this.confirmedAt,
    this.upiTransactionId,
    this.upiResponseCode,
  });

  bool get hasUpiProof => upiTransactionId != null && upiTransactionId!.isNotEmpty;

  String get routeKey => '${fromMemberId}_$toMemberId';

  PaymentAttempt copyWith({
    PaymentAttemptStatus? status,
    int? initiatedAt,
    int? confirmedAt,
    String? upiTransactionId,
    String? upiResponseCode,
  }) {
    return PaymentAttempt(
      id: id,
      groupId: groupId,
      cycleId: cycleId,
      fromMemberId: fromMemberId,
      toMemberId: toMemberId,
      amountMinor: amountMinor,
      currencyCode: currencyCode,
      status: status ?? this.status,
      createdAt: createdAt,
      initiatedAt: initiatedAt ?? this.initiatedAt,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      upiTransactionId: upiTransactionId ?? this.upiTransactionId,
      upiResponseCode: upiResponseCode ?? this.upiResponseCode,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'groupId': groupId,
      'cycleId': cycleId,
      'fromMemberId': fromMemberId,
      'toMemberId': toMemberId,
      'amountMinor': amountMinor,
      'currencyCode': currencyCode,
      'status': status.firestoreValue,
      'createdAt': createdAt,
      if (initiatedAt != null) 'initiatedAt': initiatedAt,
      if (confirmedAt != null) 'confirmedAt': confirmedAt,
      if (upiTransactionId != null) 'upiTransactionId': upiTransactionId,
      if (upiResponseCode != null) 'upiResponseCode': upiResponseCode,
    };
  }

  factory PaymentAttempt.fromFirestore(String id, Map<String, dynamic> data) {
    return PaymentAttempt(
      id: id,
      groupId: data['groupId'] as String? ?? '',
      cycleId: data['cycleId'] as String? ?? '',
      fromMemberId: data['fromMemberId'] as String? ?? '',
      toMemberId: data['toMemberId'] as String? ?? '',
      amountMinor: data['amountMinor'] as int? ?? 0,
      currencyCode: data['currencyCode'] as String? ?? 'INR',
      status: PaymentAttemptStatusX.fromFirestore(data['status'] as String?),
      createdAt: data['createdAt'] as int? ?? 0,
      initiatedAt: data['initiatedAt'] as int?,
      confirmedAt: data['confirmedAt'] as int?,
      upiTransactionId: data['upiTransactionId'] as String?,
      upiResponseCode: data['upiResponseCode'] as String?,
    );
  }

  factory PaymentAttempt.create({
    required String groupId,
    required String cycleId,
    required String fromMemberId,
    required String toMemberId,
    required int amountMinor,
    String currencyCode = 'INR',
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return PaymentAttempt(
      id: 'pa_$now',
      groupId: groupId,
      cycleId: cycleId,
      fromMemberId: fromMemberId,
      toMemberId: toMemberId,
      amountMinor: amountMinor,
      currencyCode: currencyCode,
      status: PaymentAttemptStatus.notStarted,
      createdAt: now,
    );
  }
}
