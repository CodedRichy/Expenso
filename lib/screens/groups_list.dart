import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../design/colors.dart';
import '../design/typography.dart';
import '../models/models.dart';
import '../repositories/cycle_repository.dart';
import '../services/pinned_groups_service.dart';
import '../widgets/expenso_loader.dart';
import '../widgets/member_avatar.dart';
import 'empty_states.dart';

class GroupsList extends StatefulWidget {
  const GroupsList({super.key});

  @override
  State<GroupsList> createState() => _GroupsListState();
}

class _GroupsListState extends State<GroupsList> {
  @override
  void initState() {
    super.initState();
    PinnedGroupsService.instance.load();
  }

  Widget _buildInvitationsLoadingPlaceholder() {
    return SizedBox(
      height: 88,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 2,
        itemBuilder: (context, index) {
          return Container(
            width: 140,
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(16),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInvitationsSection(BuildContext context, CycleRepository repo) {
    final invitations = repo.pendingInvitations;
    return SizedBox(
      height: 88,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: invitations.length,
        itemBuilder: (context, index) {
          final invitation = invitations[index];
          return _buildInvitationCard(context, invitation, repo, index);
        },
      ),
    );
  }

  // Track which invitations have already animated
  static final Set<String> _animatedInvitations = {};

  Widget _buildInvitationCard(BuildContext context, GroupInvitation invitation, CycleRepository repo, int index) {
    final colors = [
      AppColors.gradientStart,
      AppColors.primaryVariant,
      AppColors.gradientMid,
      AppColors.gradientEnd,
    ];
    final bgColor = colors[index % colors.length];
    
    final alreadyAnimated = _animatedInvitations.contains(invitation.groupId);
    if (!alreadyAnimated) {
      _animatedInvitations.add(invitation.groupId);
    }
    
    final card = GestureDetector(
      onTap: () => _showInvitationSheet(context, invitation, repo),
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [bgColor, bgColor.withOpacity(0.8)],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -20,
              right: -20,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    invitation.groupName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.group_add_outlined,
                        size: 14,
                        color: Colors.white.withOpacity(0.7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Tap to view',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    
    if (alreadyAnimated) {
      return card;
    }
    
    return TweenAnimationBuilder<double>(
      key: ValueKey('anim_${invitation.groupId}'),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 200 + (index * 40)),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: child,
        );
      },
      child: card,
    );
  }

  void _showInvitationSheet(BuildContext context, GroupInvitation invitation, CycleRepository repo) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 12,
          bottom: 24 + MediaQuery.of(ctx).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.gradientStart, AppColors.gradientEnd],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  invitation.groupName.isNotEmpty ? invitation.groupName[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              invitation.groupName,
              style: AppTypography.subheader,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.mail_outline_rounded, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    'Group invitation',
                    style: AppTypography.sectionLabel.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      Navigator.pop(ctx);
                      try {
                        await repo.declineInvitation(invitation.groupId);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating),
                          );
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          'Decline',
                          style: AppTypography.button.copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      Navigator.pop(ctx);
                      try {
                        await repo.acceptInvitation(invitation.groupId);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Joined ${invitation.groupName}'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating),
                          );
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          'Join Group',
                          style: AppTypography.button.copyWith(color: AppColors.surface),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Sort groups: pinned first (in pin order), then unpinned in repo order.
  List<Group> _sortedGroups(List<Group> groups, List<String> pinnedIds) {
    final pinnedSet = pinnedIds.toSet();
    final pinned = <Group>[];
    for (final id in pinnedIds) {
      final match = groups.where((g) => g.id == id).toList();
      if (match.isNotEmpty) pinned.add(match.first);
    }
    final unpinned = groups.where((g) => !pinnedSet.contains(g.id)).toList();
    return [...pinned, ...unpinned];
  }

  Future<void> _confirmDeleteGroup(BuildContext context, Group group) async {
    final repo = CycleRepository.instance;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Group'),
        content: Text(
          'Permanently delete "${group.name}" and all expense history?',
          style: AppTypography.bodySecondary.copyWith(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final wasPinned = PinnedGroupsService.instance.isPinned(group.id);
    try {
      await repo.deleteGroup(group.id);
      if (context.mounted) {
        if (wasPinned) PinnedGroupsService.instance.togglePin(group.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group deleted'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = CycleRepository.instance;
    final pinService = PinnedGroupsService.instance;

    return ListenableBuilder(
      listenable: Listenable.merge([repo, pinService]),
      builder: (context, _) {
        final groups = _sortedGroups(repo.groups, pinService.pinnedIds);
        final loading = repo.groupsLoading && groups.isEmpty;
        if (repo.streamError != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            if (CycleRepository.instance.streamError == null) return;
            Navigator.of(context).pushNamed('/error-states', arguments: {'type': 'network'});
            CycleRepository.instance.clearStreamError();
          });
        }
        return Scaffold(
          backgroundColor: AppColors.background,
          floatingActionButton: !loading && groups.isNotEmpty
              ? FloatingActionButton(
                  onPressed: () => Navigator.pushNamed(context, '/create-group'),
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                  child: const Icon(Icons.add),
                )
              : null,
          body: loading
              ? const Center(child: ExpensoLoader())
              : groups.isEmpty
                  ? EmptyStates(
                      type: 'no-groups',
                      wrapInScaffold: false,
                      onActionPressed: () => Navigator.pushNamed(context, '/create-group'),
                    )
                  : SafeArea(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 40, 16, 32),
                            child: Row(
                              children: [
                                const Expanded(
                                  child: Text('Groups', style: AppTypography.heroTitle),
                                ),
                                GestureDetector(
                                  onTap: () => Navigator.pushNamed(context, '/profile'),
                                  child: MemberAvatar(
                                    displayName: repo.currentUserName.isEmpty ? 'You' : repo.currentUserName,
                                    photoURL: repo.currentUserPhotoURL,
                                    size: 40,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (repo.invitationsLoading) ...[
                            const SizedBox(height: 16),
                            _buildInvitationsLoadingPlaceholder(),
                            const SizedBox(height: 16),
                          ] else if (repo.pendingInvitations.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _buildInvitationsSection(context, repo),
                            const SizedBox(height: 16),
                          ],
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.only(bottom: 88),
                              itemCount: groups.length,
                              itemBuilder: (context, index) {
                                final group = groups[index];
                                final isSettled = group.status == 'settled';
                                final isClosing = group.status == 'closing';
                                final isPinned = pinService.isPinned(group.id);
                                final isCreator = repo.isCurrentUserCreator(group.id);

                                return Slidable(
                                  key: ValueKey(group.id),
                                  startActionPane: ActionPane(
                                    motion: const DrawerMotion(),
                                    extentRatio: 0.25,
                                    children: [
                                      SlidableAction(
                                        onPressed: (_) async {
                                          HapticFeedback.lightImpact();
                                          if (!isPinned && !pinService.canPinMore) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('You can pin up to 3 groups. Unpin one first.'),
                                                  behavior: SnackBarBehavior.floating,
                                                ),
                                              );
                                            }
                                            return;
                                          }
                                          await pinService.togglePin(group.id);
                                        },
                                        backgroundColor: AppColors.warning,
                                        foregroundColor: AppColors.surface,
                                        icon: isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                                        label: isPinned ? 'Unpin' : 'Pin',
                                      ),
                                    ],
                                  ),
                                  endActionPane: isCreator
                                      ? ActionPane(
                                          motion: const DrawerMotion(),
                                          extentRatio: 0.25,
                                          children: [
                                            SlidableAction(
                                              onPressed: (_) {
                                                HapticFeedback.lightImpact();
                                                _confirmDeleteGroup(context, group);
                                              },
                                              backgroundColor: AppColors.error,
                                              foregroundColor: AppColors.surface,
                                              icon: Icons.delete_outline,
                                              label: 'Delete',
                                            ),
                                          ],
                                        )
                                      : null,
                                  child: InkWell(
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
                                        decoration: const BoxDecoration(
                                          border: Border(
                                            top: BorderSide(color: AppColors.border, width: 1),
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
                                                    style: AppTypography.listItemTitle.copyWith(
                                                      fontWeight: isClosing ? FontWeight.w600 : FontWeight.w500,
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
                                                          style: AppTypography.amountSM,
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Text('pending', style: AppTypography.bodySecondary),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      group.statusLine,
                                                      style: AppTypography.bodySecondary.copyWith(
                                                        color: isClosing ? AppColors.textPrimary : AppColors.textSecondary,
                                                        fontWeight: isClosing ? FontWeight.w500 : FontWeight.w400,
                                                      ),
                                                    ),
                                                  ] else
                                                    Text(
                                                      'All balances cleared',
                                                      style: AppTypography.bodySecondary.copyWith(color: AppColors.textTertiary),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            if (isPinned)
                                              const Padding(
                                                padding: EdgeInsets.only(right: 8),
                                                child: Icon(Icons.push_pin, size: 18, color: AppColors.warning),
                                              ),
                                            const SizedBox(width: 16),
                                            const Icon(
                                              Icons.chevron_right,
                                              size: 20,
                                              color: AppColors.textDisabled,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
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
