import 'package:flutter/material.dart';
import '../repositories/cycle_repository.dart';
import 'EmptyStates.dart';

class GroupsList extends StatelessWidget {
  const GroupsList({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = CycleRepository.instance;

    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final groups = repo.groups;
        return Scaffold(
          backgroundColor: const Color(0xFFF7F7F8),
          floatingActionButton: groups.isNotEmpty
              ? FloatingActionButton(
                  onPressed: () => Navigator.pushNamed(context, '/create-group'),
                  backgroundColor: const Color(0xFF1A1A1A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                  child: const Icon(Icons.add),
                )
              : null,
          body: groups.isEmpty
              ? EmptyStates(
                  type: 'no-groups',
                  wrapInScaffold: false,
                  onActionPressed: () => Navigator.pushNamed(context, '/create-group'),
                )
              : SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
                        child: Text(
                          'Groups',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1A1A1A),
                            letterSpacing: -0.6,
                          ),
                        ),
                      ),
                      // Groups List
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 88),
                    itemCount: groups.length,
                    itemBuilder: (context, index) {
                      final group = groups[index];
                      final isSettled = group.status == 'settled';
                      final isClosing = group.status == 'closing';

                      return InkWell(
                        onTap: () {
                          Navigator.pushNamed(
                            context,
                            '/group-detail',
                            arguments: group,
                          );
                        },
                        child: Opacity(
                          opacity: isSettled ? 0.5 : 1.0,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: isSettled ? 18 : 22,
                            ),
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                  color: const Color(0xFFE5E5E5),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        group.name,
                                        style: TextStyle(
                                          fontSize: 19,
                                          fontWeight: isClosing ? FontWeight.w600 : FontWeight.w500,
                                          color: const Color(0xFF1A1A1A),
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      if (!isSettled) ...[
                                        Row(
                                          children: [
                                            Text(
                                              '₹${repo.getGroupPendingAmount(group.id).toStringAsFixed(0).replaceAllMapped(
                                                RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                                                (Match m) => '${m[1]},',
                                              )}',
                                              style: TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.w600,
                                                color: const Color(0xFF1A1A1A),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'pending',
                                              style: TextStyle(
                                                fontSize: 15,
                                                color: const Color(0xFF6B6B6B),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          group.statusLine,
                                          style: TextStyle(
                                            fontSize: 15,
                                            color: isClosing ? const Color(0xFF1A1A1A) : const Color(0xFF6B6B6B),
                                            fontWeight: isClosing ? FontWeight.w500 : FontWeight.w400,
                                          ),
                                        ),
                                      ] else
                                        Text(
                                          'All balances cleared',
                                          style: TextStyle(
                                            fontSize: 15,
                                            color: const Color(0xFF9B9B9B),
                                          ),
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
                        ),
                      );
                    },
                  ),
                ),
                // Create Group Button
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: const Color(0xFFE5E5E5),
                        width: 1,
                      ),
                    ),
                  ),
                  child: TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/create-group');
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Create Group',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF5B7C99),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        },
      ),
    );
  }
}
