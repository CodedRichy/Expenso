import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../models/models.dart';
import '../repositories/cycle_repository.dart';
import '../services/connectivity_service.dart';
import '../services/locale_service.dart';
import '../services/pinned_groups_service.dart';
import '../widgets/gradient_scaffold.dart';
import '../widgets/member_avatar.dart';
import '../widgets/offline_banner.dart';
import '../widgets/skeleton_placeholders.dart';
import '../widgets/staggered_list_item.dart';
import '../widgets/tap_scale.dart';
import '../utils/money_format.dart';
import 'empty_states.dart';

class GroupsList extends StatefulWidget {
  const GroupsList({super.key});

  @override
  State<GroupsList> createState() => _GroupsListState();
}

class _GroupsListState extends State<GroupsList> {
  bool _showSlowLoadingHint = false;

  @override
  void initState() {
    super.initState();
    PinnedGroupsService.instance.load();
    _startLoadingTimeout();
  }

  void _startLoadingTimeout() {
    Future.delayed(const Duration(seconds: 6), () {
      if (!mounted) return;
      final repo = CycleRepository.instance;
      if (repo.groupsLoading && repo.groups.isEmpty) {
        setState(() => _showSlowLoadingHint = true);
      }
    });
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
      context.colorGradientStart,
      context.colorPrimaryVariant,
      context.colorGradientMid,
      context.colorGradientEnd,
    ];
    final bgColor = colors[index % colors.length];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onDarkGradient = isDark ? context.colorPrimary : context.colorSurface;
    
    final alreadyAnimated = _animatedInvitations.contains(invitation.groupId);
    if (!alreadyAnimated) {
      _animatedInvitations.add(invitation.groupId);
    }
    
    final card = TapScale(
      child: GestureDetector(
        onTap: () => _showInvitationSheet(context, invitation, repo),
        child: Container(
          width: 140,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [bgColor, bgColor.withValues(alpha: 0.8)],
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
                    color: onDarkGradient.withValues(alpha: 0.1),
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
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: onDarkGradient,
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
                          color: onDarkGradient.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Tap to view',
                          style: TextStyle(
                            fontSize: 11,
                            color: onDarkGradient.withValues(alpha: 0.7),
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
        decoration: BoxDecoration(
          color: ctx.colorSurface,
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
                color: ctx.colorBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Builder(
              builder: (context) {
                return Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [context.colorGradientStart, context.colorGradientEnd],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      invitation.groupName.isNotEmpty ? invitation.groupName[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: Theme.of(ctx).brightness == Brightness.dark ? ctx.colorPrimary : ctx.colorSurface,
                        fontSize: 32,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Text(
              invitation.groupName,
              style: context.subheader,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: ctx.colorBackground,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.mail_outline_rounded, size: 16, color: ctx.colorTextSecondary),
                  const SizedBox(width: 6),
                  Text(
                    'Group invitation',
                    style: context.sectionLabel,
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
                            SnackBar(
                              content: Text('Could not decline invitation. Check your connection and try again.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: ctx.colorBorder),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          'Decline',
                          style: Theme.of(ctx).textTheme.labelLarge?.copyWith(color: Theme.of(ctx).colorScheme.onSurfaceVariant),
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
                            SnackBar(
                              content: Text('Could not join group. Check your connection and try again.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: ctx.colorPrimary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          'Join Group',
                          style: Theme.of(ctx).textTheme.labelLarge?.copyWith(color: Theme.of(ctx).colorScheme.surface),
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
    if (ConnectivityService.instance.isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete group while offline'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final repo = CycleRepository.instance;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Group'),
        content: Text(
          'Permanently delete "${group.name}" and all expense history?',
          style: context.bodySecondary.copyWith(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
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
      if (!context.mounted) return;
      // Post-condition check: if the group is no longer in the list, deletion
      // actually succeeded — the Firestore stream already removed it, or the
      // repository confirmed idempotent removal. Show success, not an error.
      final groupStillExists = repo.getGroup(group.id) != null;
      if (!groupStillExists) {
        if (wasPinned) PinnedGroupsService.instance.togglePin(group.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group deleted'), behavior: SnackBarBehavior.floating),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not delete group. Check your connection and try again.'),
            behavior: SnackBarBehavior.floating,
          ),
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
        return GradientScaffold(
          floatingActionButton: !loading && (groups.isNotEmpty || repo.pendingInvitations.isNotEmpty)
              ? Semantics(
                  label: 'Create new group',
                  button: true,
                  child: TapScale(
                    child: FloatingActionButton(
                  onPressed: () => Navigator.pushNamed(context, '/create-group'),
                  backgroundColor: context.colorPrimary,
                  foregroundColor: context.colorSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                  child: const Icon(Icons.add),
                ),
                  ),
              )
              : null,
          body: Column(
            children: [
              OfflineBanner(
                onRetry: () {
                  ConnectivityService.instance.checkNow();
                  CycleRepository.instance.restartListening();
                },
              ),
              Expanded(
                child: loading
                    ? _BoundedGroupsLoading(showSlowHint: _showSlowLoadingHint)
                    : SafeArea(
                        bottom: false,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                AppSpacing.screenPaddingH,
                                AppSpacing.spaceXl,
                                AppSpacing.spaceXl,
                                AppSpacing.space4xl,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text('Groups', style: context.heroTitle),
                                  ),
                                  TapScale(
                                    child: GestureDetector(
                                      onTap: () => Navigator.pushNamed(context, '/profile'),
                                      child: MemberAvatar(
                                        displayName: repo.currentUserName.isEmpty ? 'You' : repo.currentUserName,
                                        photoURL: repo.currentUserPhotoURL,
                                        size: 40,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (groups.isEmpty && repo.pendingInvitations.isEmpty)
                              Expanded(
                                child: EmptyStates(
                                  type: 'no-groups',
                                  wrapInScaffold: false,
                                  onActionPressed: () => Navigator.pushNamed(context, '/create-group'),
                                ),
                              )
                            else ...[
                              if (repo.pendingInvitations.isNotEmpty) ...[
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

                                return StaggeredListItem(
                                  index: index,
                                  child: Slidable(
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
                                        backgroundColor: context.colorWarning,
                                        foregroundColor: context.colorSurface,
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
                                              backgroundColor: context.colorError,
                                              foregroundColor: context.colorSurface,
                                              icon: Icons.delete_outline,
                                              label: 'Delete',
                                            ),
                                          ],
                                        )
                                      : null,
                                  child: TapScale(
                                    scaleDown: 0.99,
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
                                          decoration: BoxDecoration(
                                            border: Border(
                                              top: BorderSide(color: context.colorBorder, width: 1),
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
                                                      style: context.listItemTitle.copyWith(
                                                        fontWeight: isClosing ? FontWeight.w600 : FontWeight.w500,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    if (!isSettled) ...[
                                                      Row(
                                                        children: [
                                                          Text(
                                                            formatMoneyFromMajor(repo.getGroupPendingAmount(group.id), group.currencyCode, LocaleService.instance.localeCode),
                                                            style: context.amountSM.copyWith(
                                                              color: Theme.of(context).colorScheme.onSurface,
                                                            ),
                                                          ),
                                                          const SizedBox(width: 8),
                                                          Text('in cycle', style: context.bodySecondary),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 6),
                                                      Text(
                                                        group.statusLine,
                                                        style: context.bodySecondary.copyWith(
                                                          color: isClosing ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurfaceVariant,
                                                          fontWeight: isClosing ? FontWeight.w500 : FontWeight.w400,
                                                        ),
                                                      ),
                                                    ] else
                                                      Text(
                                                        'All balances cleared',
                                                        style: context.bodySecondary.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              if (isPinned)
                                                Padding(
                                                  padding: const EdgeInsets.only(right: 8),
                                                  child: Icon(Icons.push_pin, size: 18, color: context.colorWarning),
                                                ),
                                              const SizedBox(width: 16),
                                              Icon(
                                                Icons.chevron_right,
                                                size: 20,
                                                color: context.colorTextDisabled,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                );
                              },
                            ),
                          ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
      },
    );
  }
}

class _BoundedGroupsLoading extends StatelessWidget {
  final bool showSlowHint;

  const _BoundedGroupsLoading({this.showSlowHint = false});

  @override
  Widget build(BuildContext context) {
    // Header measurements must match the real GroupsList header exactly:
    //   padding: fromLTRB(screenPaddingH=24, spaceXl=16, spaceXl=16, space4xl=32)
    //   title: heroTitle ≈ fontSize 34, height ~40px
    //   avatar: size 40, circle
    // Any deviation here causes a layout shift the moment real data arrives.
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header skeleton (matches real GroupsList header 1:1) ──────────
          SkeletonShimmer(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPaddingH, // 24
                AppSpacing.spaceXl,        // 16
                AppSpacing.spaceXl,        // 16  ← was 16, matches real right padding
                AppSpacing.space4xl,       // 32
              ),
              child: Row(
                children: [
                  // "Groups" title: heroTitle is 34px, line-height ~40px
                  Expanded(
                    child: SkeletonBox(width: 120, height: 34, borderRadius: 6),
                  ),
                  // Avatar: 40px circle, matches MemberAvatar(size:40)
                  const SkeletonCircle(size: 40),
                ],
              ),
            ),
          ),
          // ── Slow hint banner (inline, never replaces chrome) ─────────────
          // Rendered between header and cards so the skeleton structure is
          // unchanged. Fades in only after showSlowHint = true (≥5s elapsed).
          if (showSlowHint)
            AnimatedOpacity(
              opacity: showSlowHint ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPaddingH,
                  0,
                  AppSpacing.screenPaddingH,
                  AppSpacing.spaceLg,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.wifi_off_outlined,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Taking longer than expected — check your connection',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        ConnectivityService.instance.checkNow();
                        CycleRepository.instance.restartListening();
                      },
                      child: Text(
                        'Retry',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // ── Card skeletons (viewport-filling, bottom-padded for FAB) ─────
          // bottom: 88 = bottomNavClearance, matches the FAB clearance in the
          // real list (ListView padding: EdgeInsets.only(bottom: 88)).
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: AppSpacing.bottomNavClearance),
              physics: const NeverScrollableScrollPhysics(),
              children: const [
                SkeletonGroupCard(),
                SkeletonGroupCard(),
                SkeletonGroupCard(),
                SkeletonGroupCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

