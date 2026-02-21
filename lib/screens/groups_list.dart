import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../models/models.dart';
import '../repositories/cycle_repository.dart';
import '../services/pinned_groups_service.dart';
import '../widgets/member_avatar.dart';
import 'empty_states.dart';
import 'group_list_skeleton.dart';

class GroupsList extends StatefulWidget {
  const GroupsList({super.key});

  @override
  State<GroupsList> createState() => _GroupsListState();
}

class _GroupsListState extends State<GroupsList> {
  static bool _dummyAdded = false;

  @override
  void initState() {
    super.initState();
    PinnedGroupsService.instance.load();
    // DEBUG: Add dummy invitation and group for testing (only once)
    if (!_dummyAdded) {
      _dummyAdded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        CycleRepository.instance.addDummyInvitation();
        CycleRepository.instance.addDummyGroup();
      });
    }
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

  Widget _buildInvitationCard(BuildContext context, GroupInvitation invitation, CycleRepository repo, int index) {
    final colors = [
      const Color(0xFF1A1A1A),
      const Color(0xFF3A3A3A),
      const Color(0xFF555555),
      const Color(0xFF6B6B6B),
    ];
    final bgColor = colors[index % colors.length];
    
    return GestureDetector(
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
          boxShadow: [
            BoxShadow(
              color: bgColor.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
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
  }

  void _showInvitationSheet(BuildContext context, GroupInvitation invitation, CycleRepository repo) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
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
                color: const Color(0xFFE5E5E5),
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
                  colors: [Color(0xFF1A1A1A), Color(0xFF6B6B6B)],
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
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.mail_outline_rounded,
                    size: 16,
                    color: const Color(0xFF6B6B6B),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Group invitation',
                    style: TextStyle(
                      fontSize: 13,
                      color: const Color(0xFF6B6B6B),
                    ),
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
                        border: Border.all(color: const Color(0xFFE5E5E5)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          'Decline',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF6B6B6B),
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
                            SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating),
                          );
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          'Join Group',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
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
    final repo = CycleRepository.instance;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Group'),
        content: Text(
          'Permanently delete "${group.name}" and all expense history?',
          style: const TextStyle(fontSize: 16, color: Color(0xFF6B6B6B)),
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
          backgroundColor: const Color(0xFFF7F7F8),
          floatingActionButton: !loading && groups.isNotEmpty
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
          body: loading
              ? SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(24, 40, 24, 32),
                        child: Text(
                          'Groups',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                            letterSpacing: -0.6,
                          ),
                        ),
                      ),
                      const Expanded(child: GroupListSkeleton()),
                    ],
                  ),
                )
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
                                  child: Text(
                                    'Groups',
                                    style: TextStyle(
                                      fontSize: 34,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1A1A1A),
                                      letterSpacing: -0.6,
                                    ),
                                  ),
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
                                        backgroundColor: const Color(0xFFE5A017),
                                        foregroundColor: Colors.white,
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
                                              backgroundColor: const Color(0xFFC62828),
                                              foregroundColor: Colors.white,
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
                                            if (isPinned)
                                              Padding(
                                                padding: const EdgeInsets.only(right: 8),
                                                child: Icon(Icons.push_pin, size: 18, color: const Color(0xFFE5A017)),
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
