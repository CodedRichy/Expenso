import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/firestore_service.dart';
import '../services/user_profile_cache.dart';
import 'base_repository.dart';

/// Manages group-related data, including member profiles and invitations.
class GroupRepository extends BaseRepository {
  GroupRepository._();
  static final GroupRepository instance = GroupRepository._();

  final Map<String, Group> _groups = {};
  final Map<String, _GroupMeta> _groupMeta = {};
  final Map<String, Member> _membersById = {};
  final List<GroupInvitation> _pendingInvitations = [];
  bool _groupsLoading = true;
  bool _invitationsLoading = true;

  Map<String, Group> get groups => _groups;
  bool get groupsLoading => _groupsLoading;
  List<GroupInvitation> get pendingInvitations => _pendingInvitations;
  bool get invitationsLoading => _invitationsLoading;

  Group? getGroup(String groupId) => _groups[groupId];

  List<Member> getMembersForGroup(String groupId) {
    final group = _groups[groupId];
    if (group == null) return [];
    return group.memberIds
        .map((id) => _membersById[id])
        .whereType<Member>()
        .toList();
  }

  String getMemberDisplayNameById(String memberId) {
    return _membersById[memberId]?.name ?? 'Unknown';
  }

  // ... more methods to be moved ...
}

class _GroupMeta {
  final String activeCycleId;
  final String cycleStatus;
  final String settlementRhythm;
  final int settlementDay;

  _GroupMeta({
    required this.activeCycleId,
    required this.cycleStatus,
    required this.settlementRhythm,
    required this.settlementDay,
  });
}
