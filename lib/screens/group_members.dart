import 'package:flutter/material.dart';
import '../models/models.dart';
import '../repositories/cycle_repository.dart';
import '../utils/route_args.dart';
import '../utils/settlement_engine.dart';
import '../widgets/member_avatar.dart';

class GroupMembers extends StatelessWidget {
  const GroupMembers({super.key});

  @override
  Widget build(BuildContext context) {
    final group = RouteArgs.getGroup(context);
    if (group == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.of(context).maybePop());
      return const Scaffold(body: SizedBox.shrink());
    }
    final repo = CycleRepository.instance;

    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final currentGroup = repo.getGroup(group.id);
        if (currentGroup == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          });
          return const Scaffold(
            backgroundColor: Color(0xFFF7F7F8),
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final listMembers = repo.getMembersForGroup(group.id);
        final activeCycle = repo.getActiveCycle(group.id);
        final netBalances = SettlementEngine.computeNetBalances(
          activeCycle.expenses,
          listMembers,
        );
        final currentUserId = repo.currentUserId;
        
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
                      const SizedBox(height: 4),
                      Text(
                        '${listMembers.length} member${listMembers.length != 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 17,
                          color: const Color(0xFF6B6B6B),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: listMembers.isEmpty
                      ? Center(
                          child: Text(
                            'No members yet',
                            style: TextStyle(
                              fontSize: 17,
                              color: const Color(0xFF6B6B6B),
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                                child: Text(
                                  'MEMBERS',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF9B9B9B),
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                              ...listMembers.asMap().entries.map((entry) {
                                final index = entry.key;
                                final member = entry.value;
                                final memberBalance = netBalances[member.id] ?? 0.0;
                                final isCurrentUser = member.id == currentUserId;
                                final isCreator = member.id == currentGroup.creatorId;
                                final canRemove = repo.isCreator(group.id, currentUserId) && 
                                    !isCreator && 
                                    !isCurrentUser;
                                
                                String balanceStatusText;
                                Color balanceStatusColor;
                                if (memberBalance.abs() < 0.01) {
                                  balanceStatusText = 'Settled up';
                                  balanceStatusColor = const Color(0xFF6B6B6B);
                                } else if (isCurrentUser) {
                                  if (memberBalance > 0) {
                                    balanceStatusText = 'You get back ₹${memberBalance.toStringAsFixed(0)}';
                                    balanceStatusColor = const Color(0xFF2E7D32);
                                  } else {
                                    balanceStatusText = 'You owe ₹${(-memberBalance).toStringAsFixed(0)}';
                                    balanceStatusColor = const Color(0xFFD32F2F);
                                  }
                                } else {
                                  if (memberBalance > 0) {
                                    balanceStatusText = 'You owe them ₹${memberBalance.toStringAsFixed(0)}';
                                    balanceStatusColor = const Color(0xFFD32F2F);
                                  } else {
                                    balanceStatusText = 'Owes you ₹${(-memberBalance).toStringAsFixed(0)}';
                                    balanceStatusColor = const Color(0xFF2E7D32);
                                  }
                                }
                                
                                return InkWell(
                                  onTap: canRemove ? () {
                                    if (memberBalance.abs() >= 0.01) {
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Cannot Remove Member'),
                                          content: const Text(
                                            'Cannot remove this member. Settle their outstanding debt before removing them from the group.',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx),
                                              child: const Text('OK'),
                                            ),
                                          ],
                                        ),
                                      );
                                      return;
                                    }
                                    Navigator.pushNamed(
                                      context,
                                      '/member-change',
                                      arguments: {
                                        'groupId': group.id,
                                        'groupName': group.name,
                                        'memberId': member.id,
                                        'memberPhone': member.phone,
                                        'action': 'remove',
                                      },
                                    );
                                  } : null,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 16,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        top: index > 0
                                            ? const BorderSide(
                                                color: Color(0xFFE5E5E5),
                                                width: 1,
                                              )
                                            : BorderSide.none,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        MemberAvatar(
                                          displayName: repo.getMemberDisplayName(member.phone),
                                          photoURL: repo.getMemberPhotoURL(member.id),
                                          size: 44,
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    repo.getMemberDisplayName(member.phone),
                                                    style: TextStyle(
                                                      fontSize: 17,
                                                      color: const Color(0xFF1A1A1A),
                                                    ),
                                                  ),
                                                  if (isCreator) ...[
                                                    const SizedBox(width: 6),
                                                    const Text('👑', style: TextStyle(fontSize: 16)),
                                                  ],
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                balanceStatusText,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: balanceStatusColor,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (canRemove)
                                          Icon(
                                            Icons.chevron_right,
                                            color: const Color(0xFF9B9B9B),
                                            size: 20,
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
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
}
