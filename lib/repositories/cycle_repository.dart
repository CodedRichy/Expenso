import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/models.dart';
import '../services/data_encryption_service.dart';
import '../services/supabase_service.dart';
import '../utils/money_format.dart';
import '../services/user_profile_cache.dart';
import '../utils/expense_revision.dart';
import '../utils/expense_validation.dart';
import '../utils/settlement_engine.dart';
import '../services/feature_flag_service.dart';
import '../utils/app_logger.dart';
import './auth_repository.dart';
import './group_repository.dart';
import './settlement_repository.dart';
import './base_repository.dart';

class CycleRepository extends BaseRepository {
  CycleRepository._();
  static final CycleRepository _instance = CycleRepository._();
  static CycleRepository get instance => _instance;

  AuthRepository get _auth => AuthRepository.instance;
  GroupRepository get _groupsRepo => GroupRepository.instance;
  SettlementRepository get _settlementRepo => SettlementRepository.instance;

  String _currentUserId = '';
  String _currentUserPhone = '';
  String _currentUserName = '';
  final Map<String, Map<String, dynamic>> _userCache = {};
  bool _groupsLoading = false;
  final List<GroupInvitation> _pendingInvitations = [];
  Map<String, String>? pendingInvitation; // For storing invite link while signed out
  String? _streamError;
  StreamSubscription? _groupsSub;
  StreamSubscription? _invitationsSub;
  final List<Group> _groups = [];
  final Map<String, Member> _membersById = {};
  final Map<String, StreamSubscription> _paymentAttemptSubs = {};
  final Map<String, String> _paymentAttemptCycleId = {};
  final Map<String, _GroupMeta> _groupMeta = {};
  final Map<String, List<Expense>> _expensesByCycleId = {};
  final Map<String, List<SystemMessage>> _systemMessagesByGroup = {};
  final Map<String, StreamSubscription> _expenseSubs = {};
  final Map<String, StreamSubscription> _systemMessageSubs = {};
  final Map<String, List<ExpenseRevision>> _revisionsByGroup = {};
  final Map<String, StreamSubscription> _revisionSubs = {};
  final Map<String, Set<String>> _deletedIdsByGroup = {};
  final Map<String, StreamSubscription> _deletedIdsSubs = {};
  final Map<String, List<PaymentAttempt>> _paymentAttemptsByGroup = {};

  String get currentUserId => _auth.currentUserId;
  String get currentUserPhone => _auth.currentUserPhone;
  String get currentUserName => _auth.currentUserName;
  String? get currentUserPhotoURL => _auth.currentUserPhotoURL;
  String? get currentUserUpiId => _auth.currentUserUpiId;
  String get currentUserCurrencyCode => _auth.currentUserCurrencyCode;

  bool isCurrentUserCreator(String groupId) =>
      isCreator(groupId, currentUserId);

  static int _dateStringToSortKey(String date) {
    final timestamp = int.tryParse(date);
    if (timestamp != null) return timestamp;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (date) {
      case 'Today':
        return today.millisecondsSinceEpoch;
      case 'Yesterday':
        return today.subtract(const Duration(days: 1)).millisecondsSinceEpoch;
      default:
        final parsed = DateTime.tryParse(date);
        if (parsed != null) return parsed.millisecondsSinceEpoch;
        final match = RegExp(r'(\w+)\s+(\d+)').firstMatch(date);
        if (match != null) {
          const months = [
            'Jan',
            'Feb',
            'Mar',
            'Apr',
            'May',
            'Jun',
            'Jul',
            'Aug',
            'Sep',
            'Oct',
            'Nov',
            'Dec',
          ];
          final monthName = match.group(1)!;
          final day = int.tryParse(match.group(2)!);
          final month = months.indexOf(monthName) + 1;
          if (month >= 1 &&
              month <= 12 &&
              day != null &&
              day >= 1 &&
              day <= 31) {
            var d = DateTime(now.year, month, day);
            if (d.isAfter(today.add(const Duration(days: 1)))) {
              d = DateTime(now.year - 1, month, day);
            }
            return d.millisecondsSinceEpoch;
          }
        }
        return today.millisecondsSinceEpoch;
    }
  }


  /// Updates the global profile (phone, name, and optionally auth user id and currency). Notifies listeners.
  /// Persists to Firestore and local cache when [_currentUserId] is set.
  void setGlobalProfile(
    String phone,
    String name, {
    String? authUserId,
    String? currencyCode,
  }) {
    _currentUserPhone = phone;
    _currentUserName = name.trim();
    if (authUserId != null && authUserId.isNotEmpty) {
      _currentUserId = authUserId;
    }
    if (_currentUserId.isNotEmpty) {
      if (currencyCode != null && currencyCode.isNotEmpty) {
        _userCache[_currentUserId] ??= <String, dynamic>{};
        _userCache[_currentUserId]!['currencyCode'] = currencyCode;
      }
      _writeCurrentUserProfile().catchError((e, st) {
        AppLogger.error('setGlobalProfile write failed', name: 'CycleRepository', error: e, stackTrace: st);
      });
      // Update local cache for instant load on next cold start
      UserProfileCache.instance.save(
        userId: _currentUserId,
        displayName: _currentUserName,
        photoURL: currentUserPhotoURL,
        upiId: currentUserUpiId,
        phone: _currentUserPhone,
        currencyCode: currentUserCurrencyCode,
      );
    }
    notifyListeners();
  }

  /// Load user profile from local cache (instant, before Firestore).
  /// Call once at app start after UserProfileCache.load() completes.
  /// Sets _groupsLoading = true when a userId is cached so that GroupsList shows
  /// skeleton immediately instead of the empty state before the first Firestore snapshot.
  void loadFromLocalCache() {
    final cached = UserProfileCache.instance.getCachedProfile();
    if (cached == null) return;
    _currentUserId = cached.userId;
    _currentUserName = cached.displayName;
    _currentUserPhone = cached.phone;
    _userCache[cached.userId] = {
      'displayName': cached.displayName,
      'phoneNumber': cached.phone,
      if (cached.photoURL != null) 'photoURL': cached.photoURL,
      if (cached.upiId != null) 'upiId': cached.upiId,
      if (cached.currencyCode != null) 'currencyCode': cached.currencyCode,
    };
    // A cached profile means the user is (or was) authenticated — pre-arm the
    // loading flag so GroupsList shows skeleton, not the empty/Create Group screen,
    // during the addPostFrameCallback window before _startListening fires.
    _groupsLoading = true;
    FeatureFlagService.instance.refresh();
  }

  /// Sets in-memory identity from Firebase user. Call during build; does not notify.
  /// Use _continueAuthFromFirebaseUser() after the frame for Firestore write/listen.
  void setAuthFromFirebaseUserSync(
    String uid,
    String? phone,
    String? displayName, {
    String? photoURL,
  }) {
    if (uid.isNotEmpty) _currentUserId = uid;
    if (phone != null && phone.isNotEmpty) _currentUserPhone = phone;
    if (displayName != null && displayName.isNotEmpty) {
      _currentUserName = displayName.trim();
    }
    final cached = UserProfileCache.instance.getCachedProfile();
    final usePhoto =
        (cached != null &&
            cached.userId == uid &&
            cached.photoURL != null &&
            cached.photoURL!.isNotEmpty)
        ? cached.photoURL!
        : (photoURL != null && photoURL.isNotEmpty ? photoURL : null);
    _userCache[uid] = {
      'displayName': _currentUserName,
      'phoneNumber': _currentUserPhone,
      if (usePhoto != null) 'photoURL': usePhoto,
    };
    if (cached != null && cached.userId == uid) {
      final cur = _userCache[uid]!;
      if (cached.upiId != null && cur['upiId'] == null) {
        cur['upiId'] = cached.upiId;
      }
      if (cached.currencyCode != null && cur['currencyCode'] == null) {
        cur['currencyCode'] = cached.currencyCode;
      }
    }
  }

  /// Runs Firestore write, profile load, and listeners. Call after build (e.g. addPostFrameCallback).
  Future<void> continueAuthFromFirebaseUser() async {
    if (_currentUserId.isEmpty) return;
    _encryption = DataEncryptionService(region: 'asia-south1');
    try {
      await _encryption!.ensureUserKey();
    } catch (e, st) {
      AppLogger.error('encryption key fetch failed', name: 'CycleRepository', error: e, stackTrace: st);
      _encryption = null;
    }
    SupabaseService.instance.setEncryptionService(_encryption);
    _writeCurrentUserProfile().catchError((e, st) {
      AppLogger.error('continueAuthFromFirebaseUser write failed', name: 'CycleRepository', error: e, stackTrace: st);
    });
    _loadCurrentUserProfileFromFirestore();
    _startListening();
    FeatureFlagService.instance.refresh();
    notifyListeners();
  }

  /// Refreshes current user profile (photoURL, upiId) from Firestore. Call when opening Profile so avatar persists after app restart.
  Future<void> refreshCurrentUserProfile() async {
    if (_currentUserId.isEmpty) return;
    await _loadCurrentUserProfileFromFirestore();
  }

  Future<void> _loadCurrentUserProfileFromFirestore() async {
    try {
      final u = await SupabaseService.instance.getUser(_currentUserId);
      if (u != null && _userCache.containsKey(_currentUserId)) {
        final cur = Map<String, dynamic>.from(_userCache[_currentUserId]!);
        if (u['photoURL'] != null) cur['photoURL'] = u['photoURL'];
        if (u['upiId'] != null) cur['upiId'] = u['upiId'];
        if (u['currencyCode'] != null) cur['currencyCode'] = u['currencyCode'];
        _userCache[_currentUserId] = cur;

        // Persist to local cache for instant load on next cold start
        UserProfileCache.instance.save(
          userId: _currentUserId,
          displayName: _currentUserName,
          photoURL: u['photoURL'] as String?,
          upiId: u['upiId'] as String?,
          phone: _currentUserPhone,
          currencyCode: cur['currencyCode'] as String?,
        );

        notifyListeners();
      }
    } catch (e, st) {
      AppLogger.error('_loadCurrentUserProfileFromFirestore failed', name: 'CycleRepository', error: e, stackTrace: st);
    }
  }

  Future<void> _writeCurrentUserProfile() async {
    final cache = _userCache[_currentUserId];
    await SupabaseService.instance.setUser(
      _currentUserId,
      displayName: _currentUserName,
      phoneNumber: _currentUserPhone,
      photoURL: cache?['photoURL'] as String?,
      upiId: cache?['upiId'] as String?,
      currencyCode: cache?['currencyCode'] as String?,
    );
  }

  /// Updates current user photo URL (e.g. after upload). Persists to Firestore and local cache.
  /// Throws if the Firestore write fails so the UI can show an error.
  Future<void> updateCurrentUserPhotoURL(String? photoURL) async {
    if (_currentUserId.isEmpty) return;
    _userCache[_currentUserId] ??= <String, dynamic>{};
    final previous = _userCache[_currentUserId]!['photoURL'];
    _userCache[_currentUserId]!['photoURL'] = photoURL;
    try {
      await _writeCurrentUserProfile();
      // Update local cache for instant load on next cold start
      UserProfileCache.instance.updatePhotoURL(photoURL);
      notifyListeners();
    } catch (e, st) {
      _userCache[_currentUserId]!['photoURL'] = previous;
      notifyListeners();
      AppLogger.error('updateCurrentUserPhotoURL write failed', name: 'CycleRepository', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Updates current user UPI ID. Persists to Firestore and local cache.
  Future<void> updateCurrentUserUpiId(String? upiId) async {
    if (_currentUserId.isEmpty) return;
    _userCache[_currentUserId] ??= <String, dynamic>{};
    _userCache[_currentUserId]!['upiId'] = upiId;
    await _writeCurrentUserProfile();
    // Update local cache for instant load on next cold start
    UserProfileCache.instance.updateUpiId(upiId);
    notifyListeners();
  }

  /// Returns profile photo URL for a member (by uid). Null for pending members or when not set.
  String? getMemberPhotoURL(String memberId) {
    if (memberId.startsWith('p_')) return null;
    return _userCache[memberId]?['photoURL'] as String?;
  }

  /// Returns UPI ID for a member (by uid). Null for pending members or when not set.
  String? getMemberUpiId(String memberId) {
    if (memberId.startsWith('p_')) return null;
    return _userCache[memberId]?['upiId'] as String?;
  }

  DataEncryptionService? _encryption;

  void clearAuth() {
    _settlementRepo.stopAll();
    _expensesByCycleId.clear();
    _groupMeta.clear();
    _revisionsByGroup.clear();
    _deletedIdsByGroup.clear();
    _clearLastAdded();
    _streamError = null;
    _auth.clearAuth();
    notify();
  }

  String? _lastAddedGroupId;
  String? _lastAddedExpenseId;
  String? _lastAddedDescription;
  double? _lastAddedAmount;

  String? get lastAddedGroupId => _lastAddedGroupId;
  String? get lastAddedExpenseId => _lastAddedExpenseId;
  String? get lastAddedDescription => _lastAddedDescription;
  double? get lastAddedAmount => _lastAddedAmount;

  void _setLastAdded(
    String groupId,
    String expenseId,
    String description,
    double amount,
  ) {
    _lastAddedGroupId = groupId;
    _lastAddedExpenseId = expenseId;
    _lastAddedDescription = description;
    _lastAddedAmount = amount;
  }

  void _clearLastAdded() {
    _lastAddedGroupId = null;
    _lastAddedExpenseId = null;
    _lastAddedDescription = null;
    _lastAddedAmount = null;
  }

  bool _notifyDirty = false;
  bool _notifyScheduled = false;

  void _requestNotify() {
    _notifyDirty = true;
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    Future.microtask(_flushNotify);
  }

  void _flushNotify() {
    _notifyScheduled = false;
    if (_notifyDirty) {
      _notifyDirty = false;
      notify();
    }
  }

  void clearLastAdded() => _clearLastAdded();

  List<Group> get groups => _groupsRepo.groups;
  Map<String, Member> get membersById => _groupsRepo.membersById;

  /// Pending group invitations for the current user.
  List<GroupInvitation> get pendingInvitations => _groupsRepo.pendingInvitations;

  /// True while waiting for the first invitations snapshot.
  bool get invitationsLoading => _groupsRepo.invitationsLoading;

  List<SystemMessage> getSystemMessages(String groupId) =>
      List.unmodifiable(_systemMessagesByGroup[groupId] ?? []);

  /// True while waiting for the first Firestore groups snapshot (for skeleton UX).
  bool get groupsLoading => _groupsRepo.groupsLoading;

  String? get streamError => _groupsRepo.streamError;
  void clearStreamError() {
    // This might need a method in GroupRepository
    _groupsRepo.startListening(); 
    notify();
  }

  void _startListening() {
    _groupsRepo.startListening();
    // We might need to listen to GroupRepository to trigger our own updates if necessary,
    // or just let GroupRepository handle its own listeners.
    // For now, we manually listen to group changes to trigger expense stream loads.
    _groupsRepo.addListener(_onGroupsChanged);
  }

  void _onGroupsChanged() {
    final groups = _groupsRepo.groups;
    final newIds = groups.map((g) => g.id).toSet();
    
    // Clean up streams for removed groups
    for (final id in _expenseSubs.keys.toList()) {
      if (!newIds.contains(id)) {
        _expenseSubs[id]?.cancel();
        _expenseSubs.remove(id);
      }
    }
    // ... similarly for other group-bound streams ...
    
    notify();
  }


  void _stopListening() {
    _groupsSub?.cancel();
    _groupsSub = null;
    _invitationsSub?.cancel();
    _invitationsSub = null;
    _groupsLoading = false;
    _pendingInvitations.clear();
    for (final sub in _expenseSubs.values) {
      sub.cancel();
    }
    _expenseSubs.clear();
    for (final sub in _systemMessageSubs.values) {
      sub.cancel();
    }
    _systemMessageSubs.clear();
    _systemMessagesByGroup.clear();
    for (final sub in _revisionSubs.values) {
      sub.cancel();
    }
    _revisionSubs.clear();
    for (final sub in _deletedIdsSubs.values) {
      sub.cancel();
    }
    _deletedIdsSubs.clear();
    for (final sub in _paymentAttemptSubs.values) {
      sub.cancel();
    }
    _paymentAttemptSubs.clear();
    _paymentAttemptCycleId.clear();
  }

  void restartListening() {
    clearStreamError();
    _stopListening();
    _startListening();
  }

  /// Lazily subscribe to group details (expenses, messages, etc.) when the UI enters a group.
  void ensureGroupStreams(String groupId) {
    if (_streamError != null || _groupsLoading) return;
    final meta = _groupMeta[groupId];
    if (meta == null) return;
    final activeCycleId = meta.activeCycleId;

    if (!_expenseSubs.containsKey(groupId)) {
      _expenseSubs[groupId] = SupabaseService.instance
          .expensesStream(groupId)
          .listen(
            (expDocs) => _onExpensesSnapshot(groupId, expDocs),
            onError: (e, st) {
              AppLogger.error('expensesStream error', name: 'CycleRepository', metadata: {'groupId': groupId}, error: e, stackTrace: st);
              _streamError = e.toString();
              notifyListeners();
            },
          );
    }
    if (!_systemMessageSubs.containsKey(groupId)) {
      _systemMessageSubs[groupId] = SupabaseService.instance
          .systemMessagesStream(groupId)
          .listen(
            (msgs) => _onSystemMessagesSnapshot(groupId, msgs),
            onError: (e, st) {
              AppLogger.error('systemMessagesStream error', name: 'CycleRepository', metadata: {'groupId': groupId}, error: e, stackTrace: st);
            },
          );
    }
    if (!_revisionSubs.containsKey(groupId)) {
      _revisionSubs[groupId] = SupabaseService.instance
          .expenseRevisionsStream(groupId)
          .listen(
            (revs) => _onRevisionsSnapshot(groupId, revs),
            onError: (e, st) {
              AppLogger.error('expenseRevisionsStream error', name: 'CycleRepository', metadata: {'groupId': groupId}, error: e, stackTrace: st);
            },
          );
    }
    if (!_deletedIdsSubs.containsKey(groupId)) {
      _deletedIdsSubs[groupId] = SupabaseService.instance
          .deletedExpenseIdsStream(groupId)
          .listen(
            (ids) => _onDeletedIdsSnapshot(groupId, ids),
            onError: (e, st) {
              AppLogger.error('deletedExpenseIdsStream error', name: 'CycleRepository', metadata: {'groupId': groupId}, error: e, stackTrace: st);
            },
          );
    }
    _settlementRepo.startListening(groupId, activeCycleId);
  }

  /// Unsubscribe from streams when leaving group detail, to conserve resources.
  void unfocusGroupStreams(String groupId) {
    _expenseSubs[groupId]?.cancel();
    _expenseSubs.remove(groupId);
    _systemMessageSubs[groupId]?.cancel();
    _systemMessageSubs.remove(groupId);
    _revisionSubs[groupId]?.cancel();
    _revisionSubs.remove(groupId);
    _deletedIdsSubs[groupId]?.cancel();
    _deletedIdsSubs.remove(groupId);
    _paymentAttemptSubs[groupId]?.cancel();
    _paymentAttemptSubs.remove(groupId);
    _paymentAttemptCycleId.remove(groupId);
  }

  /// Refreshes user profile data for all members of a group.
  /// Call when opening a group to get latest profile photos, names, etc.
  Future<void> refreshGroupMemberProfiles(String groupId) async {
    final idx = _groups.indexWhere((g) => g.id == groupId);
    if (idx < 0) return;
    final group = _groups[idx];

    final uids = group.memberIds.where((id) => !id.startsWith('p_')).toList();
    bool changed = false;

    for (final uid in uids) {
      try {
        final u = await SupabaseService.instance.getUser(uid);
        if (u != null) {
          _userCache[uid] = u;
          final existing = _membersById[uid];
          final newPhotoURL = u['photoURL'] as String?;
          if (existing != null && existing.photoURL != newPhotoURL) {
            _membersById[uid] = Member(
              id: uid,
              phone: u['phoneNumber'] as String? ?? existing.phone,
              name: u['displayName'] as String? ?? existing.name,
              photoURL: newPhotoURL,
            );
            changed = true;
          }
        }
      } catch (e, st) {
        AppLogger.error('refreshGroupMemberProfiles error', name: 'CycleRepository', metadata: {'uid': uid, 'groupId': groupId}, error: e, stackTrace: st);
      }
    }

    if (changed) notifyListeners();
  }

  void _onExpensesSnapshot(String groupId, List<DocView> expDocs) {
    final meta = _groupMeta[groupId];
    if (meta == null) return;
    final cycleId = meta.activeCycleId;
    final currencyCode = getGroup(groupId)?.currencyCode ?? 'INR';
    final list = <Expense>[];
    for (final d in expDocs) {
      try {
        list.add(_expenseFromFirestore(d.data(), d.id, currencyCode: currencyCode));
      } catch (e, st) {
        AppLogger.error('_onExpensesSnapshot skipping doc', name: 'CycleRepository', metadata: {'docId': d.id, 'groupId': groupId}, error: e, stackTrace: st);
      }
    }
    _expensesByCycleId[cycleId] = list;
    _refreshGroupAmounts(groupId);
    _requestNotify();
  }

  void _onSystemMessagesSnapshot(
    String groupId,
    List<Map<String, dynamic>> msgs,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    _systemMessagesByGroup[groupId] = msgs.map((m) {
      final ts = m['timestamp'] as int? ?? 0;
      final dt = DateTime.fromMillisecondsSinceEpoch(ts);
      String dateStr;
      if (dt.year == today.year &&
          dt.month == today.month &&
          dt.day == today.day) {
        dateStr = 'Today';
      } else if (dt.year == yesterday.year &&
          dt.month == yesterday.month &&
          dt.day == yesterday.day) {
        dateStr = 'Yesterday';
      } else {
        dateStr = _formatDate(dt);
      }
      return SystemMessage(
        id: m['id'] as String? ?? '',
        type: m['type'] as String? ?? '',
        userId: m['userId'] as String? ?? '',
        userName: m['userName'] as String? ?? '',
        date: dateStr,
        timestamp: ts,
        detail: m['detail'] as String? ?? '',
        prefix: m['prefix'] as String? ?? '',
      );
    }).toList();
    _requestNotify();
  }

  void _onRevisionsSnapshot(String groupId, List<Map<String, dynamic>> revs) {
    _revisionsByGroup[groupId] = revs
        .map(
          (r) => ExpenseRevision(
            expenseId: r['expenseId'] as String? ?? r['id'] as String? ?? '',
            replacesExpenseId: r['replacesExpenseId'] as String?,
          ),
        )
        .toList();
  }

  void _onDeletedIdsSnapshot(String groupId, Set<String> ids) {
    _deletedIdsByGroup[groupId] = ids;
  }


  String _phoneForUid(String uid) {
    if (uid == _currentUserId) return _currentUserPhone;
    return _membersById[uid]?.phone ??
        _userCache[uid]?['phoneNumber'] as String? ??
        '';
  }

  Expense _expenseFromFirestore(
    Map<String, dynamic> data,
    String id, {
    String currencyCode = 'INR',
  }) {
    final payerId = data['payerId'] is String ? data['payerId'] as String : '';
    final participantIdsRaw = data['participantIds'] is List ? data['participantIds'] as List<dynamic> : null;
    final splits = data['splits'] is Map ? data['splits'] as Map<String, dynamic> : null;
    final splitsMinorRaw = data['splitsMinor'] is Map ? data['splitsMinor'] as Map<String, dynamic> : null;
    final amountMinorStored = data['amountMinor'];
    final hasMinor =
        amountMinorStored != null &&
        (amountMinorStored is int ||
            (amountMinorStored is num &&
                amountMinorStored == amountMinorStored.roundToDouble())) &&
        splitsMinorRaw != null &&
        splitsMinorRaw.isNotEmpty;

    double amount;
    final splitAmountsById = <String, double>{};
    int? amountMinor;
    Map<String, int>? splitAmountsByIdMinor;

    if (hasMinor) {
      final am = amountMinorStored is int
          ? amountMinorStored
          : (amountMinorStored as num).round();
      amountMinor = am;
      amount = MoneyConversion.minorToDisplay(am, currencyCode);
      splitAmountsByIdMinor = {};
      for (final entry in splitsMinorRaw.entries) {
        final key = entry.key.toString();
        if (key.startsWith('p_')) continue;
        final v = entry.value;
        final minor = v is int
            ? v
            : (v is num ? v.round() : int.tryParse(v?.toString() ?? '0') ?? 0);
        splitAmountsByIdMinor[key] = minor;
        splitAmountsById[key] = MoneyConversion.minorToDisplay(
          minor,
          currencyCode,
        );
      }
    } else {
      amount = (data['amount'] is num)
          ? (data['amount'] as num).toDouble()
          : 0.0;
      final participantIds =
          participantIdsRaw
              ?.map((e) => e?.toString())
              .where((s) => s != null && s.isNotEmpty)
              .cast<String>()
              .toList() ??
          splits?.keys.toList() ??
          [];
      for (final uid in participantIds) {
        final amt = splits != null && splits.containsKey(uid)
            ? ((splits[uid] is num)
                  ? (splits[uid] as num).toDouble()
                  : double.tryParse(splits[uid]?.toString() ?? '') ?? 0.0)
            : 0.0;
        splitAmountsById[uid] = amt;
      }
      if (splitAmountsById.isEmpty && splits != null) {
        for (final entry in splits.entries) {
          splitAmountsById[entry.key] = (entry.value is num)
              ? (entry.value as num).toDouble()
              : double.tryParse(entry.value?.toString() ?? '') ?? 0.0;
        }
      }
    }

    final participantIds = splitAmountsById.isNotEmpty
        ? splitAmountsById.keys.toList()
        : (participantIdsRaw
                  ?.map((e) => e?.toString())
                  .where((s) => s != null && s.isNotEmpty)
                  .cast<String>()
                  .toList() ??
              splits?.keys.toList() ??
              []);
    final splitType = (data['splitType'] as String?)?.trim().isNotEmpty == true
        ? (data['splitType'] as String).trim()
        : 'Even';
    return Expense(
      id: id,
      description: data['description'] as String? ?? '',
      amount: amount,
      date: data['date'] as String? ?? 'Today',
      participantIds: participantIds,
      paidById: payerId,
      createdById: data['createdById'] as String? ?? '',
      splitAmountsById: splitAmountsById.isEmpty ? null : splitAmountsById,
      category: data['category'] as String? ?? '',
      splitType: splitType,
      amountMinor: amountMinor,
      splitAmountsByIdMinor: splitAmountsByIdMinor,
    );
  }

  void _refreshGroupAmounts([String? groupId]) {
    final idsToRefresh = groupId != null
        ? _groups.where((g) => g.id == groupId).map((g) => g.id).toList()
        : _groups.map((g) => g.id).toList();
    for (var i = 0; i < _groups.length; i++) {
      final g = _groups[i];
      if (!idsToRefresh.contains(g.id)) continue;
      final meta = _groupMeta[g.id];
      if (meta == null) continue;
      final expenses = _expensesByCycleId[meta.activeCycleId] ?? [];
      final amount = expenses.fold<double>(0.0, (s, e) => s + e.amount);
      final status = meta.cycleStatus == 'settling'
          ? 'closing'
          : (meta.cycleStatus == 'active' ? 'open' : 'settled');
      final statusLine = meta.cycleStatus == 'settling'
          ? 'Cycle Settled - Pending Restart'
          : 'Cycle open';
      _groups[i] = Group(
        id: g.id,
        name: g.name,
        status: status,
        amount: amount,
        statusLine: statusLine,
        creatorId: g.creatorId,
        memberIds: g.memberIds,
        currencyCode: g.currencyCode,
        inviteLinkToken: g.inviteLinkToken,
        inviteLinkEnabled: g.inviteLinkEnabled,
      );
    }
  }


  Future<void> addGroup(Group group, {String? settlementRhythm, int? settlementDay}) =>
      _groupsRepo.addGroup(group, settlementRhythm: settlementRhythm, settlementDay: settlementDay);

  Group? getGroup(String id) => _groupsRepo.getGroup(id);

  List<Member> getMembersForGroup(String groupId) => _groupsRepo.getMembersForGroup(groupId);

  String getMemberDisplayNameById(String uid) => _groupsRepo.getMemberDisplayNameById(uid);

  String getMemberDisplayName(String phoneOrUid) => _groupsRepo.getMemberDisplayName(phoneOrUid);

  void addMemberToGroup(String groupId, Member member) => _groupsRepo.addMemberToGroup(groupId, member);

  Future<void> acceptInvitation(String groupId) => _groupsRepo.acceptInvitation(groupId);

  Future<void> declineInvitation(String groupId) => _groupsRepo.declineInvitation(groupId);

  void removeMemberFromGroup(String groupId, String memberId) => _groupsRepo.removeMemberFromGroup(groupId, memberId);

  bool isCreator(String groupId, String userId) => _groupsRepo.isCreator(groupId, userId);

  bool canEditCycle(String groupId, String userId) {
    final meta = _groupMeta[groupId];
    if (meta == null) return false;
    if (meta.cycleStatus == 'settling') return false;
    if (isCreator(groupId, userId)) return true;
    return meta.cycleStatus == 'active';
  }

  /// Returns true if [userId] may edit or delete [expenseId] in [groupId].
  ///
  /// Rules (domain layer — cannot be bypassed via UI):
  /// - Cycle must be active (not settling/closed). Hard block.
  /// - Expense must be in an active lifecycle state.
  /// - No participant may have an in-flight or settled PaymentAttempt. Hard block.
  /// - Creator of the expense can always mutate their own expense.
  /// - Group admin (group.creatorId) can mutate any expense, but an
  ///   activity log entry will be written automatically.
  bool canMutateExpense(String groupId, String expenseId, String userId) {
    final meta = _groupMeta[groupId];
    if (meta == null) return false;
    // Hard block: closed or settling cycles are immutable.
    if (meta.cycleStatus != 'active') return false;
    // Expense must be in an active lifecycle state.
    if (!canEditExpense(groupId, expenseId)) return false;

    // Hard block: settlement corruption prevention.
    final attempts = _paymentAttemptsByGroup[groupId] ?? [];
    final expense = getExpense(groupId, expenseId);
    final participantSet = expense?.participantIds.toSet() ?? {};

    final relevantAttempts = attempts.where((a) {
      final isRelevant =
          participantSet.contains(a.fromMemberId) ||
          participantSet.contains(a.toMemberId) ||
          (expense != null &&
              (a.fromMemberId == expense.paidById ||
                  a.toMemberId == expense.paidById));
      return isRelevant;
    });

    // If any relevant attempt is fully settled (confirmed by receiver or cash confirmed),
    // we block the mutation entirely. Real money has moved.
    if (relevantAttempts.any((a) => a.status.isFullyConfirmed)) return false;
    // If any relevant attempt is in flight (initiated, confirmed by payer, cash pending),
    // we block to prevent invalidating an active settlement plan.
    if (relevantAttempts.any((a) => a.status.isInFlight)) return false;

    // Creator of the expense can always mutate.
    if (expense != null && expense.createdById == userId) return true;
    // Group admin (group creator) can override.
    if (isCreator(groupId, userId)) return true;
    return false;
  }

  bool canDeleteGroup(String groupId, String userId) {
    return isCreator(groupId, userId);
  }

  Cycle getActiveCycle(String groupId) {
    final meta = _groupMeta[groupId];
    final group = getGroup(groupId);
    if (meta != null && group != null) {
      final status = meta.cycleStatus == 'settling'
          ? CycleStatus.settling
          : CycleStatus.active;
      final expenses = _expensesByCycleId[meta.activeCycleId] ?? [];
      return Cycle(
        id: meta.activeCycleId,
        groupId: groupId,
        status: status,
        startDate: _formatDate(DateTime.now()),
        expenses: expenses,
      );
    }
    final now = DateTime.now();
    final newCycleId = _nextCycleId();
    return Cycle(
      id: newCycleId,
      groupId: groupId,
      status: CycleStatus.active,
      startDate: _formatDate(now),
      expenses: [],
    );
  }

  List<Expense> getExpenses(String cycleId) {
    final list = _expensesByCycleId[cycleId];
    return list != null ? List.unmodifiable(list) : [];
  }

  Future<void> addExpense(String groupId, Expense expense) async {
    final amountError = validateExpenseAmount(expense.amount);
    if (amountError != null) throw ArgumentError(amountError);
    final descError = validateExpenseDescription(expense.description);
    if (descError != null) throw ArgumentError(descError);

    final meta = _groupMeta[groupId];
    if (meta?.cycleStatus == 'settling') {
      throw StateError(
        'This cycle is being settled. New expenses cannot be added until the next cycle begins.',
      );
    }
    final cycleId = meta?.activeCycleId;
    if (cycleId == null) {
      throw ArgumentError(
        'No active cycle. Start a new cycle to add expenses.',
      );
    }
    final payerId = expense.paidById.isNotEmpty
        ? expense.paidById
        : _currentUserId;
    final members = getMembersForGroup(groupId);
    final realMemberIds = members
        .where((m) => !m.id.startsWith('p_'))
        .map((m) => m.id)
        .toList();
    final participantIds = expense.participantIds.isNotEmpty
        ? expense.participantIds
        : (realMemberIds.isNotEmpty ? realMemberIds : [_currentUserId]);
    final splits = <String, double>{};
    if (expense.splitAmountsById != null &&
        expense.splitAmountsById!.isNotEmpty) {
      for (final e in expense.splitAmountsById!.entries) {
        if (!e.key.startsWith('p_')) splits[e.key] = e.value;
      }
    }
    if (splits.isEmpty) {
      final perShare = expense.amount / participantIds.length;
      for (final uid in participantIds) {
        if (!uid.startsWith('p_')) splits[uid] = perShare;
      }
    }
    if (splits.isEmpty) splits[payerId] = expense.amount;
    final uids = splits.keys.toList();
    final currencyCode = getGroup(groupId)?.currencyCode ?? 'INR';
    final amountMinor = MoneyConversion.parseToMinor(
      expense.amount,
      currencyCode,
    ).amountMinor;
    final splitsMinor = splits.map(
      (k, v) => MapEntry(
        k,
        MoneyConversion.parseToMinor(v, currencyCode).amountMinor,
      ),
    );
    final data = {
      'id': expense.id,
      'groupId': groupId,
      'amount': expense.amount,
      'amountMinor': amountMinor,
      'splitsMinor': splitsMinor,
      'payerId': payerId,
      'splitType': expense.splitType.isNotEmpty ? expense.splitType : 'Even',
      'participantIds': uids,
      'splits': splits.map((k, v) => MapEntry(k, v)),
      'description': sanitizeTextInput(expense.description),
      'date': expense.date,
      'dateSortKey': _dateStringToSortKey(expense.date),
      'createdById': _currentUserId,
      if (expense.category.isNotEmpty) 'category': expense.category,
    };
    await SupabaseService.instance.addExpense(groupId, data);
    _setLastAdded(groupId, expense.id, expense.description, expense.amount);
  }

  /// Adds an expense from the Magic Bar confirmation flow. All person references by member id.
  Future<void> addExpenseFromMagicBar(
    String groupId, {
    required String id,
    required String description,
    required double amount,
    required String date,
    required String payerId,
    required String splitType,
    required List<String> participantIds,
    List<String>? excludedIds,
    Map<String, double>? exactAmountsById,
    String category = '',
  }) async {
    final amountError = validateExpenseAmount(amount);
    if (amountError != null) throw ArgumentError(amountError);
    final descError = validateExpenseDescription(description);
    if (descError != null) throw ArgumentError(descError);

    final meta = _groupMeta[groupId];
    if (meta?.cycleStatus == 'settling') {
      throw StateError(
        'This cycle is being settled. New expenses cannot be added until the next cycle begins.',
      );
    }
    final cycleId = meta?.activeCycleId;
    if (cycleId == null) {
      throw ArgumentError(
        'No active cycle. Start a new cycle to add expenses.',
      );
    }

    final effectivePayerId = payerId.isNotEmpty ? payerId : _currentUserId;
    final members = getMembersForGroup(groupId);
    final allIds = members
        .where((m) => !m.id.startsWith('p_'))
        .map((m) => m.id)
        .toList();

    List<String> idsInSplit = [];
    Map<String, double> splitsById = {};

    if (splitType == 'Exact' &&
        exactAmountsById != null &&
        exactAmountsById.isNotEmpty) {
      idsInSplit = exactAmountsById.keys
          .where((k) => !k.startsWith('p_'))
          .toList();
      for (final e in exactAmountsById.entries) {
        if (!e.key.startsWith('p_')) splitsById[e.key] = e.value;
      }
    } else if (splitType == 'Exclude' &&
        excludedIds != null &&
        excludedIds.isNotEmpty) {
      final excludedSet = excludedIds.toSet();
      idsInSplit = allIds.where((id) => !excludedSet.contains(id)).toList();
      if (idsInSplit.isEmpty) idsInSplit = [effectivePayerId];
      final perShare = amount / idsInSplit.length;
      for (final uid in idsInSplit) {
        splitsById[uid] = perShare;
      }
    } else {
      idsInSplit = participantIds.isNotEmpty
          ? participantIds.where((id) => !id.startsWith('p_')).toList()
          : allIds;
      if (idsInSplit.isEmpty) idsInSplit = [effectivePayerId];
      final perShare = amount / idsInSplit.length;
      for (final uid in idsInSplit) {
        splitsById[uid] = perShare;
      }
    }

    final splits = <String, double>{};
    for (final uid in idsInSplit) {
      splits[uid] = splitsById[uid] ?? 0.0;
    }
    if (splits.isEmpty) splits[effectivePayerId] = amount;

    final currencyCode = getGroup(groupId)?.currencyCode ?? 'INR';
    final amountMinor = MoneyConversion.parseToMinor(
      amount,
      currencyCode,
    ).amountMinor;
    final splitsMinor = splits.map(
      (k, v) => MapEntry(
        k,
        MoneyConversion.parseToMinor(v, currencyCode).amountMinor,
      ),
    );

    final writtenParticipantIds = splits.keys.toList();

    final data = {
      'id': id,
      'groupId': groupId,
      'amount': amount,
      'amountMinor': amountMinor,
      'splitsMinor': splitsMinor,
      'payerId': effectivePayerId,
      'splitType': splitType,
      'participantIds': writtenParticipantIds,
      'splits': splits.map((k, v) => MapEntry(k, v)),
      'description': sanitizeTextInput(description),
      'date': date,
      'dateSortKey': _dateStringToSortKey(date),
      'createdById': _currentUserId,
      if (category.isNotEmpty) 'category': category,
    };

    await SupabaseService.instance.addExpense(groupId, data);
    _setLastAdded(groupId, id, description, amount);
  }

  /// Adds an expense from a NormalizedExpense (the canonical path).
  /// This method takes an already-validated, ID-only NormalizedExpense and persists it.
  Future<void> addExpenseFromNormalized(
    String groupId, {
    required String id,
    required NormalizedExpense normalized,
    required String splitType,
  }) async {
    final meta = _groupMeta[groupId];
    if (meta?.cycleStatus == 'settling') {
      throw StateError(
        'This cycle is being settled. New expenses cannot be added until the next cycle begins.',
      );
    }
    final cycleId = meta?.activeCycleId;
    if (cycleId == null) {
      throw ArgumentError(
        'No active cycle. Start a new cycle to add expenses.',
      );
    }

    final payerId = normalized.primaryPayerId;
    final splits = normalized.participantSharesByMemberId.map(
      (memberId, money) => MapEntry(memberId, MoneyConversion.toDisplay(money)),
    );
    final participantIds = normalized.participantIds;
    final displayAmount = MoneyConversion.toDisplay(normalized.total);

    final splitsMinor = normalized.participantSharesByMemberId.map(
      (memberId, money) => MapEntry(memberId, money.amountMinor),
    );

    final data = {
      'id': id,
      'groupId': groupId,
      'amount': displayAmount,
      'amountMinor': normalized.total.amountMinor,
      'splitsMinor': splitsMinor,
      'payerId': payerId,
      'splitType': splitType,
      'participantIds': participantIds,
      'splits': splits,
      'description': sanitizeTextInput(normalized.description),
      'date': normalized.date,
      'dateSortKey': _dateStringToSortKey(normalized.date),
      'createdById': _currentUserId,
      if (normalized.category.isNotEmpty) 'category': normalized.category,
    };

    await SupabaseService.instance.addExpense(groupId, data);
    _setLastAdded(groupId, id, normalized.description, displayAmount);
  }

  /// Converts a NormalizedExpense to an Expense model (for local use).
  Expense normalizedToExpense(
    String id,
    NormalizedExpense normalized,
    String splitType,
  ) {
    final displayAmount = MoneyConversion.toDisplay(normalized.total);
    final splitAmounts = normalized.participantSharesByMemberId.map(
      (memberId, money) => MapEntry(memberId, MoneyConversion.toDisplay(money)),
    );
    return Expense(
      id: id,
      description: normalized.description,
      amount: displayAmount,
      date: normalized.date,
      participantIds: normalized.participantIds,
      paidById: normalized.primaryPayerId,
      splitAmountsById: splitAmounts,
      category: normalized.category,
      splitType: splitType,
    );
  }

  Expense? getExpense(String groupId, String expenseId) {
    final meta = _groupMeta[groupId];
    if (meta == null) return null;
    final list = _expensesByCycleId[meta.activeCycleId];
    if (list == null) return null;
    try {
      return list.firstWhere((e) => e.id == expenseId);
    } catch (_) {
      return null;
    }
  }

  /// Returns the lifecycle state of an expense (active, deleted, or superseded).
  ExpenseLifecycleState getExpenseLifecycleState(
    String groupId,
    String expenseId,
  ) {
    final revisions = _revisionsByGroup[groupId] ?? [];
    final deletedIds = _deletedIdsByGroup[groupId] ?? {};
    return deriveExpenseState(
      expenseId: expenseId,
      revisions: revisions,
      deletedExpenseIds: deletedIds,
    );
  }

  /// Returns true if the expense can be edited (is active).
  bool canEditExpense(String groupId, String expenseId) {
    return getExpenseLifecycleState(groupId, expenseId) ==
        ExpenseLifecycleState.active;
  }

  /// Returns true if the expense can be deleted (is active).
  bool canDeleteExpense(String groupId, String expenseId) {
    return getExpenseLifecycleState(groupId, expenseId) ==
        ExpenseLifecycleState.active;
  }

  /// Returns true if the expense is deleted (soft-deleted via compensation model).
  bool isExpenseDeleted(String groupId, String expenseId) {
    return getExpenseLifecycleState(groupId, expenseId) ==
        ExpenseLifecycleState.deleted;
  }

  /// Returns all active (non-deleted, non-superseded) expenses for a group.
  List<Expense> getActiveExpenses(String groupId) {
    final cycle = getActiveCycle(groupId);
    return cycle.expenses.where((e) => canEditExpense(groupId, e.id)).toList();
  }

  /// Updates an expense in-place.
  /// Enforces: cycle must be active; caller must be expense creator or group admin.
  /// Admin overrides always emit a system activity entry for auditability.
  void updateExpense(String groupId, Expense updatedExpense) {
    final amountError = validateExpenseAmount(updatedExpense.amount);
    if (amountError != null) throw ArgumentError(amountError);
    final descError = validateExpenseDescription(updatedExpense.description);
    if (descError != null) throw ArgumentError(descError);

    final revisions = _revisionsByGroup[groupId] ?? <ExpenseRevision>[];
    final deletedIds = _deletedIdsByGroup[groupId] ?? {};

    guardEdit(
      expenseId: updatedExpense.id,
      revisions: revisions,
      deletedExpenseIds: deletedIds,
    );

    if (!canMutateExpense(groupId, updatedExpense.id, _currentUserId)) {
      throw StateError('You do not have permission to edit this expense.');
    }

    // Capture old values for activity log before writing.
    final existing = getExpense(groupId, updatedExpense.id);
    final isAdminOverride =
        existing != null &&
        existing.createdById.isNotEmpty &&
        existing.createdById != _currentUserId &&
        isCreator(groupId, _currentUserId);

    final meta = _groupMeta[groupId];
    if (meta == null) return;
    final payerId = updatedExpense.paidById.isNotEmpty
        ? updatedExpense.paidById
        : _currentUserId;

    final Map<String, double> splits;
    final String splitType;
    List<String> participantIds;
    if (updatedExpense.splitAmountsById != null &&
        updatedExpense.splitAmountsById!.isNotEmpty) {
      splits = Map.from(updatedExpense.splitAmountsById!);
      if (splits.isEmpty) splits[payerId] = updatedExpense.amount;
      splitType = updatedExpense.splitType;
      participantIds = splits.keys.toList();
    } else {
      final ids = updatedExpense.participantIds.isNotEmpty
          ? updatedExpense.participantIds
          : [payerId];
      final perShare = updatedExpense.amount / ids.length;
      splits = {for (final uid in ids) uid: perShare};
      splitType = updatedExpense.splitType;
      participantIds = ids;
    }

    final currencyCode = getGroup(groupId)?.currencyCode ?? 'INR';
    final amountMinor = MoneyConversion.parseToMinor(
      updatedExpense.amount,
      currencyCode,
    ).amountMinor;
    final splitsMinor = splits.map(
      (k, v) => MapEntry(
        k,
        MoneyConversion.parseToMinor(v, currencyCode).amountMinor,
      ),
    );
    SupabaseService.instance.updateExpense(groupId, updatedExpense.id, {
      'amount': updatedExpense.amount,
      'amountMinor': amountMinor,
      'splitsMinor': splitsMinor,
      'description': sanitizeTextInput(updatedExpense.description),
      'date': updatedExpense.date,
      'dateSortKey': _dateStringToSortKey(updatedExpense.date),
      'payerId': payerId,
      'splitType': splitType,
      'participantIds': participantIds,
      'splits': splits.map((k, v) => MapEntry(k, v)),
      if (updatedExpense.category.isNotEmpty)
        'category': updatedExpense.category,
    });

    // Emit activity log for admin overrides or any material change.
    if (existing != null) {
      final actorName = _currentUserName.isNotEmpty
          ? _currentUserName
          : 'Someone';
      final currencyCode = getGroup(groupId)?.currencyCode ?? 'INR';
      final fmtAmount = formatMoneyFromMajor(existing.amount, currencyCode);
      final prefix = isAdminOverride
          ? '$actorName (admin) edited'
          : '$actorName edited';
      String detail = '${existing.description} $fmtAmount';
      if (isAdminOverride) {
        detail +=
            '. Settlement plan recalculated. Any pending payments may need to be re-initiated.';
      }
      SupabaseService.instance
          .addSystemMessage(
            groupId,
            type: 'expense_edited',
            userName: actorName,
            odId: _currentUserId,
            detail: detail,
            prefix: prefix,
          )
          .catchError((e) => debugPrint('Activity log write failed: $e'));
    }
  }

  /// Soft-deletes an expense using the compensation model.
  /// Enforces: cycle must be active; caller must be expense creator or group admin.
  /// Admin overrides always emit a system activity entry for auditability.
  /// The original expense document is preserved for audit trail.
  Future<void> deleteExpense(String groupId, String expenseId) async {
    if (!canMutateExpense(groupId, expenseId, _currentUserId)) {
      throw StateError('You do not have permission to delete this expense.');
    }

    final revisions = _revisionsByGroup[groupId] ?? <ExpenseRevision>[];
    final deletedIds = _deletedIdsByGroup[groupId] ?? {};

    guardDelete(
      expenseId: expenseId,
      revisions: revisions,
      deletedExpenseIds: deletedIds,
    );

    // Capture before deleting for activity log.
    final existing = getExpense(groupId, expenseId);
    final isAdminOverride =
        existing != null &&
        existing.createdById.isNotEmpty &&
        existing.createdById != _currentUserId &&
        isCreator(groupId, _currentUserId);

    await SupabaseService.instance.markExpenseDeleted(
      groupId,
      expenseId,
      deletedById: _currentUserId,
    );

    if (_lastAddedGroupId == groupId && _lastAddedExpenseId == expenseId) {
      _clearLastAdded();
    }

    // Activity log: always emit for admin overrides; for creators only if it's a non-trivial expense.
    if (existing != null) {
      final actorName = _currentUserName.isNotEmpty
          ? _currentUserName
          : 'Someone';
      final currencyCode = getGroup(groupId)?.currencyCode ?? 'INR';
      final fmtAmount = formatMoneyFromMajor(existing.amount, currencyCode);
      final prefix = isAdminOverride
          ? '$actorName (admin) deleted'
          : '$actorName deleted';
      String detail = '${existing.description} $fmtAmount';
      if (isAdminOverride) {
        detail +=
            '. Settlement plan recalculated. Any pending payments may need to be re-initiated.';
      }
      SupabaseService.instance
          .addSystemMessage(
            groupId,
            type: 'expense_deleted',
            userName: actorName,
            odId: _currentUserId,
            detail: detail,
            prefix: prefix,
          )
          .catchError((e) => debugPrint('Activity log write failed: $e'));
    }
  }

  /// Hard-deletes an expense (removes from Firestore completely).
  /// Use for undo operations within the undo window only.
  void hardDeleteExpense(String groupId, String expenseId) {
    SupabaseService.instance.deleteExpense(groupId, expenseId);
    if (_lastAddedGroupId == groupId && _lastAddedExpenseId == expenseId) {
      _clearLastAdded();
    }
  }

  /// Deletes the group from Firestore. Only the creator can delete.
  /// Cancels the group's expense subscription first so no pending writes can recreate an empty group doc after delete.
  /// Removes the group from local state after delete so the UI updates.
  /// Idempotent: if Firestore reports NOT_FOUND the group is already gone — treat as success.
  Future<void> deleteGroup(String groupId) async {
    if (!canDeleteGroup(groupId, _currentUserId)) {
      throw StateError('Only the group creator can delete this group.');
    }
    _expenseSubs[groupId]?.cancel();
    _expenseSubs.remove(groupId);
    _paymentAttemptSubs[groupId]?.cancel();
    _paymentAttemptSubs.remove(groupId);
    _paymentAttemptCycleId.remove(groupId);
    try {
      await SupabaseService.instance.deleteGroup(groupId);
    } catch (e) {
      // Treat NOT_FOUND as success — the group is already gone.
      // Only rethrow if the group is still present in our local state,
      // which indicates a real permission or network error.
      final stillExists = _groups.any((g) => g.id == groupId);
      if (stillExists) rethrow;
      // Group no longer exists locally either — deletion succeeded despite the error.
      debugPrint(
        'CycleRepository.deleteGroup: swallowed benign error (group already gone): $e',
      );
    }
    _removeGroupLocally(groupId);
  }

  /// Removes a group from in-memory state so the list updates immediately after delete.
  void _removeGroupLocally(String groupId) {
    final meta = _groupMeta[groupId];
    _groups.removeWhere((g) => g.id == groupId);
    _groupMeta.remove(groupId);
    _expenseSubs[groupId]?.cancel();
    _expenseSubs.remove(groupId);
    _paymentAttemptSubs[groupId]?.cancel();
    _paymentAttemptSubs.remove(groupId);
    _paymentAttemptCycleId.remove(groupId);
    _paymentAttemptsByGroup.remove(groupId);
    if (meta != null) {
      _expensesByCycleId.remove(meta.activeCycleId);
    }
    notifyListeners();
  }

  /// Net balances from expenses, adjusted by all fully confirmed payment attempts.
  /// Used so that after B pays A ₹20, adding a new expense does not double-count the settled amount.
  Map<String, int> getNetBalancesAfterSettlementsMinor(String groupId) {
    final cycle = getActiveCycle(groupId);
    final members = getMembersForGroup(groupId);
    final ids = members
        .where((m) => !m.id.startsWith('p_'))
        .map((m) => m.id)
        .toSet();
    final currencyCode = getGroup(groupId)?.currencyCode ?? 'INR';
    final net = Map<String, int>.from(
      SettlementEngine.computeNetBalances(
        cycle.expenses,
        members,
        currencyCode: currencyCode,
      ),
    );
    for (final id in ids) {
      net.putIfAbsent(id, () => 0);
    }
    final attempts = _paymentAttemptsByGroup[groupId] ?? [];
    for (final a in attempts) {
      if (!a.status.isFullyConfirmed || a.amountMinor <= 0) continue;
      if (net.containsKey(a.fromMemberId)) {
        net[a.fromMemberId] = (net[a.fromMemberId] ?? 0) + a.amountMinor;
      }
      if (net.containsKey(a.toMemberId)) {
        net[a.toMemberId] = (net[a.toMemberId] ?? 0) - a.amountMinor;
      }
    }
    return Map.unmodifiable(net);
  }

  Map<String, double> calculateBalances(String groupId) {
    final currencyCode = getGroup(groupId)?.currencyCode ?? 'INR';
    final netMinor = getNetBalancesAfterSettlementsMinor(groupId);
    return netMinor.map(
      (id, minor) => MapEntry(id, MoneyConversion.minorToDisplay(minor, currencyCode)),
    );
  }

  List<String> getSettlementInstructions(String groupId) {
    final balances = calculateBalances(groupId);
    final currencyCode = getGroup(groupId)?.currencyCode ?? 'INR';
    final debtors = balances.entries
        .where((e) => e.value < -0.01)
        .map((e) => _BalanceEntry(e.key, -e.value))
        .toList();
    final creditors = balances.entries
        .where((e) => e.value > 0.01)
        .map((e) => _BalanceEntry(e.key, e.value))
        .toList();
    debtors.sort((a, b) => b.amount.compareTo(a.amount));
    creditors.sort((a, b) => b.amount.compareTo(a.amount));
    final List<String> result = [];
    int d = 0, c = 0;
    while (d < debtors.length && c < creditors.length) {
      final debtor = debtors[d];
      final creditor = creditors[c];
      final amount = (debtor.amount < creditor.amount
          ? debtor.amount
          : creditor.amount);
      if (amount < 0.01) break;
      result.add(
        '${getMemberDisplayNameById(debtor.id)} owes ${getMemberDisplayNameById(creditor.id)} ${formatMoneyFromMajor(amount, currencyCode)}',
      );
      debtor.amount -= amount;
      creditor.amount -= amount;
      if (debtor.amount < 0.01) d++;
      if (creditor.amount < 0.01) c++;
    }
    return result;
  }

  /// Settlement transfers for the current user as debtor: (creditor, amount) pairs and total.
  /// Empty list and 0 if current user owes nothing.
  List<SettlementTransfer> getSettlementTransfersForCurrentUser(
    String groupId,
  ) {
    final balances = calculateBalances(groupId);
    final debtors = balances.entries
        .where((e) => e.value < -0.01)
        .map((e) => _BalanceEntry(e.key, -e.value))
        .toList();
    final creditors = balances.entries
        .where((e) => e.value > 0.01)
        .map((e) => _BalanceEntry(e.key, e.value))
        .toList();
    debtors.sort((a, b) => b.amount.compareTo(a.amount));
    creditors.sort((a, b) => b.amount.compareTo(a.amount));
    final List<SettlementTransfer> result = [];
    int d = 0, c = 0;
    while (d < debtors.length && c < creditors.length) {
      final debtor = debtors[d];
      final creditor = creditors[c];
      final amount = (debtor.amount < creditor.amount
          ? debtor.amount
          : creditor.amount);
      if (amount < 0.01) break;
      if (debtor.id == _currentUserId) {
        result.add(
          SettlementTransfer(
            creditorPhone: _phoneForUid(creditor.id),
            creditorDisplayName: getMemberDisplayNameById(creditor.id),
            amount: amount,
          ),
        );
      }
      debtor.amount -= amount;
      creditor.amount -= amount;
      if (debtor.amount < 0.01) d++;
      if (creditor.amount < 0.01) c++;
    }
    return result;
  }

  // ============================================================
  // PAYMENT ATTEMPTS
  // ============================================================

  List<PaymentAttempt> getPaymentAttempts(String groupId) =>
      _settlementRepo.getPaymentAttempts(groupId);

  Future<void> loadPaymentAttempts(String groupId) async {
    final cycle = getActiveCycle(groupId);
    _settlementRepo.startListening(groupId, cycle.id);
  }

  PaymentAttempt? getPaymentAttemptForRoute(String groupId, String fromId, String toId) {
    final attempts = _paymentAttemptsByGroup[groupId] ?? [];
    try {
      return attempts.firstWhere(
        (a) => a.fromMemberId == fromId && a.toMemberId == toId,
      );
    } catch (_) {
      return null;
    }
  }

  Future<PaymentAttempt> getOrCreatePaymentAttempt({
    required String groupId,
    required String fromMemberId,
    required String toMemberId,
    required int amountMinor,
    required String currencyCode,
  }) async {
    final existing = getPaymentAttemptForRoute(groupId, fromMemberId, toMemberId);
    if (existing != null) return existing;

    final cycle = getActiveCycle(groupId);
    final id = await createPaymentAttempt(
      groupId: groupId,
      cycleId: cycle.id,
      amount: MoneyConversion.minorToDisplay(amountMinor, currencyCode),
      fromMemberId: fromMemberId,
      toMemberId: toMemberId,
      currencyCode: currencyCode,
    );
    
    // Create local stub until snapshot arrives
    return PaymentAttempt(
      id: id,
      groupId: groupId,
      cycleId: cycle.id,
      fromMemberId: fromMemberId,
      toMemberId: toMemberId,
      amountMinor: amountMinor,
      currencyCode: currencyCode,
      status: PaymentAttemptStatus.notStarted,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  double getGroupPendingAmount(String groupId) {
    final cycle = getActiveCycle(groupId);
    final members = getMembersForGroup(groupId);
    final currencyCode = getGroup(groupId)?.currencyCode ?? 'INR';
    final netBalances = SettlementEngine.computeNetBalances(cycle.expenses, members, currencyCode: currencyCode);
    final myBalanceMinor = netBalances[currentUserId] ?? 0;
    return myBalanceMinor < 0 
        ? MoneyConversion.minorToDisplay(-myBalanceMinor, currencyCode) 
        : 0.0;
  }


  Future<String> createPaymentAttempt({
    required String groupId,
    required String cycleId,
    required double amount,
    required String fromMemberId,
    required String toMemberId,
    required String currencyCode,
    String? upiId,
  }) =>
      _settlementRepo.createPaymentAttempt(
        groupId: groupId,
        cycleId: cycleId,
        amount: amount,
        fromMemberId: fromMemberId,
        toMemberId: toMemberId,
        currencyCode: currencyCode,
        upiId: upiId,
      );

  Future<void> confirmPaymentReceived(String groupId, String attemptId) =>
      _settlementRepo.confirmPaymentReceived(groupId, attemptId);


  Future<void> markAssetTransfer(String groupId, String attemptId) =>
      _settlementRepo.markAssetTransfer(groupId, attemptId);

  bool isFullySettledEmitted(String cycleId) =>
      _settlementRepo.isFullySettledEmitted(cycleId);
  void markFullySettledEmitted(String cycleId) =>
      _settlementRepo.markFullySettledEmitted(cycleId);
  void clearFullySettledEmitted() => _settlementRepo.clearFullySettledEmitted();

  Future<void> markPaymentInitiated(String groupId, String attemptId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    // Guard: can only initiate from notStarted.
    final current = _paymentAttemptsByGroup[groupId]?.firstWhere(
      (a) => a.id == attemptId,
      orElse: () => PaymentAttempt(
        id: '',
        groupId: '',
        cycleId: '',
        fromMemberId: '',
        toMemberId: '',
        amountMinor: 0,
        currencyCode: 'INR',
        status: PaymentAttemptStatus.notStarted,
        createdAt: 0,
      ),
    );
    if (current != null && current.status != PaymentAttemptStatus.notStarted) {
      debugPrint(
        'markPaymentInitiated: skipped (already ${current.status.firestoreValue})',
      );
      return; // idempotent — already past this state
    }
    await SupabaseService.instance.updatePaymentAttemptStatus(
      groupId,
      attemptId,
      PaymentAttemptStatus.initiated.firestoreValue,
      initiatedAt: now,
    );
    _updateLocalAttemptStatus(
      groupId,
      attemptId,
      PaymentAttemptStatus.initiated,
      initiatedAt: now,
    );
    _logSettlementEvent(
      groupId,
      SettlementEventType.paymentInitiated,
      amountMinor: current?.amountMinor,
      paymentAttemptId: attemptId,
    );
  }

  Future<void> markPaymentConfirmedByPayer(
    String groupId,
    String attemptId, {
    String? upiTransactionId,
    String? upiResponseCode,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    // Guard: payer can only confirm from initiated or notStarted.
    // confirmedByPayer/receiver/cashConfirmed are terminal — never regress.
    final current = _paymentAttemptsByGroup[groupId]?.firstWhere(
      (a) => a.id == attemptId,
      orElse: () => PaymentAttempt(
        id: '',
        groupId: '',
        cycleId: '',
        fromMemberId: '',
        toMemberId: '',
        amountMinor: 0,
        currencyCode: 'INR',
        status: PaymentAttemptStatus.notStarted,
        createdAt: 0,
      ),
    );
    if (current != null && current.status.isSettled) {
      debugPrint(
        'markPaymentConfirmedByPayer: skipped (already settled: ${current.status.firestoreValue})',
      );
      return; // idempotent — already settled
    }
    if (current != null &&
        current.status != PaymentAttemptStatus.notStarted &&
        current.status != PaymentAttemptStatus.initiated) {
      throw StateError(
        'Invalid transition: cannot move from ${current.status.firestoreValue} to confirmedByPayer.',
      );
    }
    await SupabaseService.instance.updatePaymentAttemptStatus(
      groupId,
      attemptId,
      PaymentAttemptStatus.confirmedByPayer.firestoreValue,
      confirmedAt: now,
      upiTransactionId: upiTransactionId,
      upiResponseCode: upiResponseCode,
    );
    _updateLocalAttemptStatus(
      groupId,
      attemptId,
      PaymentAttemptStatus.confirmedByPayer,
      confirmedAt: now,
      upiTransactionId: upiTransactionId,
      upiResponseCode: upiResponseCode,
    );
    _logSettlementEvent(
      groupId,
      SettlementEventType.paymentConfirmedByPayer,
      paymentAttemptId: attemptId,
    );
    _checkAndEmitFullySettled(groupId);
  }

  Future<void> markPaymentConfirmedByReceiver(
    String groupId,
    String attemptId,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    // Guard: receiver can only confirm from confirmedByPayer.
    // This ensures the payer has explicitly claimed to have paid before the receiver settles.
    final current = _paymentAttemptsByGroup[groupId]?.firstWhere(
      (a) => a.id == attemptId,
      orElse: () => PaymentAttempt(
        id: '',
        groupId: '',
        cycleId: '',
        fromMemberId: '',
        toMemberId: '',
        amountMinor: 0,
        currencyCode: 'INR',
        status: PaymentAttemptStatus.notStarted,
        createdAt: 0,
      ),
    );
    if (current != null &&
        current.status == PaymentAttemptStatus.confirmedByReceiver) {
      debugPrint(
        'markPaymentConfirmedByReceiver: skipped (already confirmedByReceiver)',
      );
      return; // idempotent
    }
    if (current != null &&
        current.status != PaymentAttemptStatus.confirmedByPayer) {
      throw StateError(
        'Invalid transition: receiver cannot confirm from ${current.status.firestoreValue}. '
        'Payer must confirm first (confirmedByPayer).',
      );
    }
    await SupabaseService.instance.updatePaymentAttemptStatus(
      groupId,
      attemptId,
      PaymentAttemptStatus.confirmedByReceiver.firestoreValue,
      confirmedAt: now,
    );
    _updateLocalAttemptStatus(
      groupId,
      attemptId,
      PaymentAttemptStatus.confirmedByReceiver,
      confirmedAt: now,
    );
    final attempt = _paymentAttemptsByGroup[groupId]?.firstWhere(
      (a) => a.id == attemptId,
      orElse: () => PaymentAttempt(
        id: '',
        groupId: '',
        cycleId: '',
        fromMemberId: '',
        toMemberId: '',
        amountMinor: 0,
        currencyCode: 'INR',
        status: PaymentAttemptStatus.notStarted,
        createdAt: 0,
      ),
    );
    _logSettlementEvent(
      groupId,
      SettlementEventType.paymentConfirmedByReceiver,
      amountMinor: attempt?.amountMinor,
      paymentAttemptId: attemptId,
    );
    _checkAndEmitFullySettled(groupId);
  }

  Future<void> markPaymentDisputed(String groupId, String attemptId) async {
    await SupabaseService.instance.updatePaymentAttemptStatus(
      groupId,
      attemptId,
      PaymentAttemptStatus.disputed.firestoreValue,
    );

    _updateLocalAttemptStatus(
      groupId,
      attemptId,
      PaymentAttemptStatus.disputed,
    );
    _logSettlementEvent(
      groupId,
      SettlementEventType.paymentDisputed,
      paymentAttemptId: attemptId,
    );
  }

  Future<void> markPaymentAsCash(String groupId, String attemptId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await SupabaseService.instance.updatePaymentAttemptStatus(
      groupId,
      attemptId,
      PaymentAttemptStatus.cashPending.firestoreValue,
      initiatedAt: now,
    );

    _updateLocalAttemptStatus(
      groupId,
      attemptId,
      PaymentAttemptStatus.cashPending,
      initiatedAt: now,
    );

    final attempt = _paymentAttemptsByGroup[groupId]?.firstWhere(
      (a) => a.id == attemptId,
      orElse: () => PaymentAttempt(
        id: '',
        groupId: '',
        cycleId: '',
        fromMemberId: '',
        toMemberId: '',
        amountMinor: 0,
        currencyCode: 'INR',
        status: PaymentAttemptStatus.notStarted,
        createdAt: 0,
      ),
    );
    _logSettlementEvent(
      groupId,
      SettlementEventType.cashConfirmationRequested,
      amountMinor: attempt?.amountMinor,
      paymentAttemptId: attemptId,
    );
  }

  Future<void> confirmCashReceived(String groupId, String attemptId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await SupabaseService.instance.updatePaymentAttemptStatus(
      groupId,
      attemptId,
      PaymentAttemptStatus.cashConfirmed.firestoreValue,
      confirmedAt: now,
    );

    _updateLocalAttemptStatus(
      groupId,
      attemptId,
      PaymentAttemptStatus.cashConfirmed,
      confirmedAt: now,
    );

    final attempt = _paymentAttemptsByGroup[groupId]?.firstWhere(
      (a) => a.id == attemptId,
      orElse: () => PaymentAttempt(
        id: '',
        groupId: '',
        cycleId: '',
        fromMemberId: '',
        toMemberId: '',
        amountMinor: 0,
        currencyCode: 'INR',
        status: PaymentAttemptStatus.notStarted,
        createdAt: 0,
      ),
    );
    _logSettlementEvent(
      groupId,
      SettlementEventType.cashConfirmed,
      amountMinor: attempt?.amountMinor,
      paymentAttemptId: attemptId,
    );
    _checkAndEmitFullySettled(groupId);
  }

  void _updateLocalAttemptStatus(
    String groupId,
    String attemptId,
    PaymentAttemptStatus status, {
    int? initiatedAt,
    int? confirmedAt,
    String? upiTransactionId,
    String? upiResponseCode,
  }) {
    final attempts = _paymentAttemptsByGroup[groupId];
    if (attempts == null) return;

    final index = attempts.indexWhere((a) => a.id == attemptId);
    if (index == -1) return;

    attempts[index] = attempts[index].copyWith(
      status: status,
      initiatedAt: initiatedAt,
      confirmedAt: confirmedAt,
      upiTransactionId: upiTransactionId,
      upiResponseCode: upiResponseCode,
    );
    notifyListeners();
  }

  /// Phase 1 (Freeze): Sets the current cycle's status to settling. Creator-only.
  /// Makes the group passive immediately (cycle settling) and writes to Firestore.
  void settleAndRestartCycle(String groupId) {
    if (!isCreator(groupId, _currentUserId)) return;
    final meta = _groupMeta[groupId];
    if (meta == null) return;
    SupabaseService.instance.updateGroup(groupId, {'cycleStatus': 'settling'});
    _groupMeta[groupId] = _GroupMeta(
      activeCycleId: meta.activeCycleId,
      cycleStatus: 'settling',
      settlementRhythm: meta.settlementRhythm,
      settlementDay: meta.settlementDay,
    );
    _refreshGroupAmounts();
    _logSettlementEvent(groupId, SettlementEventType.cycleSettlementStarted);
    notifyListeners();
  }

  /// Archive & Restart: Moves current cycle expenses to settled_cycles, then starts new cycle. Creator-only.
  /// Works whether cycle is 'active' (e.g. from Settle now dialog) or 'settling' (e.g. after Pay via UPI).
  /// Throws if not creator or group meta missing so the UI can show an error.
  Future<void> archiveAndRestart(String groupId) async {
    if (!isCreator(groupId, _currentUserId)) {
      throw StateError(
        'Only the group creator can settle and start a new cycle.',
      );
    }
    final meta = _groupMeta[groupId];
    if (meta == null) {
      throw StateError('Group data not loaded. Pull to refresh or try again.');
    }

    // Call Cloud Function to perform the settlement atomically
    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'asia-south1',
      ).httpsCallable('settleAndRestart');
      final result = await callable.call({'groupId': groupId});

      final newCycleId = result.data['newCycleId'] as String;

      _groupMeta[groupId] = _GroupMeta(
        activeCycleId: newCycleId,
        cycleStatus: 'active',
      );
      _expensesByCycleId.remove(meta.activeCycleId);
      _expensesByCycleId[newCycleId] = [];
      _paymentAttemptsByGroup.remove(groupId);
      _fullySettledEmitted.remove(groupId);
      _refreshGroupAmounts();
      _logSettlementEvent(groupId, SettlementEventType.cycleArchived);
      notifyListeners();
    } catch (e) {
      debugPrint('Cloud Function settleAndRestart failed: $e');
      throw StateError('Failed to settle and restart: $e');
    }
  }

  /// Returns all closed cycles for the group, newest first (from Firestore settled_cycles).
  Future<List<Cycle>> getHistory(String groupId) async {
    try {
      final settledDocs = await SupabaseService.instance.getSettledCycles(
        groupId,
      );
      final List<Cycle> closed = [];
      for (final doc in settledDocs) {
        final data = doc.data();
        final cycleId = doc.id;
        final startDate = data['startDate'] as String? ?? '';
        final endDate = data['endDate'] as String? ?? '';
        final expenseDocs = await SupabaseService.instance
            .getSettledCycleExpenses(groupId, cycleId);
        final currencyCode = getGroup(groupId)?.currencyCode ?? 'INR';
        final expenses = expenseDocs
            .map(
              (d) => _expenseFromFirestore(
                d.data(),
                d.id,
                currencyCode: currencyCode,
              ),
            )
            .toList();
        closed.add(
          Cycle(
            id: cycleId,
            groupId: groupId,
            status: CycleStatus.closed,
            startDate: startDate,
            endDate: endDate,
            expenses: expenses,
          ),
        );
      }
      return closed;
    } catch (e) {
      debugPrint('CycleRepository.getHistory failed for $groupId: $e');
      return [];
    }
  }

  /// Stream of settlement events for a group (most recent first).
  Stream<List<SettlementEvent>> settlementEventsStream(String groupId) {
    return SupabaseService.instance
        .settlementEventsStream(groupId)
        .map(
          (list) =>
              list.map((data) => SettlementEvent.fromFirestore(data)).toList(),
        );
  }

  /// Get settlement events for a group (one-time fetch).
  Future<List<SettlementEvent>> getSettlementEvents(String groupId) async {
    final data = await SupabaseService.instance.getSettlementEvents(groupId);
    return data.map((d) => SettlementEvent.fromFirestore(d)).toList();
  }

  /// Compute pending settlement count (members who haven't completed payment).
  int getPendingSettlementCount(String groupId) {
    final attempts = _paymentAttemptsByGroup[groupId] ?? [];
    return attempts.where((a) => !a.status.isFullyConfirmed).length;
  }

  /// Remaining balance for a member (positive = owed to them, negative = they owe).
  /// Uses net from expenses adjusted by all fully confirmed payments.
  double getRemainingBalance(String groupId, String memberId) {
    final currencyCode = getGroup(groupId)?.currencyCode ?? 'INR';
    final netMinor = getNetBalancesAfterSettlementsMinor(groupId);
    return MoneyConversion.minorToDisplay(netMinor[memberId] ?? 0, currencyCode);
  }

  /// Total amount this member has paid in settlement (marked as paid or confirmed).
  /// Used so the summary card can show "Settled ₹X" alongside "You Paid" (expenses).
  double getSettlementPaidByMember(String groupId, String memberId) {
    final currencyCode = getGroup(groupId)?.currencyCode ?? 'INR';
    final attempts = _paymentAttemptsByGroup[groupId] ?? [];
    int totalMinor = 0;
    for (final a in attempts) {
      if (a.fromMemberId == memberId && a.status.isSettled) {
        totalMinor += a.amountMinor;
      }
    }
    return MoneyConversion.minorToDisplay(totalMinor, currencyCode);
  }

  /// True when remaining balances (after confirmed payments) are zero for everyone.
  bool isFullySettled(String groupId) {
    final currencyCode = getGroup(groupId)?.currencyCode ?? 'INR';
    final net = getNetBalancesAfterSettlementsMinor(groupId);
    final routes = SettlementEngine.computePaymentRoutes(net, currencyCode);
    return routes.isEmpty;
  }

  final Set<String> _fullySettledEmitted = {};

  void _checkAndEmitFullySettled(String groupId) {
    if (_fullySettledEmitted.contains(groupId)) return;

    final meta = _groupMeta[groupId];
    if (meta == null || meta.cycleStatus != 'settling') return;

    if (isFullySettled(groupId)) {
      _fullySettledEmitted.add(groupId);
      _logSettlementEvent(groupId, SettlementEventType.cycleFullySettled);
      notifyListeners();
    }
  }

  void _logSettlementEvent(
    String groupId,
    SettlementEventType type, {
    int? amountMinor,
    String? paymentAttemptId,
    int? pendingCount,
  }) {
    final currencyCode = getGroup(groupId)?.currencyCode;
    SupabaseService.instance
        .addSettlementEvent(
          groupId,
          type: type.firestoreValue,
          amountMinor: amountMinor,
          currencyCode: currencyCode,
          paymentAttemptId: paymentAttemptId,
          pendingCount: pendingCount,
        )
        .catchError((e) {
          debugPrint('CycleRepository._logSettlementEvent failed: $e');
        });
  }

  final Map<String, DateTime> _lastPendingReminderDate = {};

  /// Check if a pending reminder should be emitted for this group today.
  /// Emits a "X members still pending settlement" event once per day when in settling mode.
  Future<void> checkAndEmitPendingReminder(String groupId) async {
    final meta = _groupMeta[groupId];
    if (meta == null || meta.cycleStatus != 'settling') return;

    final (_, pendingCount, _) = getMemberSettlementStatus(groupId);
    if (pendingCount == 0) return;

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final lastEmitted = _lastPendingReminderDate[groupId];

    if (lastEmitted != null && !lastEmitted.isBefore(todayDate)) {
      return;
    }

    final events = await SupabaseService.instance.getSettlementEvents(groupId);
    for (final data in events) {
      if (data['type'] == 'pending_reminder') {
        final ts = data['timestamp'] as int? ?? 0;
        final eventDate = DateTime.fromMillisecondsSinceEpoch(ts);
        final eventDay = DateTime(
          eventDate.year,
          eventDate.month,
          eventDate.day,
        );
        if (!eventDay.isBefore(todayDate)) {
          _lastPendingReminderDate[groupId] = todayDate;
          return;
        }
        break;
      }
    }

    _logSettlementEvent(
      groupId,
      SettlementEventType.pendingReminder,
      pendingCount: pendingCount,
    );
    _lastPendingReminderDate[groupId] = todayDate;
  }

  /// Get member settlement status: returns (settledCount, totalWithDues, pendingMemberIds).
  /// A member is "settled" if all their outgoing payment routes are confirmed.
  /// Members with no dues (net balance >= 0) are not counted.
  (int settled, int total, List<String> pendingIds) getMemberSettlementStatus(
    String groupId,
  ) {
    final cycle = getActiveCycle(groupId);
    final members = getMembersForGroup(groupId);
    if (members.isEmpty) return (0, 0, []);

    final currencyCode = getGroup(groupId)?.currencyCode ?? 'INR';
    final netBalances = SettlementEngine.computeNetBalances(
      cycle.expenses,
      members,
      currencyCode: currencyCode,
    );
    final routes = SettlementEngine.computePaymentRoutes(netBalances, currencyCode);
    final attempts = _paymentAttemptsByGroup[groupId] ?? [];

    final membersWithDues = <String>{};
    final memberRoutes = <String, List<PaymentRoute>>{};

    for (final route in routes) {
      membersWithDues.add(route.fromMemberId);
      memberRoutes.putIfAbsent(route.fromMemberId, () => []).add(route);
    }

    if (membersWithDues.isEmpty) return (0, 0, []);

    int settledCount = 0;
    final pendingIds = <String>[];

    for (final memberId in membersWithDues) {
      final myRoutes = memberRoutes[memberId] ?? [];
      bool allSettled = true;

      for (final route in myRoutes) {
        final attempt = attempts.firstWhere(
          (a) =>
              a.fromMemberId == route.fromMemberId &&
              a.toMemberId == route.toMemberId,
          orElse: () => PaymentAttempt(
            id: '',
            groupId: '',
            cycleId: '',
            fromMemberId: '',
            toMemberId: '',
            amountMinor: 0,
            currencyCode: 'INR',
            status: PaymentAttemptStatus.notStarted,
            createdAt: 0,
          ),
        );
        if (!attempt.status.isFullyConfirmed) {
          allSettled = false;
          break;
        }
      }

      if (allSettled) {
        settledCount++;
      } else {
        pendingIds.add(memberId);
      }
    }

    return (settledCount, membersWithDues.length, pendingIds);
  }

  /// Check if a specific member has completed all their payment obligations.
  bool isMemberSettled(String groupId, String memberId) {
    final cycle = getActiveCycle(groupId);
    final members = getMembersForGroup(groupId);
    if (members.isEmpty) return true;

    final currencyCode = getGroup(groupId)?.currencyCode ?? 'INR';
    final netBalances = SettlementEngine.computeNetBalances(
      cycle.expenses,
      members,
      currencyCode: currencyCode,
    );
    final routes = SettlementEngine.computePaymentRoutes(netBalances, currencyCode);
    final myRoutes = routes.where((r) => r.fromMemberId == memberId).toList();

    if (myRoutes.isEmpty) return true;

    final attempts = _paymentAttemptsByGroup[groupId] ?? [];

    for (final route in myRoutes) {
      final attempt = attempts.firstWhere(
        (a) =>
            a.fromMemberId == route.fromMemberId &&
            a.toMemberId == route.toMemberId,
        orElse: () => PaymentAttempt(
          id: '',
          groupId: '',
          cycleId: '',
          fromMemberId: '',
          toMemberId: '',
          amountMinor: 0,
          currencyCode: 'INR',
          status: PaymentAttemptStatus.notStarted,
          createdAt: 0,
        ),
      );
      if (!attempt.status.isFullyConfirmed) return false;
    }

    return true;
  }

  static String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  static String _nextCycleId() =>
      'c_${DateTime.now().millisecondsSinceEpoch}';
}

class _GroupMeta {
  final String activeCycleId;
  final String cycleStatus;
  final String settlementRhythm;
  final int settlementDay;

  _GroupMeta({
    required this.activeCycleId,
    required this.cycleStatus,
    this.settlementRhythm = 'weekly',
    this.settlementDay = 0,
  });
}

class _BalanceEntry {
  final String id;
  double amount;
  _BalanceEntry(this.id, this.amount);
}
