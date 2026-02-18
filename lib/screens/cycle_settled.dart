import 'package:flutter/material.dart';
import '../models/models.dart';

class CycleSettled extends StatelessWidget {
  const CycleSettled({super.key});

  @override
  Widget build(BuildContext context) {
    final group = ModalRoute.of(context)!.settings.arguments as Group;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                    group.name,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A1A1A),
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 96),
                  child: SizedBox(
                    width: 320,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'This cycle is settled',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1A1A1A),
                            letterSpacing: -0.9,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '₹${group.amount.toStringAsFixed(0).replaceAllMapped(
                            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                            (Match m) => '${m[1]},',
                          )} settled',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 17,
                            color: const Color(0xFF6B6B6B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'All balances cleared. The next cycle has begun.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: const Color(0xFF6B6B6B),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 48),
                        Column(
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pushNamedAndRemoveUntil(
                                  context,
                                  '/group-detail',
                                  (route) => route.isFirst,
                                  arguments: group,
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1A1A1A),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 0,
                                minimumSize: const Size(double.infinity, 0),
                              ),
                              child: Text(
                                'Continue',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: () {
                                Navigator.pushNamed(context, '/cycle-history', arguments: group);
                              },
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF1A1A1A),
                                side: const BorderSide(color: Color(0xFFE5E5E5)),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                minimumSize: const Size(double.infinity, 0),
                              ),
                              child: Text(
                                'View History',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
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
