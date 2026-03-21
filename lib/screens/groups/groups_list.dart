import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../design/colors.dart';
import '../../design/spacing.dart';
import '../../design/typography.dart';
import '../../models/models.dart';
import '../../repositories/cycle_repository.dart';
import '../../services/connectivity_service.dart';
import '../../services/locale_service.dart';
import '../../services/pinned_groups_service.dart';
import '../../widgets/animated_number.dart';
import '../../widgets/gradient_scaffold.dart';
import '../../widgets/member_avatar.dart';
import '../../widgets/offline_banner.dart';
import '../../widgets/skeleton_placeholders.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/staggered_list_item.dart';
import '../../widgets/tap_scale.dart';
import '../../widgets/error_state_widget.dart';
import '../../utils/money_format.dart';
import '../../widgets/empty_state_widget.dart';

class GroupsList extends StatefulWidget {
  const GroupsList({super.key});

  @override
  State<GroupsList> createState() => _GroupsListState();
}

class _GroupsListState extends State<GroupsList> {
  bool _showSlowLoadingHint = false;
  bool _navigatingToError = false;

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

  Widget _buildInvitationCard(
    BuildContext context,
    GroupInvitation invitation,
    CycleRepository repo,
    int index,
  ) {
    final alreadyAnimated = _animatedInvitations.contains(invitation.groupId);
    if (!alreadyAnimated) {
      _animatedInvitations.add(invitation.groupId);
    }

    final card = TapScale(
      child: GestureDetector(
        onTap: () => _showInvitationSheet(context, invitation, repo),
        child: GlassCard(
          width: 160,
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.all(16),
          borderRadius: AppSpacing.radiusMedium,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: context.colorPrimary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.group_add, size: 16, color: context.colorPrimary),
                  ),
                  const Spacer(),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: context.colorPrimary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                invitation.groupName,
                style: context.labelLarge.copyWith(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'New Invitation',
                style: context.labelSmall.copyWith(color: context.colorTextSecondary),
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
        return Opacity(opacity: value, child: child);
      },
      child: card,
    );
  }

  void _showInvitationSheet(
    BuildContext context,
    GroupInvitation invitation,
    CycleRepository repo,
  ) {
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
                      colors: [
                        context.colorGradientStart,
                        context.colorGradientEnd,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      invitation.groupName.isNotEmpty
                          ? invitation.groupName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: Theme.of(ctx).brightness == Brightness.dark
                            ? ctx.colorPrimary
                            : ctx.colorSurface,
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
                  Icon(
                    Icons.mail_outline_rounded,
                    size: 16,
                    color: ctx.colorTextSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text('Group invitation', style: context.sectionLabel),
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
                              content: Text(
                                'Could not decline invitation. Check your connection and try again.',
                              ),
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
                          style: Theme.of(ctx).textTheme.labelLarge?.copyWith(
                            color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                          ),
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
                              content: Text(
                                'Could not join group. Check your connection and try again.',
                              ),
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
                          style: Theme.of(ctx).textTheme.labelLarge?.copyWith(
                            color: Theme.of(ctx).colorScheme.surface,
                          ),
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
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
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
          const SnackBar(
            content: Text('Group deleted'),
            behavior: SnackBarBehavior.floating,
          ),
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
          const SnackBar(
            content: Text('Group deleted'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not delete group. Check your connection and try again.',
            ),
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
        if (repo.streamError != null && !_navigatingToError) {
          _navigatingToError = true;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!context.mounted) return;
            CycleRepository.instance.clearStreamError();
            await Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => Scaffold(body: Center(child: ErrorStateWidget(type: 'network')))));
            if (mounted) setState(() => _navigatingToError = false);
          });
        }
        return GradientScaffold(
          floatingActionButton:
              !loading &&
                  (groups.isNotEmpty || repo.pendingInvitations.isNotEmpty)
              ? TapScale(
                  onTap: () => Navigator.pushNamed(context, '/create-group'),
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: context.colorPrimary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: context.colorPrimary.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 28),
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
                                children: [                                  Expanded(
                                    child: Text(
                                      'Groups',
                                      style: context.displayLarge.copyWith(fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  TapScale(
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
                            // ── Dashboard summary card ─────────────────────
                            if (groups.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                                child: _DashboardHeroCard(groups: groups, repo: repo),
                              ),
                            if (groups.isEmpty &&
                                repo.pendingInvitations.isEmpty)
                              Expanded(
                                child: EmptyStateWidget(
                                  type: 'no-groups',
                                  onActionPressed: () => Navigator.pushNamed(
                                    context,
                                    '/create-group',
                                  ),
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
                                    final isPinned = pinService.isPinned(
                                      group.id,
                                    );
                                    final isCreator = repo.isCurrentUserCreator(
                                      group.id,
                                    );

                                      return StaggeredListItem(
                                        index: index,
                                        child: Padding(
                                          padding: const EdgeInsets.only(bottom: 12, left: 20, right: 20),
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
                                                            content: Text('Max 3 pins allowed.'),
                                                            behavior: SnackBarBehavior.floating,
                                                          ),
                                                        );
                                                      }
                                                      return;
                                                    }
                                                    await pinService.togglePin(group.id);
                                                  },
                                                  backgroundColor: context.colorWarning,
                                                  foregroundColor: Colors.white,
                                                  icon: isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                                                  label: isPinned ? 'Unpin' : 'Pin',
                                                  borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                                                ),
                                              ],
                                            ),
                                            endActionPane: isCreator ? ActionPane(
                                              motion: const DrawerMotion(),
                                              extentRatio: 0.25,
                                              children: [
                                                SlidableAction(
                                                  onPressed: (_) {
                                                    HapticFeedback.lightImpact();
                                                    _confirmDeleteGroup(context, group);
                                                  },
                                                  backgroundColor: context.colorError,
                                                  foregroundColor: Colors.white,
                                                  icon: Icons.delete_outline,
                                                  label: 'Delete',
                                                  borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                                                ),
                                              ],
                                            ) : null,
                                            child: TapScale(
                                              onTap: () => Navigator.pushNamed(context, '/group-detail', arguments: group),
                                              child: GlassCard(
                                                padding: const EdgeInsets.all(20),
                                                borderRadius: AppSpacing.radiusMedium,
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Row(
                                                            children: [
                                                              if (isPinned) ...[
                                                                Icon(Icons.push_pin, size: 14, color: context.colorWarning),
                                                                const SizedBox(width: 6),
                                                              ],
                                                              Text(
                                                                group.name,
                                                                style: context.labelLarge.copyWith(fontWeight: FontWeight.w600),
                                                              ),
                                                            ],
                                                          ),
                                                          const SizedBox(height: 8),
                                                          if (!isSettled) ...[
                                                            Text(
                                                              formatMoneyFromMajor(
                                                                repo.getGroupPendingAmount(group.id),
                                                                group.currencyCode,
                                                                LocaleService.instance.localeCode,
                                                              ),
                                                              style: context.headingSmall.copyWith(fontWeight: FontWeight.w600),
                                                            ),
                                                            const SizedBox(height: 4),
                                                            Text(
                                                              group.statusLine,
                                                              style: context.labelMedium.copyWith(color: context.colorTextSecondary),
                                                            ),
                                                          ] else
                                                            Text(
                                                              'All settled',
                                                              style: context.labelMedium.copyWith(color: context.colorSuccess),
                                                            ),
                                                        ],
                                                      ),
                                                    ),
                                                    Icon(Icons.chevron_right, size: 20, color: context.colorTextTertiary),
                                                  ],
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
                AppSpacing.spaceXl, // 16
                AppSpacing.spaceXl, // 16  ← was 16, matches real right padding
                AppSpacing.space4xl, // 32
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
              padding: const EdgeInsets.only(
                bottom: AppSpacing.bottomNavClearance,
              ),
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

// ─────────────────────────────────────────────────────────────────────────────
// _DashboardHeroCard
//
// Shows a compact financial summary across all active groups:
//   - Net position headline (animated, colour-coded)
//   - Two breakdown pills: owed to you / you owe
//   - Group count + settled count
// ─────────────────────────────────────────────────────────────────────────────

class _DashboardHeroCard extends StatelessWidget {
  final List<Group> groups;
  final CycleRepository repo;

  const _DashboardHeroCard({required this.groups, required this.repo});

  // Aggregate balances across active (non-settled) groups.
  // Returns (totalOwedToMe, totalIOwe, primaryCurrency).
  (double, double, String) _computeBalances() {
    try {
      double owedToMe = 0;
      double iOwe = 0;
      final uid = repo.currentUserId;
      if (uid.isEmpty) return (0, 0, 'INR');
      String currency = 'INR';
      for (final g in groups) {
        if (g.status == 'settled') continue;
        currency = g.currencyCode;
        final bal = repo.getRemainingBalance(g.id, uid);
        if (!bal.isFinite) continue;
        if (bal > 0.005) {
          owedToMe += bal;
        } else if (bal < -0.005) {
          iOwe += bal.abs();
        }
      }
      return (owedToMe, iOwe, currency);
    } catch (e) {
      debugPrint('DashboardHeroCard._computeBalances error: $e');
      return (0, 0, 'INR');
    }
  }

  @override
  Widget build(BuildContext context) {
    final (owedToMe, iOwe, currency) = _computeBalances();
    final locale = LocaleService.instance.localeCode;
    final net = owedToMe - iOwe;
    final isPositive = net > 0.005;
    final isNegative = net < -0.005;
    final netColor = isPositive
        ? context.colorSuccess
        : isNegative
            ? context.colorWarning
            : context.colorTextSecondary;
    final settledCount = groups.where((g) => g.status == 'settled').length;
    final activeCount = groups.length - settledCount;

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      borderRadius: AppSpacing.radiusMedium,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label + group count
          Row(
            children: [
              Expanded(
                child: Text(
                  'Your Net Position',
                  style: context.labelMedium.copyWith(
                    color: context.colorTextSecondary,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: context.colorPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$activeCount active · $settledCount settled',
                  style: context.caption.copyWith(
                    color: context.colorPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Animated net headline
          AnimatedNumber(
            value: net.abs(),
            currencyCode: currency,
            locale: locale,
            duration: const Duration(milliseconds: 800),
            style: context.displayLarge.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -1.5,
              height: 1.05,
              color: netColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isPositive
                ? 'overall you are owed'
                : isNegative
                    ? 'overall you owe'
                    : 'all settled up',
            style: context.bodySecondary.copyWith(
              color: netColor.withValues(alpha: 0.75),
              fontWeight: FontWeight.w500,
            ),
          ),
          // Breakdown pills — only when there's mixed debt/credit
          if (owedToMe > 0.005 && iOwe > 0.005) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                _StatPill(
                  label: 'Owed to you',
                  amount: formatMoneyFromMajor(owedToMe, currency, locale),
                  color: context.colorSuccess,
                  icon: Icons.arrow_downward_rounded,
                ),
                const SizedBox(width: 10),
                _StatPill(
                  label: 'You owe',
                  amount: formatMoneyFromMajor(iOwe, currency, locale),
                  color: context.colorWarning,
                  icon: Icons.arrow_upward_rounded,
                ),
              ],
            ),
          ] else if (owedToMe > 0.005) ...[
            const SizedBox(height: 10),
            _StatPill(
              label: 'Owed to you',
              amount: formatMoneyFromMajor(owedToMe, currency, locale),
              color: context.colorSuccess,
              icon: Icons.arrow_downward_rounded,
            ),
          ] else if (iOwe > 0.005) ...[
            const SizedBox(height: 10),
            _StatPill(
              label: 'You owe',
              amount: formatMoneyFromMajor(iOwe, currency, locale),
              color: context.colorWarning,
              icon: Icons.arrow_upward_rounded,
            ),
          ],
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String amount;
  final Color color;
  final IconData icon;

  const _StatPill({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: context.caption.copyWith(
                  color: color.withValues(alpha: 0.85),
                  fontSize: 10,
                ),
              ),
              Text(
                amount,
                style: context.labelMedium.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
