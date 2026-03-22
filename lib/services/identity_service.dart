import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../utils/phone_utils.dart';

class GlobalIdentity {
  final String identifier;
  final String displayName;
  final String? photoURL;
  final String? upiId;
  final Set<String> groupIds;
  final int lastUpdated;

  const GlobalIdentity({
    required this.identifier,
    required this.displayName,
    this.photoURL,
    this.upiId,
    required this.groupIds,
    required this.lastUpdated,
  });

  GlobalIdentity copyWith({
    String? displayName,
    String? photoURL,
    String? upiId,
    Set<String>? groupIds,
    int? lastUpdated,
  }) {
    return GlobalIdentity(
      identifier: identifier,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      upiId: upiId ?? this.upiId,
      groupIds: groupIds ?? this.groupIds,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  GlobalIdentity merge(GlobalIdentity other) {
    final useOther = other.lastUpdated > lastUpdated;
    return GlobalIdentity(
      identifier: identifier,
      displayName: useOther && other.displayName.isNotEmpty
          ? other.displayName
          : (displayName.isNotEmpty ? displayName : other.displayName),
      photoURL: useOther && other.photoURL != null
          ? other.photoURL
          : (photoURL ?? other.photoURL),
      upiId: useOther && other.upiId != null
          ? other.upiId
          : (upiId ?? other.upiId),
      groupIds: {...groupIds, ...other.groupIds},
      lastUpdated: useOther ? other.lastUpdated : lastUpdated,
    );
  }
}

class IdentityService extends ChangeNotifier {
  IdentityService._internal();

  static final IdentityService _instance = IdentityService._internal();
  static IdentityService get instance => _instance;

  final Map<String, GlobalIdentity> _identities = {};

  static String normalizeIdentifier(String input) => PhoneUtils.formatE164(input);

  GlobalIdentity? getIdentity(String identifier) {
    final normalized = normalizeIdentifier(identifier);
    return _identities[normalized];
  }

  List<GlobalIdentity> get allIdentities => _identities.values.toList();

  Set<String> getGroupsForIdentifier(String identifier) {
    return _identities[normalizeIdentifier(identifier)]?.groupIds ?? {};
  }

  void registerMember({
    required String identifier,
    required String groupId,
    String displayName = '',
    String? photoURL,
    String? upiId,
    int? timestamp,
  }) {
    final normalized = normalizeIdentifier(identifier);
    if (normalized.length < 3) return;

    final now = timestamp ?? DateTime.now().millisecondsSinceEpoch;
    final incoming = GlobalIdentity(
      identifier: normalized,
      displayName: displayName,
      photoURL: photoURL,
      upiId: upiId,
      groupIds: {groupId},
      lastUpdated: now,
    );

    final existing = _identities[normalized];
    if (existing != null) {
      _identities[normalized] = existing.merge(incoming);
    } else {
      _identities[normalized] = incoming;
    }
  }

  void registerFromMember(
    Member member,
    String groupId, {
    String? photoURL,
    String? upiId,
  }) {
    final identifier = member.email ?? member.phone;
    if (identifier.isEmpty) return;
    registerMember(
      identifier: identifier,
      groupId: groupId,
      displayName: member.name,
      photoURL: photoURL ?? member.photoURL,
      upiId: upiId,
    );
  }

  void updateIdentity({
    required String identifier,
    String? displayName,
    String? photoURL,
    String? upiId,
  }) {
    final normalized = normalizeIdentifier(identifier);
    final existing = _identities[normalized];
    if (existing == null) return;

    _identities[normalized] = existing.copyWith(
      displayName: displayName,
      photoURL: photoURL,
      upiId: upiId,
      lastUpdated: DateTime.now().millisecondsSinceEpoch,
    );
    notifyListeners();
  }

  String getDisplayName(String identifier) {
    final identity = getIdentity(identifier);
    if (identity != null && identity.displayName.isNotEmpty) {
      return identity.displayName;
    }
    return _formatIdentifier(identifier);
  }

  String? getPhotoURL(String identifier) {
    return getIdentity(identifier)?.photoURL;
  }

  String? getUpiId(String identifier) {
    return getIdentity(identifier)?.upiId;
  }

  void buildFromGroups(
    List<Group> groups,
    Map<String, Member> membersById,
    Map<String, Map<String, dynamic>> userCache,
  ) {
    for (final group in groups) {
      for (final memberId in group.memberIds) {
        final member = membersById[memberId];
        if (member == null || member.phone.isEmpty) continue;

        final userData = userCache[memberId];
        registerMember(
          identifier: member.email ?? member.phone,
          groupId: group.id,
          displayName: member.name,
          photoURL: userData?['photoURL'] as String? ?? member.photoURL,
          upiId: userData?['upiId'] as String?,
        );
      }
    }
    notifyListeners();
  }

  void clear() {
    _identities.clear();
    notifyListeners();
  }

  int get identityCount => _identities.length;

  static String _formatIdentifier(String input) => 
    input.contains('@') ? input : PhoneUtils.formatDisplay(input);
}
