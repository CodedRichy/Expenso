import 'package:flutter/material.dart';
import '../repositories/cycle_repository.dart';

class MemberChange extends StatelessWidget {
  final String groupName;
  final String memberPhone;
  final String action; // 'leave' or 'remove'

  const MemberChange({
    super.key,
    this.groupName = '',
    this.memberPhone = '',
    this.action = 'leave',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final args = ModalRoute.of(context)?.settings.arguments;
    final String displayGroupId;
    final String displayGroupName;
    final String displayMemberId;
    final String displayMemberPhone;
    final String displayAction;
    if (args is Map<String, dynamic>) {
      displayGroupId = args['groupId'] as String? ?? '';
      displayGroupName = args['groupName'] as String? ?? groupName;
      displayMemberId = args['memberId'] as String? ?? '';
      displayMemberPhone = args['memberPhone'] as String? ?? memberPhone;
      displayAction = args['action'] as String? ?? action;
    } else {
      displayGroupId = '';
      displayGroupName = groupName;
      displayMemberId = '';
      displayMemberPhone = args is String ? args : memberPhone;
      displayAction = action;
    }
    
    final repo = CycleRepository.instance;
    final memberDisplayName = displayMemberId.isNotEmpty 
        ? repo.getMemberDisplayName(displayMemberPhone)
        : displayMemberPhone;
    
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
                    displayGroupName,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
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
                          displayAction == 'leave' ? 'Leave group' : 'Remove member',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          displayAction == 'leave'
                              ? 'You will be removed from this group'
                              : '$memberDisplayName will be removed from this group',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 17,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Changes apply from the next cycle. Current cycle balances remain unchanged.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 48),
                        Column(
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                if (displayGroupId.isNotEmpty && displayMemberId.isNotEmpty) {
                                  repo.removeMemberFromGroup(displayGroupId, displayMemberId);
                                }
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.error,
                                foregroundColor: theme.colorScheme.onError,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 0,
                                minimumSize: const Size(double.infinity, 0),
                              ),
                              child: Text(
                                'Remove',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              style: OutlinedButton.styleFrom(
                                backgroundColor: isDark ? theme.colorScheme.surfaceContainerHighest : Colors.white,
                                foregroundColor: theme.colorScheme.onSurface,
                                side: BorderSide(color: theme.dividerColor),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                minimumSize: const Size(double.infinity, 0),
                              ),
                              child: Text(
                                'Cancel',
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
