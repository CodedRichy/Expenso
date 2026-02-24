import 'package:flutter/material.dart';
import '../models/models.dart';
import '../models/cycle.dart';
import '../repositories/cycle_repository.dart';

class CycleHistory extends StatefulWidget {
  const CycleHistory({super.key});

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
    final group = ModalRoute.of(context)?.settings.arguments as Group?;
    if (group != null && _groupId != group.id) {
      _groupId = group.id;
      _loadHistory();
    }
  }

  void _loadHistory() {
    setState(() {
      _hasError = false;
      _historyFuture = CycleRepository.instance.getHistory(_groupId!).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          _hasError = true;
          return <Cycle>[];
        },
      ).catchError((e) {
        _hasError = true;
        return <Cycle>[];
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final group = ModalRoute.of(context)?.settings.arguments as Group?;
    if (group == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.maybePop(context));
      return const Scaffold(body: SizedBox.shrink());
    }
    final groupName = group.name;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.chevron_left, size: 24),
                    color: theme.colorScheme.onSurface,
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                    constraints: const BoxConstraints(),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(32, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    groupName,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Settlement history',
                    style: TextStyle(
                      fontSize: 17,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
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
                        child: SizedBox(
                          width: 280,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'No settlement history',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w500,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Settled cycles will appear here.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: theme.colorScheme.onSurfaceVariant,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
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
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                        child: Text(
                          'PAST CYCLES',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurfaceVariant,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: cycles.length,
                          itemBuilder: (context, index) {
                            final cycle = cycles[index];
                          final startDate = cycle.startDate ?? '–';
                          final endDate = cycle.endDate ?? '–';
                          final settledAmount = cycle.expenses.fold<double>(
                            0.0,
                            (sum, e) => sum + e.amount,
                          );
                          final expenseCount = cycle.expenses.length;
                          return InkWell(
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                '/cycle-history-detail',
                                arguments: {
                                  'cycle': cycle,
                                  'groupName': groupName,
                                },
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                border: Border(
                                  top: index > 0
                                      ? BorderSide(
                                          color: theme.dividerColor,
                                          width: 1,
                                        )
                                      : BorderSide.none,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '$startDate – $endDate',
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w500,
                                            color: theme.colorScheme.onSurface,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Text(
                                              '₹${settledAmount.toStringAsFixed(0).replaceAllMapped(
                                                RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                                                (Match m) => '${m[1]},',
                                              )}',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: theme.colorScheme.onSurface,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'settled · $expenseCount expense${expenseCount != 1 ? 's' : ''}',
                                              style: TextStyle(
                                                fontSize: 15,
                                                color: theme.colorScheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Icon(
                                    Icons.chevron_right,
                                    size: 20,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ],
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
    final theme = Theme.of(context);
    if (_timedOut) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.hourglass_empty, size: 48, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text(
                'Taking longer than expected',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface),
              ),
              const SizedBox(height: 8),
              Text(
                'Check your connection',
                style: TextStyle(fontSize: 15, color: theme.colorScheme.onSurfaceVariant),
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
            child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading history...',
            style: TextStyle(fontSize: 15, color: theme.colorScheme.onSurfaceVariant),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
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
                color: isDark ? theme.colorScheme.surfaceContainerHighest : const Color(0xFFE5E5E5),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.wifi_off, size: 28, color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Check your connection and try again',
              style: TextStyle(fontSize: 15, color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.onSurface,
                side: BorderSide(color: theme.dividerColor),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
