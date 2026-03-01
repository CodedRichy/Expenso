import 'package:flutter/material.dart';
import '../design/colors.dart';
import '../design/typography.dart';
import '../models/settlement_event.dart';
import '../repositories/cycle_repository.dart';

/// Activity card in old design; tap opens full list in a bottom sheet.
class SettlementActivityTapToExpand extends StatelessWidget {
  final String groupId;

  const SettlementActivityTapToExpand({super.key, required this.groupId});

  static const int _previewCount = 1;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SettlementEvent>>(
      stream: CycleRepository.instance.settlementEventsStream(groupId),
      builder: (context, snapshot) {
        final events = snapshot.data ?? [];
        if (events.isEmpty) return const SizedBox.shrink();

        final pendingCount = CycleRepository.instance.getPendingSettlementCount(groupId);
        final displayEvents = events.take(_previewCount).toList();

        return Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () {
              showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (ctx) => DraggableScrollableSheet(
                  initialChildSize: 0.5,
                  minChildSize: 0.25,
                  maxChildSize: 0.9,
                  builder: (ctx, scrollController) => Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Row(
                            children: [
                              Text(
                                'Activity',
                                style: context.listItemTitle.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const Spacer(),
                              if (pendingCount > 0) _PendingBadge(count: pendingCount),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: StreamBuilder<List<SettlementEvent>>(
                            stream: CycleRepository.instance.settlementEventsStream(groupId),
                            builder: (context, snapshot) {
                              final list = snapshot.data ?? [];
                              if (list.isEmpty) {
                                return const Center(child: Text('No activity yet'));
                              }
                              return ListView.separated(
                                controller: scrollController,
                                padding: const EdgeInsets.only(bottom: 24),
                                itemCount: list.length,
                                separatorBuilder: (_, index) => const Divider(height: 1, indent: 48),
                                itemBuilder: (context, index) => _EventRow(event: list[index]),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                    child: Row(
                      children: [
                        Icon(
                          Icons.history,
                          size: 18,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Activity',
                          style: context.listItemTitle.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                        if (pendingCount > 0) _PendingBadge(count: pendingCount),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.expand_less,
                          size: 20,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: displayEvents.length,
                    separatorBuilder: (_, index) => const Divider(height: 1, indent: 48),
                    itemBuilder: (context, index) => _EventRow(event: displayEvents[index]),
                  ),
                  if (events.length > _previewCount)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
                      child: Row(
                        children: [
                          const Spacer(),
                          Text(
                            'Tap to see all',
                            style: context.caption.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.expand_less,
                            size: 16,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

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
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.history,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Activity',
                      style: context.listItemTitle.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                separatorBuilder: (context, index) => const Divider(height: 1, indent: 48),
                itemBuilder: (context, index) {
                  return _EventRow(event: displayEvents[index]);
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

  const _EventRow({required this.event});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _EventIcon(type: event.type),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              event.displayMessage,
              style: context.bodyPrimary,
            ),
          ),
          Text(
            event.relativeTime,
            style: context.caption.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
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
      SettlementEventType.cycleSettlementStarted => (Icons.flag_outlined, context.colorAccent),
      SettlementEventType.paymentInitiated => (Icons.send_outlined, context.colorWarning),
      SettlementEventType.paymentPending => (Icons.hourglass_empty, context.colorWarning),
      SettlementEventType.paymentConfirmedByPayer => (Icons.check_circle_outline, context.colorAccent),
      SettlementEventType.paymentConfirmedByReceiver => (Icons.verified_outlined, context.colorSuccess),
      SettlementEventType.paymentFailed => (Icons.cancel_outlined, context.colorError),
      SettlementEventType.paymentDisputed => (Icons.error_outline, context.colorError),
      SettlementEventType.cashConfirmationRequested => (Icons.payments_outlined, context.colorWarning),
      SettlementEventType.cashConfirmed => (Icons.payments, context.colorSuccess),
      SettlementEventType.cycleFullySettled => (Icons.celebration_outlined, context.colorSuccess),
      SettlementEventType.cycleArchived => (Icons.inventory_2_outlined, context.colorTextSecondary),
      SettlementEventType.pendingReminder => (Icons.schedule, context.colorWarning),
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
        color: context.colorWarningBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$count pending',
        style: context.caption.copyWith(
          color: context.colorWarning,
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
            color: context.colorSurfaceVariant,
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
                      style: context.bodyPrimary,
                    ),
                    if (pendingCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '$pendingCount member${pendingCount == 1 ? '' : 's'} pending settlement',
                          style: context.caption.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                latestEvent.relativeTime,
                style: context.caption.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
