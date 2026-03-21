import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../design/typography.dart';
import '../../design/colors.dart';
import '../../design/spacing.dart';
import '../../models/models.dart';
import '../../repositories/cycle_repository.dart';
import '../../services/connectivity_service.dart';
import '../../utils/route_args.dart';
import '../../services/locale_service.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/tap_scale.dart';
import '../../widgets/gradient_scaffold.dart';
import '../../widgets/member_avatar.dart';
import '../../widgets/skeleton_placeholders.dart';
import '../../widgets/staggered_list_item.dart';
import '../../services/firestore_service.dart';
import '../../utils/phone_utils.dart';
import '../../utils/money_format.dart';

// Show member removal confirmation dialog
Future<bool?> showMemberChangeDialog(
  BuildContext context, {
  required String groupId,
  required String groupName,
  required String memberId,
  required String memberPhone,
  required String action,
}) async {
  final repo = CycleRepository.instance;
  final memberDisplayName = memberId.isNotEmpty
      ? repo.getMemberDisplayName(memberPhone)
      : memberPhone;

  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: context.colorSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        action == 'leave' ? 'Leave group' : 'Remove member',
        style: context.subheader,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            action == 'leave'
                ? 'You will be removed from $groupName. You can leave anytime; any balance carries to the next cycle until settled.'
                : '$memberDisplayName will be removed from $groupName',
            style: context.bodyPrimary,
          ),
          const SizedBox(height: 12),
          Text(
            'Changes apply from the next cycle. Current cycle balances remain unchanged.',
            style: context.bodySecondary,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (groupId.isNotEmpty && memberId.isNotEmpty) {
              if (ConnectivityService.instance.isOffline) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Cannot remove member while offline'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                Navigator.pop(ctx, false);
                return;
              }
              repo.removeMemberFromGroup(groupId, memberId);
            }
            Navigator.pop(ctx, true);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(ctx).colorScheme.error,
            foregroundColor: Theme.of(ctx).colorScheme.onError,
          ),
          child: const Text('Remove'),
        ),
      ],
    ),
  );
}

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
          // Shimmer skeleton while group data loads
          return GradientScaffold(
            body: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: SkeletonShimmer(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(width: 180, height: 22, borderRadius: 6),
                          const SizedBox(height: 6),
                          SkeletonBox(width: 100, height: 14, borderRadius: 4),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: SkeletonShimmer(
                        child: Column(
                          children: List.generate(
                            6,
                            (i) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Container(
                                height: 72,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusMedium,
                                  ),
                                ),
                              ),
                            ),
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
        final listMembers = repo.getMembersForGroup(resolvedGroup.id);
        final currentUserId = repo.currentUserId;

        return GradientScaffold(
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header ──────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      TapScale(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context);
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.black.withValues(alpha: 0.08),
                            ),
                          ),
                          child: const Icon(Icons.chevron_left, size: 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              resolvedGroup.name,
                              style: context.headingMedium.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${listMembers.length} member${listMembers.length != 1 ? 's' : ''}',
                              style: context.labelMedium.copyWith(
                                color: context.colorTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Members list ─────────────────────────────────────────
                Expanded(
                  child: listMembers.isEmpty
                      ? Center(
                          child: Text(
                            'No members yet',
                            style: context.bodyPrimary.copyWith(
                              color: context.colorTextSecondary,
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'MEMBERS',
                                style: context.sectionLabel,
                              ),
                              const SizedBox(height: 12),
                              GlassCard(
                                padding: EdgeInsets.zero,
                                borderRadius: AppSpacing.radiusMedium,
                                child: Column(
                                  children: listMembers
                                      .asMap()
                                      .entries
                                      .map((entry) {
                                    final index = entry.key;
                                    final member = entry.value;
                                    final remainingBalance =
                                        repo.getRemainingBalance(
                                      currentGroup.id,
                                      member.id,
                                    );
                                    final isCreator =
                                        member.id == currentGroup.creatorId;
                                    final isPending =
                                        member.id.startsWith('p_');
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
                                        onTap: () {
                                          HapticFeedback.selectionClick();
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
                                            horizontal: 20,
                                            vertical: 14,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border(
                                              top: index > 0
                                                  ? BorderSide(
                                                      color: Colors.black
                                                          .withValues(
                                                            alpha: 0.06,
                                                          ),
                                                      width: 1,
                                                    )
                                                  : BorderSide.none,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              MemberAvatar(
                                                displayName:
                                                    repo.getMemberDisplayName(
                                                  member.phone,
                                                ),
                                                photoURL:
                                                    repo.getMemberPhotoURL(
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
                                                        Flexible(
                                                          child: Text(
                                                            repo.getMemberDisplayName(
                                                              member.phone,
                                                            ),
                                                            style: context
                                                                .listItemTitle
                                                                .copyWith(
                                                              color: isPending
                                                                  ? context
                                                                      .colorTextSecondary
                                                                  : context
                                                                      .colorTextPrimary,
                                                            ),
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                        if (isCreator) ...[
                                                          const SizedBox(
                                                            width: 6,
                                                          ),
                                                          const Text(
                                                            '👑',
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                            ),
                                                          ),
                                                        ],
                                                        if (isPending) ...[
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                          Container(
                                                            padding:
                                                                const EdgeInsets
                                                                    .symmetric(
                                                              horizontal: 8,
                                                              vertical: 2,
                                                            ),
                                                            decoration:
                                                                BoxDecoration(
                                                              color: context
                                                                  .colorBorder,
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                4,
                                                              ),
                                                            ),
                                                            child: Text(
                                                              'Invited',
                                                              style: context
                                                                  .caption
                                                                  .copyWith(
                                                                color: context
                                                                    .colorTextTertiary,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                    if (member
                                                        .name.isNotEmpty) ...[
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        member.phone,
                                                        style: context
                                                            .bodySecondary,
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                              // ── Balance pill + chevron ──
                                              _BalancePill(
                                                balance: remainingBalance,
                                                currencyCode:
                                                    currentGroup.currencyCode,
                                              ),
                                              const SizedBox(width: 4),
                                              Icon(
                                                Icons.chevron_right,
                                                color:
                                                    context.colorTextTertiary,
                                                size: 18,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
          floatingActionButton: TapScale(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pushNamed(
                context,
                '/invite-members',
                arguments: currentGroup,
              );
            },
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: context.colorPrimary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: context.colorPrimary.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(Icons.person_add, color: Colors.white, size: 22),
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
      final isAppCreator = member.id == '605oNyF1miUumLGMgEnaGGD0Lyh2';
      final isPending = member.id.startsWith('p_');
      return Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          24 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
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
                  color: (isDark ? Colors.white : Colors.black)
                      .withValues(alpha: 0.1),
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
                      color: (isDark ? Colors.white : Colors.black)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.08),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary
                              .withValues(alpha: 0.05),
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
                      PhoneUtils.formatDisplay(member.phone),
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.8),
                        letterSpacing: 0.5,
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
                        final showBeta = isBeta ||
                            member.id == '605oNyF1miUumLGMgEnaGGD0Lyh2';

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (joinedAt != null) ...[
                              Text(
                                'Member since ${DateFormat('MMM yyyy').format(DateTime.fromMillisecondsSinceEpoch(joinedAt))}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: theme.colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.6),
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
                    TapScale(
                      onTap: () {
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
                        showMemberChangeDialog(
                          context,
                          groupId: group.id,
                          groupName: group.name,
                          memberId: member.id,
                          memberPhone: member.phone,
                          action: 'remove',
                        );
                      },
                      child: SizedBox(
                        width: double.infinity,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.error
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.person_remove,
                                color: theme.colorScheme.error,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Remove from Group',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                ],
              ),
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

// ─────────────────────────────────────────────────────────────────────────────
// _BalancePill
// Shows a colour-coded pill for a member's net balance.
//   positive → green  (someone owes them money)
//   negative → amber  (they owe money)
//   zero     → hidden (fully settled)
// ─────────────────────────────────────────────────────────────────────────────

class _BalancePill extends StatelessWidget {
  final double balance;
  final String currencyCode;

  const _BalancePill({required this.balance, required this.currencyCode});

  @override
  Widget build(BuildContext context) {
    final abs = balance.abs();
    if (abs < 0.01) return const SizedBox.shrink();

    final isCredit = balance > 0;
    final color = isCredit ? context.colorSuccess : context.colorWarning;
    final label = formatMoneyFromMajor(
      abs,
      currencyCode,
      LocaleService.instance.localeCode,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        isCredit ? '+$label' : '-$label',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}
