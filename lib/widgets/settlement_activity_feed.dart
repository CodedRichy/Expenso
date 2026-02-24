import 'package:flutter/material.dart';
import '../design/colors.dart';
import '../design/typography.dart';
import '../models/settlement_event.dart';
import '../repositories/cycle_repository.dart';

class SettlementActivityFeed extends StatelessWidget {
  final String groupId;
  final int maxItems;

  const SettlementActivityFeed({
    super.key,
    required this.groupId,
    this.maxItems = 10,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SettlementEvent>>(
      stream: CycleRepository.instance.settlementEventsStream(groupId),
      builder: (context, snapshot) {
        final events = snapshot.data ?? [];
        
        if (events.isEmpty) {
          return const SizedBox.shrink();
        }

        final displayEvents = events.take(maxItems).toList();
        final pendingCount = CycleRepository.instance.getPendingSettlementCount(groupId);

        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    const Icon(
                      Icons.history,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Activity',
                      style: AppTypography.listItemTitle.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    if (pendingCount > 0)
                      _PendingBadge(count: pendingCount),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: displayEvents.length,
                separatorBuilder: (_, __) => const Divider(height: 1, indent: 48),
                itemBuilder: (context, index) {
                  return _EventRow(event: displayEvents[index], groupId: groupId);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EventRow extends StatelessWidget {
  final SettlementEvent event;
  final String groupId;

  const _EventRow({required this.event, required this.groupId});

  String _getEnrichedMessage() {
    final repo = CycleRepository.instance;
    
    if (event.paymentAttemptId == null) {
      return event.displayMessage;
    }

    final attempts = repo.getPaymentAttempts(groupId);
    final attempt = attempts.where((a) => a.id == event.paymentAttemptId).firstOrNull;
    
    if (attempt == null) {
      return event.displayMessage;
    }

    final fromName = repo.getMemberDisplayNameById(attempt.fromMemberId);
    final toName = repo.getMemberDisplayNameById(attempt.toMemberId);
    final amount = '₹${(attempt.amountMinor / 100).toStringAsFixed(0)}';

    switch (event.type) {
      case SettlementEventType.paymentInitiated:
        return '$fromName initiated $amount to $toName';
      case SettlementEventType.paymentConfirmedByPayer:
        return '$fromName marked $amount as paid to $toName';
      case SettlementEventType.paymentConfirmedByReceiver:
        return '$toName confirmed receiving $amount from $fromName';
      case SettlementEventType.paymentDisputed:
        return '$toName disputed payment from $fromName';
      case SettlementEventType.cashConfirmationRequested:
        return '$fromName requested cash confirmation ($amount) from $toName';
      case SettlementEventType.cashConfirmed:
        return '$toName confirmed cash receipt ($amount) from $fromName';
      default:
        return event.displayMessage;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _EventIcon(type: event.type),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _getEnrichedMessage(),
              style: AppTypography.bodyPrimary,
            ),
          ),
          Text(
            event.relativeTime,
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventIcon extends StatelessWidget {
  final SettlementEventType type;

  const _EventIcon({required this.type});

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color) = switch (type) {
      SettlementEventType.cycleSettlementStarted => (Icons.flag_outlined, AppColors.accent),
      SettlementEventType.paymentInitiated => (Icons.send_outlined, AppColors.warning),
      SettlementEventType.paymentPending => (Icons.hourglass_empty, AppColors.warning),
      SettlementEventType.paymentConfirmedByPayer => (Icons.check_circle_outline, AppColors.accent),
      SettlementEventType.paymentConfirmedByReceiver => (Icons.verified_outlined, AppColors.success),
      SettlementEventType.paymentFailed => (Icons.cancel_outlined, AppColors.error),
      SettlementEventType.paymentDisputed => (Icons.error_outline, AppColors.error),
      SettlementEventType.cashConfirmationRequested => (Icons.payments_outlined, AppColors.warning),
      SettlementEventType.cashConfirmed => (Icons.payments, AppColors.success),
      SettlementEventType.cycleFullySettled => (Icons.celebration_outlined, AppColors.success),
      SettlementEventType.cycleArchived => (Icons.inventory_2_outlined, AppColors.textSecondary),
    };

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 16, color: color),
    );
  }
}

class _PendingBadge extends StatelessWidget {
  final int count;

  const _PendingBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.warningBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$count pending',
        style: AppTypography.caption.copyWith(
          color: AppColors.warning,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class SettlementActivitySummary extends StatelessWidget {
  final String groupId;

  const SettlementActivitySummary({super.key, required this.groupId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SettlementEvent>>(
      stream: CycleRepository.instance.settlementEventsStream(groupId),
      builder: (context, snapshot) {
        final events = snapshot.data ?? [];
        if (events.isEmpty) return const SizedBox.shrink();

        final latestEvent = events.first;
        final pendingCount = CycleRepository.instance.getPendingSettlementCount(groupId);

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              _EventIcon(type: latestEvent.type),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      latestEvent.displayMessage,
                      style: AppTypography.bodyPrimary,
                    ),
                    if (pendingCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '$pendingCount member${pendingCount == 1 ? '' : 's'} pending settlement',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                latestEvent.relativeTime,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
