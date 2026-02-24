import 'package:flutter/foundation.dart';
import '../models/models.dart';

class GlobalIdentity {
  final String phoneE164;
  final String displayName;
  final String? photoURL;
  final String? upiId;
  final Set<String> groupIds;
  final int lastUpdated;

  const GlobalIdentity({
    required this.phoneE164,
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
      phoneE164: phoneE164,
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
      phoneE164: phoneE164,
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

  static String normalizePhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.startsWith('+')) return digits;
    if (digits.length == 10) return '+91$digits';
    if (digits.length == 12 && digits.startsWith('91')) return '+$digits';
    return '+$digits';
  }

  GlobalIdentity? getIdentity(String phone) {
    final normalized = normalizePhone(phone);
    return _identities[normalized];
  }

  List<GlobalIdentity> get allIdentities => _identities.values.toList();

  Set<String> getGroupsForPhone(String phone) {
    return _identities[normalizePhone(phone)]?.groupIds ?? {};
  }

  void registerMember({
    required String phone,
    required String groupId,
    String displayName = '',
    String? photoURL,
    String? upiId,
    int? timestamp,
  }) {
    final normalized = normalizePhone(phone);
    if (normalized.length < 5) return;

    final now = timestamp ?? DateTime.now().millisecondsSinceEpoch;
    final incoming = GlobalIdentity(
      phoneE164: normalized,
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

  void registerFromMember(Member member, String groupId, {String? photoURL, String? upiId}) {
    if (member.phone.isEmpty) return;
    registerMember(
      phone: member.phone,
      groupId: groupId,
      displayName: member.name,
      photoURL: photoURL ?? member.photoURL,
      upiId: upiId,
    );
  }

  void updateIdentity({
    required String phone,
    String? displayName,
    String? photoURL,
    String? upiId,
  }) {
    final normalized = normalizePhone(phone);
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

  String getDisplayName(String phone) {
    final identity = getIdentity(phone);
    if (identity != null && identity.displayName.isNotEmpty) {
      return identity.displayName;
    }
    return _formatPhone(phone);
  }

  String? getPhotoURL(String phone) {
    return getIdentity(phone)?.photoURL;
  }

  String? getUpiId(String phone) {
    return getIdentity(phone)?.upiId;
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
          phone: member.phone,
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

  static String _formatPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.length == 10) {
      return '${digits.substring(0, 5)} ${digits.substring(5)}';
    }
    if (digits.length == 12 && digits.startsWith('91')) {
      return '+91 ${digits.substring(2, 7)} ${digits.substring(7)}';
    }
    return phone;
  }
}
