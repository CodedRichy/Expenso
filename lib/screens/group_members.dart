import 'package:flutter/material.dart';
import '../repositories/cycle_repository.dart';
import '../utils/route_args.dart';
import '../utils/settlement_engine.dart';
import '../widgets/expenso_loader.dart';
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

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
          return Scaffold(
            backgroundColor: theme.scaffoldBackgroundColor,
            body: const Center(child: ExpensoLoader()),
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
                        group.name,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${listMembers.length} member${listMembers.length != 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 17,
                          color: theme.colorScheme.onSurfaceVariant,
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
                              color: theme.colorScheme.onSurfaceVariant,
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
                                    color: theme.colorScheme.onSurfaceVariant,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                              ...listMembers.asMap().entries.map((entry) {
                                final index = entry.key;
                                final member = entry.value;
                                final memberBalance = netBalances[member.id] ?? 0.0;
                                final isCreator = member.id == currentGroup.creatorId;
                                final isPending = member.id.startsWith('p_');
                                final canRemove = repo.isCreator(group.id, currentUserId) && 
                                    !isCreator && 
                                    member.id != currentUserId;
                                
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
                                            ? BorderSide(
                                                color: theme.dividerColor,
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
                                                      color: isPending ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onSurface,
                                                    ),
                                                  ),
                                                  if (isCreator) ...[
                                                    const SizedBox(width: 6),
                                                    const Text('👑', style: TextStyle(fontSize: 16)),
                                                  ],
                                                  if (isPending) ...[
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: theme.dividerColor,
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        'Invited',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w500,
                                                          color: theme.colorScheme.onSurfaceVariant,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              if (member.name.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  member.phone,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: theme.colorScheme.onSurfaceVariant,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        if (canRemove)
                                          Icon(
                                            Icons.chevron_right,
                                            color: theme.colorScheme.onSurfaceVariant,
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
          floatingActionButton: FloatingActionButton(
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  '/invite-members',
                  arguments: currentGroup,
                );
              },
              backgroundColor: theme.colorScheme.primary,
              child: Icon(Icons.person_add, color: theme.colorScheme.onPrimary),
            ),
        );
      },
    );
  }
}
