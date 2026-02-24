import '../utils/money_format.dart';

enum SettlementEventType {
  cycleSettlementStarted,
  paymentInitiated,
  paymentPending,
  paymentConfirmedByPayer,
  paymentConfirmedByReceiver,
  paymentFailed,
  paymentDisputed,
  cashConfirmationRequested,
  cashConfirmed,
  cycleFullySettled,
  cycleArchived,
  pendingReminder,
}

extension SettlementEventTypeX on SettlementEventType {
  String get firestoreValue {
    switch (this) {
      case SettlementEventType.cycleSettlementStarted:
        return 'cycle_settlement_started';
      case SettlementEventType.paymentInitiated:
        return 'payment_initiated';
      case SettlementEventType.paymentPending:
        return 'payment_pending';
      case SettlementEventType.paymentConfirmedByPayer:
        return 'payment_confirmed_by_payer';
      case SettlementEventType.paymentConfirmedByReceiver:
        return 'payment_confirmed_by_receiver';
      case SettlementEventType.paymentFailed:
        return 'payment_failed';
      case SettlementEventType.paymentDisputed:
        return 'payment_disputed';
      case SettlementEventType.cashConfirmationRequested:
        return 'cash_confirmation_requested';
      case SettlementEventType.cashConfirmed:
        return 'cash_confirmed';
      case SettlementEventType.cycleFullySettled:
        return 'cycle_fully_settled';
      case SettlementEventType.cycleArchived:
        return 'cycle_archived';
      case SettlementEventType.pendingReminder:
        return 'pending_reminder';
    }
  }

  static SettlementEventType fromFirestore(String value) {
    switch (value) {
      case 'cycle_settlement_started':
        return SettlementEventType.cycleSettlementStarted;
      case 'payment_initiated':
        return SettlementEventType.paymentInitiated;
      case 'payment_pending':
        return SettlementEventType.paymentPending;
      case 'payment_confirmed_by_payer':
        return SettlementEventType.paymentConfirmedByPayer;
      case 'payment_confirmed_by_receiver':
        return SettlementEventType.paymentConfirmedByReceiver;
      case 'payment_failed':
        return SettlementEventType.paymentFailed;
      case 'payment_disputed':
        return SettlementEventType.paymentDisputed;
      case 'cash_confirmation_requested':
        return SettlementEventType.cashConfirmationRequested;
      case 'cash_confirmed':
        return SettlementEventType.cashConfirmed;
      case 'cycle_fully_settled':
        return SettlementEventType.cycleFullySettled;
      case 'cycle_archived':
        return SettlementEventType.cycleArchived;
      case 'pending_reminder':
        return SettlementEventType.pendingReminder;
      default:
        return SettlementEventType.cycleSettlementStarted;
    }
  }
}

class SettlementEvent {
  final String id;
  final SettlementEventType type;
  final int? amountMinor;
  final int timestamp;
  final String? paymentAttemptId;
  final int? pendingCount;

  const SettlementEvent({
    required this.id,
    required this.type,
    this.amountMinor,
    required this.timestamp,
    this.paymentAttemptId,
    this.pendingCount,
  });

  factory SettlementEvent.fromFirestore(Map<String, dynamic> data) {
    return SettlementEvent(
      id: data['id'] as String? ?? '',
      type: SettlementEventTypeX.fromFirestore(data['type'] as String? ?? ''),
      amountMinor: data['amountMinor'] as int?,
      timestamp: data['timestamp'] as int? ?? 0,
      paymentAttemptId: data['paymentAttemptId'] as String?,
      pendingCount: data['pendingCount'] as int?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'type': type.firestoreValue,
      if (amountMinor != null) 'amountMinor': amountMinor,
      'timestamp': timestamp,
      if (paymentAttemptId != null) 'paymentAttemptId': paymentAttemptId,
      if (pendingCount != null) 'pendingCount': pendingCount,
    };
  }

  String get displayMessage {
    switch (type) {
      case SettlementEventType.cycleSettlementStarted:
        return 'Settlement started';
      case SettlementEventType.paymentInitiated:
        if (amountMinor != null) {
          return '${formatMoney(amountMinor!)} payment initiated';
        }
        return 'Payment initiated';
      case SettlementEventType.paymentPending:
        if (amountMinor != null) {
          return 'Payment pending: ${formatMoney(amountMinor!)}';
        }
        return 'Payment pending';
      case SettlementEventType.paymentConfirmedByPayer:
        return 'Payment confirmed';
      case SettlementEventType.paymentConfirmedByReceiver:
        return 'Payment received';
      case SettlementEventType.paymentFailed:
        return 'Payment failed';
      case SettlementEventType.paymentDisputed:
        return 'Payment disputed';
      case SettlementEventType.cashConfirmationRequested:
        if (amountMinor != null) {
          return 'Cash payment requested: ${formatMoney(amountMinor!)}';
        }
        return 'Cash payment requested';
      case SettlementEventType.cashConfirmed:
        if (amountMinor != null) {
          return 'Cash payment confirmed: ${formatMoney(amountMinor!)}';
        }
        return 'Cash payment confirmed';
      case SettlementEventType.cycleFullySettled:
        return 'Cycle fully settled';
      case SettlementEventType.cycleArchived:
        return 'Cycle closed';
      case SettlementEventType.pendingReminder:
        if (pendingCount != null && pendingCount! > 0) {
          return '$pendingCount member${pendingCount == 1 ? '' : 's'} still pending settlement';
        }
        return 'Settlement still pending';
    }
  }

  String get relativeTime {
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = now - timestamp;
    final seconds = diff ~/ 1000;
    final minutes = seconds ~/ 60;
    final hours = minutes ~/ 60;
    final days = hours ~/ 24;

    if (seconds < 60) return 'Just now';
    if (minutes < 60) return '${minutes}m ago';
    if (hours < 24) return '${hours}h ago';
    if (days < 7) return '${days}d ago';
    
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${_monthName(date.month)} ${date.day}';
  }

  static String _monthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}
