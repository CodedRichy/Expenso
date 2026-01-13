import 'package:flutter/material.dart';

class HistoryCycle {
  final String id;
  final String startDate;
  final String endDate;
  final double settledAmount;
  final int expenseCount;

  HistoryCycle({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.settledAmount,
    required this.expenseCount,
  });
}

class CycleHistory extends StatelessWidget {
  final String groupName;
  final List<HistoryCycle>? cycles;

  const CycleHistory({
    super.key,
    this.groupName = 'Weekend Trip',
    this.cycles,
  });

  @override
  Widget build(BuildContext context) {
    final defaultCycles = cycles ??
        [
          HistoryCycle(
            id: '1',
            startDate: 'Dec 1',
            endDate: 'Dec 7',
            settledAmount: 2800,
            expenseCount: 6,
          ),
          HistoryCycle(
            id: '2',
            startDate: 'Nov 24',
            endDate: 'Nov 30',
            settledAmount: 3240,
            expenseCount: 8,
          ),
          HistoryCycle(
            id: '3',
            startDate: 'Nov 17',
            endDate: 'Nov 23',
            settledAmount: 1950,
            expenseCount: 4,
          ),
        ];

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.chevron_left, size: 24),
                    color: const Color(0xFF1A1A1A),
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
                      color: const Color(0xFF1A1A1A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Settlement history',
                    style: TextStyle(
                      fontSize: 17,
                      color: const Color(0xFF6B6B6B),
                    ),
                  ),
                ],
              ),
            ),
            // Cycles List
            if (defaultCycles.isNotEmpty)
              Expanded(
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
                          color: const Color(0xFF9B9B9B),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: defaultCycles.length,
                        itemBuilder: (context, index) {
                          final cycle = defaultCycles[index];
                          return InkWell(
                            onTap: () {
                              Navigator.pushNamed(context, '/cycle-history-detail');
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              decoration: BoxDecoration(
                                border: Border(
                                  top: index > 0
                                      ? const BorderSide(color: Color(0xFFE5E5E5), width: 1)
                                      : BorderSide.none,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${cycle.startDate} – ${cycle.endDate}',
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w500,
                                            color: const Color(0xFF1A1A1A),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Text(
                                              '₹${cycle.settledAmount.toStringAsFixed(0).replaceAllMapped(
                                                RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                                                (Match m) => '${m[1]},',
                                              )}',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFF1A1A1A),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'settled · ${cycle.expenseCount} expense${cycle.expenseCount != 1 ? 's' : ''}',
                                              style: TextStyle(
                                                fontSize: 15,
                                                color: const Color(0xFF6B6B6B),
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
                                    color: const Color(0xFFB0B0B0),
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
              )
            else
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
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
                              color: const Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Settled cycles will appear here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: const Color(0xFF6B6B6B),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
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
