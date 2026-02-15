import 'package:flutter/material.dart';
import '../models/models.dart';
import '../models/cycle.dart';
import '../repositories/cycle_repository.dart';
import 'empty_states.dart';

class GroupDetail extends StatelessWidget {
  final Group? group;

  const GroupDetail({
    super.key,
    this.group,
  });

  @override
  Widget build(BuildContext context) {
    final repo = CycleRepository.instance;
    final routeGroup = ModalRoute.of(context)?.settings.arguments as Group?;
    final resolvedGroup = routeGroup ?? group;
    if (resolvedGroup == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.maybePop(context));
      return const Scaffold(body: SizedBox.shrink());
    }
    final groupId = resolvedGroup.id;

    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final defaultGroup = repo.getGroup(groupId) ?? resolvedGroup;
        // Single lookup at start of builder; getActiveCycle may create a cycle if none exists.
        final activeCycle = repo.getActiveCycle(groupId);
        final expenses = repo.getExpenses(activeCycle.id);
        final pendingAmount = expenses.fold<double>(0.0, (sum, e) => sum + e.amount);
        final isPassive = activeCycle.status == CycleStatus.settling;
        final isClosing = activeCycle.status == CycleStatus.settling || defaultGroup.status == 'closing';
        final isSettled = activeCycle.status == CycleStatus.closed || defaultGroup.status == 'settled';
        final hasExpenses = expenses.isNotEmpty;

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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                      IconButton(
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            '/group-members',
                            arguments: defaultGroup,
                          );
                        },
                        icon: const Icon(Icons.people_outline, size: 24),
                        color: const Color(0xFF1A1A1A),
                        padding: EdgeInsets.zero,
                        alignment: Alignment.centerRight,
                        constraints: const BoxConstraints(),
                        style: IconButton.styleFrom(
                          minimumSize: const Size(32, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    defaultGroup.name,
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
            // Amount Summary
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
              child: !isSettled
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '₹${pendingAmount.toStringAsFixed(0).replaceAllMapped(
                            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                            (Match m) => '${m[1]},',
                          )}',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            color: isPassive ? const Color(0xFF9B9B9B) : const Color(0xFF1A1A1A),
                            letterSpacing: -0.5,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isPassive ? 'Cycle Settled - Pending Restart' : 'pending',
                          style: TextStyle(
                            fontSize: 15,
                            color: isPassive ? const Color(0xFF9B9B9B) : const Color(0xFF6B6B6B),
                          ),
                        ),
                        if (!isPassive) ...[
                          const SizedBox(height: 4),
                          Text(
                            defaultGroup.statusLine,
                            style: TextStyle(
                              fontSize: 15,
                              color: isClosing ? const Color(0xFF1A1A1A) : const Color(0xFF6B6B6B),
                              fontWeight: isClosing ? FontWeight.w500 : FontWeight.w400,
                            ),
                          ),
                        ],
                        if (repo.getGroupPendingAmount(groupId) > 0 || isPassive) ...[
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: () {
                              if (isPassive) {
                                repo.archiveAndRestart(groupId);
                              } else {
                                final isLeader = repo.isCreator(groupId, repo.currentUserId);
                                if (isLeader) {
                                  _showSettleConfirmDialog(context, repo, groupId);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Request sent to group leader.'),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1A1A1A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                              minimumSize: const Size(double.infinity, 0),
                            ),
                            child: Text(
                              isPassive ? 'Start New Cycle' : 'Settle now',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                '/settlement-confirmation',
                                arguments: defaultGroup,
                              );
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              'Pay via UPI',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF5B7C99),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ],
                    )
                  : Text(
                      'All balances cleared',
                      style: TextStyle(
                        fontSize: 17,
                        color: const Color(0xFF6B6B6B),
                      ),
                    ),
            ),
            // Recent Expenses
            if (hasExpenses)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                      child: Text(
                        'EXPENSE LOG',
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
                        itemCount: expenses.length,
                        itemBuilder: (context, index) {
                          final expense = expenses[index];
                          return InkWell(
                            onTap: isPassive
                                ? null
                                : () {
                                    Navigator.pushNamed(
                                      context,
                                      '/edit-expense',
                                      arguments: {
                                        'expenseId': expense.id,
                                        'groupId': defaultGroup.id,
                                      },
                                    );
                                  },
                            child: Container(
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
                                          () {
                                            final d = expense.description;
                                            final currentName = repo.currentUserName;
                                            if (expense.participantPhones.isEmpty) {
                                              final fallback = currentName.isNotEmpty ? currentName : 'Just you';
                                              final dLower = d.toLowerCase();
                                              if (dLower.contains(fallback.toLowerCase()) || dLower.contains('just you')) return d;
                                              return '$d — $fallback';
                                            }
                                            final names = expense.participantPhones
                                                .map((p) => repo.getMemberDisplayName(p))
                                                .toList();
                                            final dLower = d.toLowerCase();
                                            final notInDescription = names
                                                .where((name) => !dLower.contains(name.toLowerCase()))
                                                .toList();
                                            if (notInDescription.isEmpty) return d;
                                            return '$d — with ${notInDescription.join(', ')}';
                                          }(),
                                          style: TextStyle(
                                            fontSize: 17,
                                            color: const Color(0xFF1A1A1A),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          expense.date,
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
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              )
            else
              EmptyStates(type: 'no-expenses-new-cycle'),
            // Add Expense Input (hidden when passive - cycle is read-only)
            if (!isSettled && !isPassive)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: const Color(0xFFE5E5E5),
                      width: 1,
                    ),
                  ),
                ),
                child: GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/expense-input',
                      arguments: defaultGroup,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFE5E5E5)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Add expense',
                      style: TextStyle(
                        fontSize: 17,
                        color: const Color(0xFFB0B0B0),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
      },
    );
  }

  void _showSettleConfirmDialog(BuildContext context, CycleRepository repo, String groupId) {
    final instructions = repo.getSettlementInstructions(groupId);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Settle & Restart',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1A1A1A),
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                instructions.isEmpty ? 'No balances to settle.' : 'The following will close this cycle:',
                style: TextStyle(
                  fontSize: 15,
                  color: const Color(0xFF6B6B6B),
                ),
              ),
              if (instructions.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...instructions.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      s,
                      style: TextStyle(
                        fontSize: 15,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF5B7C99),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              repo.settleAndRestartCycle(groupId);
              Navigator.pop(ctx);
            },
            child: Text(
              'Confirm',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A1A1A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
