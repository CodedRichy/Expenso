import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../design/typography.dart';
import '../../design/colors.dart';
import '../../design/spacing.dart';
import '../../models/models.dart';
import '../../repositories/cycle_repository.dart';
import '../../utils/route_args.dart';
import '../../widgets/expenso_loader.dart';
import '../../widgets/member_avatar.dart';
import '../../widgets/staggered_list_item.dart';
import '../../widgets/tap_scale.dart';
import '../../services/feature_flag_service.dart';
import '../../services/firestore_service.dart';

class GroupMembers extends StatelessWidget {
  final Group? group;

  const GroupMembers({super.key, this.group});

  @override
  Widget build(BuildContext context) {
    final resolvedGroup = group ?? RouteArgs.getGroup(context);
    if (resolvedGroup == null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => Navigator.of(context).maybePop(),
      );
      return const Scaffold(body: SizedBox.shrink());
    }
    final repo = CycleRepository.instance;

    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final currentGroup = repo.getGroup(resolvedGroup.id);
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
        final listMembers = repo.getMembersForGroup(resolvedGroup.id);
        final currentUserId = repo.currentUserId;

        return Scaffold(
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.screenPaddingH,
                    AppSpacing.screenHeaderPaddingTop,
                    AppSpacing.screenPaddingH,
                    AppSpacing.space3xl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TapScale(
                        child: IconButton(
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
                      ),
                      const SizedBox(height: 20),
                      Text(
                        resolvedGroup.name,
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
                                padding: const EdgeInsets.fromLTRB(
                                  24,
                                  16,
                                  24,
                                  16,
                                ),
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
                                final remainingBalance = repo
                                    .getRemainingBalance(
                                      currentGroup.id,
                                      member.id,
                                    );
                                final isCreator =
                                    member.id == currentGroup.creatorId;
                                final isPending = member.id.startsWith('p_');
                                final canRemove =
                                    repo.isCreator(
                                      currentGroup.id,
                                      currentUserId,
                                    ) &&
                                    !isCreator &&
                                    member.id != currentUserId;

                                return StaggeredListItem(
                                  index: index,
                                  child: TapScale(
                                    scaleDown: 0.99,
                                    child: InkWell(
                                      onTap: () {
                                        _showMemberProfileBottomSheet(
                                          context,
                                          currentGroup,
                                          member,
                                          canRemove,
                                          remainingBalance,
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
                                            MemberAvatar(
                                              displayName: repo
                                                  .getMemberDisplayName(
                                                    member.phone,
                                                  ),
                                              photoURL: repo.getMemberPhotoURL(
                                                member.id,
                                              ),
                                              size: 44,
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        repo.getMemberDisplayName(
                                                          member.phone,
                                                        ),
                                                        style: TextStyle(
                                                          fontSize: 17,
                                                          color: isPending
                                                              ? theme
                                                                    .colorScheme
                                                                    .onSurfaceVariant
                                                              : theme
                                                                    .colorScheme
                                                                    .onSurface,
                                                        ),
                                                      ),
                                                      if (isCreator) ...[
                                                        const SizedBox(
                                                          width: 6,
                                                        ),
                                                        const Text(
                                                          '👑',
                                                          style: TextStyle(
                                                            fontSize: 16,
                                                          ),
                                                        ),
                                                      ],
                                                      if (isPending) ...[
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 8,
                                                                vertical: 2,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: theme
                                                                .dividerColor,
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  4,
                                                                ),
                                                          ),
                                                          child: Text(
                                                            'Invited',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                              color: theme
                                                                  .colorScheme
                                                                  .onSurfaceVariant,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                  if (member
                                                      .name
                                                      .isNotEmpty) ...[
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      member.phone,
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: theme
                                                            .colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                            Icon(
                                              Icons.chevron_right,
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                              size: 20,
                                            ),
                                          ],
                                        ),
                                      ),
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
          floatingActionButton: TapScale(
            child: FloatingActionButton(
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  '/invite-members',
                  arguments: currentGroup,
                );
              },
              backgroundColor: context.colorPrimary,
              foregroundColor: context.colorSurface,
              child: const Icon(Icons.person_add),
            ),
          ),
        );
      },
    );
  }
}

void _showMemberProfileBottomSheet(
  BuildContext context,
  Group group,
  Member member,
  bool canRemove,
  double remainingBalance,
) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useRootNavigator: true,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final isDark = theme.brightness == Brightness.dark;
      final repo = CycleRepository.instance;
      final displayName = repo.getMemberDisplayName(member.phone);
      final photoURL = repo.getMemberPhotoURL(member.id);
      final isAppCreator = member.id == 'QoLVTOw3heVLRZZih5nEhdsL55T2';
      final isPending = member.id.startsWith('p_');
      return Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 24 + MediaQuery.of(ctx).viewInsets.bottom),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
                  width: 0.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.05),
                        blurRadius: 32,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: MemberAvatar(
                    displayName: displayName,
                    photoURL: photoURL,
                    size: 140,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  displayName,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                if (member.phone.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    _formatPhoneLabel(member.phone),
                    style: context.bodySecondary.copyWith(
                      letterSpacing: 0.5,
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                if (!isPending)
                  FutureBuilder<Map<String, dynamic>?>(
                    future: FirestoreService.instance.getUser(member.id),
                    builder: (context, snapshot) {
                      final data = snapshot.data;
                      final isBeta = data?['isBeta'] == true;
                      final joinedAt = data?['joinedAt'] as int?;
                      final showBeta = isBeta || member.id == 'QoLVTOw3heVLRZZih5nEhdsL55T2';

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (joinedAt != null) ...[
                            Text(
                              'Member since ${DateFormat('MMM yyyy').format(DateTime.fromMillisecondsSinceEpoch(joinedAt))}',
                              style: context.caption.copyWith(
                                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              if (isAppCreator)
                                _Badge(
                                  icon: Icons.workspace_premium,
                                  color: Colors.amber,
                                  label: 'App Creator',
                                  isDark: isDark,
                                ),
                              if (showBeta)
                                _Badge(
                                  icon: Icons.science_outlined,
                                  color: Colors.green,
                                  label: 'Beta Tester',
                                  isDark: isDark,
                                ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                if (canRemove) ...[
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (remainingBalance.abs() >= 0.01) {
                          Navigator.pop(ctx);
                          showDialog(
                            context: context,
                            builder: (alertCtx) => AlertDialog(
                              title: const Text('Cannot Remove Member'),
                              content: const Text(
                                'Cannot remove this member. Settle their outstanding debt before removing them from the group.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(alertCtx),
                                  child: const Text('OK'),
                                ),
                              ],
                            ),
                          );
                          return;
                        }
                        Navigator.pop(ctx);
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
                      },
                      icon: const Icon(Icons.person_remove),
                      label: const Text('Remove from Group'),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                        backgroundColor: theme.colorScheme.error.withValues(alpha: 0.1),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final bool isDark;

  const _Badge({
    required this.icon,
    required this.color,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.95),
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatPhoneLabel(String phone) {
  final clean = phone.replaceAll(RegExp(r'\D'), '');
  if (clean.length == 10) {
    return '+91 ${clean.substring(0, 5)} ${clean.substring(5)}';
  } else if (clean.length > 10) {
    // Assuming it starts with 91 or similar
    if (clean.startsWith('91')) {
      return '+91 ${clean.substring(2, 7)} ${clean.substring(7)}';
    }
  }
  return phone;
}
