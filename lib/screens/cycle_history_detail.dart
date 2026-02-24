import 'package:flutter/material.dart';
import '../models/cycle.dart';
import '../utils/route_args.dart';

class CycleHistoryDetail extends StatelessWidget {
  const CycleHistoryDetail({super.key});

  @override
  Widget build(BuildContext context) {
    final args = RouteArgs.getMap(context);
    if (args == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.of(context).maybePop());
      return const Scaffold(body: SizedBox.shrink());
    }
    final cycleData = args['cycle'];
    final groupName = args['groupName'] as String?;
    if (cycleData is! Cycle || groupName == null || groupName.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.of(context).maybePop());
      return const Scaffold(body: SizedBox.shrink());
    }
    final cycle = cycleData;
    final startDate = cycle.startDate ?? '–';
    final endDate = cycle.endDate ?? '–';
    final cycleDate = '$startDate – $endDate';
    final settledAmount = cycle.expenses.fold<double>(0.0, (sum, e) => sum + e.amount);
    final listExpenses = cycle.expenses;

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
                    cycleDate,
                    style: TextStyle(
                      fontSize: 17,
                      color: const Color(0xFF6B6B6B),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: const Color(0xFFE5E5E5),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '₹${settledAmount.toStringAsFixed(0).replaceAllMapped(
                      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                      (Match m) => '${m[1]},',
                    )}',
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A1A1A),
                      letterSpacing: -0.9,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'settled',
                    style: TextStyle(
                      fontSize: 15,
                      color: const Color(0xFF6B6B6B),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                    child: Text(
                      'EXPENSES',
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
                      itemCount: listExpenses.length,
                      itemBuilder: (context, index) {
                        final expense = listExpenses[index];
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border(
                              top: index > 0
                                  ? const BorderSide(color: Color(0xFFE5E5E5), width: 1)
                                  : BorderSide.none,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      expense.description,
                                      style: TextStyle(
                                        fontSize: 17,
                                        color: const Color(0xFF1A1A1A),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      expense.displayDate,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: const Color(0xFF9B9B9B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                '₹${expense.amount.toStringAsFixed(0).replaceAllMapped(
                                  RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                                  (Match m) => '${m[1]},',
                                )}',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1A1A1A),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
