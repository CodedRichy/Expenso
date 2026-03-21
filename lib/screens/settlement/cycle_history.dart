import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../design/colors.dart';
import '../../design/spacing.dart';
import '../../design/typography.dart';
import '../../models/models.dart';
import '../../repositories/cycle_repository.dart';
import '../../utils/money_format.dart';
import '../../utils/route_args.dart';
import '../../services/locale_service.dart';
import '../../widgets/gradient_scaffold.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/tap_scale.dart';
import '../../widgets/staggered_list_item.dart';

class CycleHistory extends StatefulWidget {
  final Group? group;

  const CycleHistory({super.key, this.group});

  @override
  State<CycleHistory> createState() => _CycleHistoryState();
}

class _CycleHistoryState extends State<CycleHistory> {
  late Future<List<Cycle>> _historyFuture;
  bool _hasError = false;
  String? _groupId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final group = widget.group ?? RouteArgs.getGroup(context);
    if (group != null && _groupId != group.id) {
      _groupId = group.id;
      _loadHistory();
    }
  }

  void _loadHistory() {
    setState(() {
      _hasError = false;
      _historyFuture = CycleRepository.instance
          .getHistory(_groupId!)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              _hasError = true;
              return <Cycle>[];
            },
          )
          .catchError((e) {
            _hasError = true;
            return <Cycle>[];
          });
    });
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group ?? RouteArgs.getGroup(context);
    if (group == null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => Navigator.maybePop(context),
      );
      return const Scaffold(body: SizedBox.shrink());
    }
    final groupName = group.name;
    final currencyCode = group.currencyCode;
    final locale = LocaleService.instance.localeCode;

    return GradientScaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              child: Row(
                children: [
                  TapScale(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.08),
                        ),
                      ),
                      child: const Icon(Icons.chevron_left, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          groupName,
                          style: context.headingMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Settlement history',
                          style: context.labelMedium.copyWith(
                            color: context.colorTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Content ─────────────────────────────────────────────────
            FutureBuilder<List<Cycle>>(
              future: _historyFuture,
              builder: (context, snapshot) {
                final cycles = snapshot.data ?? [];
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Expanded(
                    child: _BoundedLoadingState(
                      onTimeout: () {
                        if (mounted) setState(() => _hasError = true);
                      },
                    ),
                  );
                }
                if (_hasError && cycles.isEmpty) {
                  return Expanded(
                    child: _ErrorWithRetry(
                      message: 'Could not load history',
                      onRetry: _loadHistory,
                    ),
                  );
                }
                if (cycles.isEmpty) {
                  return Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 64,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.history_outlined,
                              size: 48,
                              color: context.colorTextTertiary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No settlement history',
                              textAlign: TextAlign.center,
                              style: context.headingSmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Settled cycles will appear here.',
                              textAlign: TextAlign.center,
                              style: context.bodySecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                return Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                        child: Text('PAST CYCLES', style: context.sectionLabel),
                      ),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                          itemCount: cycles.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final cycle = cycles[index];
                            final startDate = cycle.startDate ?? '–';
                            final endDate = cycle.endDate ?? '–';
                            final settledAmount = cycle.expenses.fold<double>(
                              0.0,
                              (sum, e) => sum + e.amount,
                            );
                            final expenseCount = cycle.expenses.length;

                            return StaggeredListItem(
                              index: index,
                              child: TapScale(
                                scaleDown: 0.98,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  Navigator.pushNamed(
                                    context,
                                    '/cycle-history-detail',
                                    arguments: {
                                      'cycle': cycle,
                                      'groupName': groupName,
                                      'currencyCode': currencyCode,
                                    },
                                  );
                                },
                                child: GlassCard(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 18,
                                    vertical: 16,
                                  ),
                                  borderRadius: AppSpacing.radiusSmall,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '$startDate – $endDate',
                                              style: context.listItemTitle,
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Text(
                                                  formatMoneyFromMajor(
                                                    settledAmount,
                                                    currencyCode,
                                                    locale,
                                                  ),
                                                  style:
                                                      context.bodyPrimary
                                                          .copyWith(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  '· $expenseCount expense${expenseCount != 1 ? 's' : ''}',
                                                  style: context.bodySecondary,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withValues(
                                            alpha: 0.1,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.check,
                                          size: 16,
                                          color: Colors.green.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BoundedLoadingState extends StatefulWidget {
  final VoidCallback? onTimeout;

  const _BoundedLoadingState({this.onTimeout});

  @override
  State<_BoundedLoadingState> createState() => _BoundedLoadingStateState();
}

class _BoundedLoadingStateState extends State<_BoundedLoadingState> {
  bool _timedOut = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted && !_timedOut) {
        setState(() => _timedOut = true);
        widget.onTimeout?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_timedOut) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.hourglass_empty,
                size: 48,
                color: context.colorTextTertiary,
              ),
              const SizedBox(height: 16),
              Text(
                'Taking longer than expected',
                style: context.headingSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Check your connection',
                style: context.bodySecondary,
              ),
            ],
          ),
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: context.colorPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading history...',
            style: context.bodySecondary,
          ),
        ],
      ),
    );
  }
}

class _ErrorWithRetry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorWithRetry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: context.colorBorder,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.wifi_off,
                size: 28,
                color: context.colorTextSecondary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: context.headingSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Check your connection and try again',
              style: context.bodySecondary,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TapScale(
              onTap: onRetry,
              child: GlassCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 12,
                ),
                borderRadius: AppSpacing.radiusMedium,
                child: Text(
                  'Try again',
                  style: context.labelMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
