import 'package:cloud_firestore/cloud_firestore.dart';

import 'data_encryption_service.dart';

abstract class DocView {
  String get id;
  Map<String, dynamic> data();
}

class _SnapshotDocView implements DocView {
  _SnapshotDocView(this._doc);
  final QueryDocumentSnapshot<Map<String, dynamic>> _doc;
  @override
  String get id => _doc.id;
  @override
  Map<String, dynamic> data() => _doc.data();
}

class _DecryptedDocView implements DocView {
  _DecryptedDocView(this.id, this._data);
  @override
  final String id;
  final Map<String, dynamic> _data;
  @override
  Map<String, dynamic> data() => _data;
}

/// Firestore collection and field names. Test mode; all writes use real User.uid.
class FirestorePaths {
  static const String users = 'users';
  static const String groups = 'groups';
  static const String expenses = 'expenses';
  static const String settledCycles = 'settled_cycles';
  static const String systemMessages = 'system_messages';
  static const String expenseRevisions = 'expense_revisions';
  static const String deletedExpenses = 'deleted_expenses';
  static const String paymentAttempts = 'payment_attempts';
  static const String settlementEvents = 'settlement_events';

  static String groupDoc(String groupId) => '$groups/$groupId';
  static String groupExpenses(String groupId) => '$groups/$groupId/$expenses';
  static String groupSystemMessages(String groupId) => '$groups/$groupId/$systemMessages';
  static String groupSettledCycle(String groupId, String cycleId) =>
      '$groups/$groupId/$settledCycles/$cycleId';
  static String groupSettledCycleExpenses(String groupId, String cycleId) =>
      '$groups/$groupId/$settledCycles/$cycleId/$expenses';
  static String groupExpenseRevisions(String groupId) => '$groups/$groupId/$expenseRevisions';
  static String groupDeletedExpenses(String groupId) => '$groups/$groupId/$deletedExpenses';
  static String groupPaymentAttempts(String groupId) => '$groups/$groupId/$paymentAttempts';
  static String groupSettlementEvents(String groupId) => '$groups/$groupId/$settlementEvents';
}

/// Low-level Firestore access for users, groups, and expenses.
/// All writes must use the authenticated User.uid (e.g. test number +91 79022 03218).
class FirestoreService {
  FirestoreService._();

  static final FirestoreService _instance = FirestoreService._();

  static FirestoreService get instance => _instance;

  DataEncryptionService? _encryption;
  void setEncryptionService(DataEncryptionService? s) => _encryption = s;

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  /// Set or merge user profile. Document ID = [uid].
  Future<void> setUser(String uid, {
    String? displayName,
    String? phoneNumber,
    String? photoURL,
    String? upiId,
    String? currencyCode,
  }) async {
    final ref = _firestore.collection(FirestorePaths.users).doc(uid);
    final data = <String, dynamic>{};
    if (displayName != null) data['displayName'] = displayName;
    if (phoneNumber != null) data['phoneNumber'] = phoneNumber;
    if (photoURL != null) data['photoURL'] = photoURL;
    if (upiId != null) data['upiId'] = upiId;
    if (currencyCode != null) data['currencyCode'] = currencyCode;
    if (data.isEmpty) return;
    if (_encryption != null) {
      await _encryption!.ensureUserKey();
    }
    final toSet = _encryption != null
        ? await _encryption!.encryptUserData(data)
        : data;
    await ref.set(toSet, SetOptions(merge: true));
  }

  /// Get user doc. Returns null if missing.
  Future<Map<String, dynamic>?> getUser(String uid) async {
    final snap = await _firestore.collection(FirestorePaths.users).doc(uid).get();
    final raw = snap.exists ? snap.data() : null;
    if (raw != null && _encryption != null) {
      await _encryption!.ensureUserKey();
      return _encryption!.decryptUserData(raw);
    }
    return raw;
  }

  /// Stream of a single user (for display name / phone).
  Stream<Map<String, dynamic>?> userStream(String uid) {
    return _firestore.collection(FirestorePaths.users).doc(uid).snapshots().asyncMap((s) async {
      final raw = s.exists ? s.data() : null;
      if (raw != null && _encryption != null) {
        await _encryption!.ensureUserKey();
        return _encryption!.decryptUserData(raw);
      }
      return raw;
    });
  }

  /// Create a group. [groupId] e.g. g_xxx. [creatorId] = Firebase UID.
  Future<void> createGroup(String groupId, {
    required String groupName,
    required String creatorId,
    String? activeCycleId,
    List<Map<String, String>>? pendingMembers,
    String? settlementRhythm,
    int? settlementDay,
    String? currencyCode,
  }) async {
    final ref = _firestore.doc(FirestorePaths.groupDoc(groupId));
    await ref.set({
      'groupName': groupName,
      'members': [creatorId],
      'creatorId': creatorId,
      'activeCycleId': activeCycleId ?? _nextCycleId(),
      'cycleStatus': 'active',
      'currencyCode': currencyCode ?? 'INR',
      if (pendingMembers != null && pendingMembers.isNotEmpty) 'pendingMembers': pendingMembers,
      if (settlementRhythm != null) 'settlementRhythm': settlementRhythm,
      if (settlementDay != null) 'settlementDay': settlementDay,
    });
  }

  static String _nextCycleId() => 'c_${DateTime.now().millisecondsSinceEpoch}';

  /// Stream of groups where [uid] is in members.
  Stream<List<DocView>> groupsStream(String uid) {
    return _firestore
        .collection(FirestorePaths.groups)
        .where('members', arrayContains: uid)
        .snapshots()
        .asyncMap((s) async {
          final docs = s.docs;
          if (_encryption != null && docs.isNotEmpty) {
            await _encryption!.ensureGroupKeys(docs.map((d) => d.id).toList());
            final decryptedDocs = await Future.wait(docs.map((d) async {
              final decrypted = await _encryption!.decryptGroupData(d.data(), d.id);
              return _DecryptedDocView(d.id, decrypted) as DocView;
            }));
            return decryptedDocs;
          }
          return docs.map((d) => _SnapshotDocView(d) as DocView).toList();
        });
  }

  /// Get a single group doc.
  Future<DocumentSnapshot<Map<String, dynamic>>> getGroup(String groupId) async {
    return _firestore.doc(FirestorePaths.groupDoc(groupId)).get();
  }

  /// Stream of groups where [phone] (normalized) is in pendingPhones - i.e. pending invitations.
  /// Note: No decryption attempted here since invited users don't have access to group keys yet.
  Stream<List<DocView>> pendingInvitationsStream(String phone) {
    final normalizedPhone = _normalizePhone(phone);
    return _firestore
        .collection(FirestorePaths.groups)
        .where('pendingPhones', arrayContains: normalizedPhone)
        .snapshots()
        .map((s) => s.docs.map((d) => _SnapshotDocView(d) as DocView).toList());
  }

  /// Accept an invitation: move user from pending to members atomically.
  /// Handles both new (unencrypted List) and legacy (encrypted String) pendingMembers.
  /// All cleanup happens in a single transaction - no encryption keys required.
  Future<void> acceptInvitation(String groupId, String uid, String phone, {String? userName}) async {
    final normalizedPhone = _normalizePhone(phone);
    final ref = _firestore.doc(FirestorePaths.groupDoc(groupId));
    
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data()!;
      
      final members = List<String>.from(data['members'] as List? ?? []);
      if (members.contains(uid)) return;
      
      List<String> pendingPhones = List<String>.from(data['pendingPhones'] as List? ?? []);
      pendingPhones.remove(normalizedPhone);
      members.add(uid);
      
      final rawPending = data['pendingMembers'];
      List<Map<String, dynamic>> pendingList = _extractPendingMembersList(rawPending);
      pendingList.removeWhere((e) => _normalizePhone(e['phone'] ?? '') == normalizedPhone);
      
      final Map<String, dynamic> updates = {
        'members': members,
        'pendingPhones': pendingPhones,
        'pendingMembers': pendingList,
      };
      
      tx.update(ref, updates);
    });
    
    if (userName != null && userName.isNotEmpty) {
      await addSystemMessage(groupId, type: 'joined', userName: userName, odId: uid);
    }
  }

  /// Decline an invitation: just remove from pendingMembers and add a system message.
  Future<void> declineInvitation(String groupId, String phone, {String? userName}) async {
    await removePendingMemberFromGroup(groupId, phone);
    if (userName != null && userName.isNotEmpty) {
      await addSystemMessage(groupId, type: 'declined', userName: userName);
    }
  }

  /// Add a system message to the group (e.g. "Alice joined", "Bob declined").
  Future<void> addSystemMessage(String groupId, {
    required String type,
    String userName = '',
    String odId = '',
  }) async {
    final now = DateTime.now();
    final id = 'sys_${now.millisecondsSinceEpoch}';
    final ref = _firestore.collection(FirestorePaths.groupSystemMessages(groupId)).doc(id);
    await ref.set({
      'id': id,
      'type': type,
      'userId': odId,
      'userName': userName,
      'timestamp': now.millisecondsSinceEpoch,
    });
  }

  /// Stream of system messages for a group.
  Stream<List<Map<String, dynamic>>> systemMessagesStream(String groupId) {
    return _firestore
        .collection(FirestorePaths.groupSystemMessages(groupId))
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs.map((d) => d.data()).toList());
  }

  /// Add a settlement event to the group activity feed.
  Future<void> addSettlementEvent(
    String groupId, {
    required String type,
    int? amountMinor,
    String? paymentAttemptId,
    int? pendingCount,
  }) async {
    final now = DateTime.now();
    final id = 'se_${now.millisecondsSinceEpoch}';
    final ref = _firestore.collection(FirestorePaths.groupSettlementEvents(groupId)).doc(id);
    await ref.set({
      'id': id,
      'type': type,
      if (amountMinor != null) 'amountMinor': amountMinor,
      'timestamp': now.millisecondsSinceEpoch,
      if (paymentAttemptId != null) 'paymentAttemptId': paymentAttemptId,
      if (pendingCount != null) 'pendingCount': pendingCount,
    });
  }

  /// Stream of settlement events for a group (most recent first).
  Stream<List<Map<String, dynamic>>> settlementEventsStream(String groupId) {
    return _firestore
        .collection(FirestorePaths.groupSettlementEvents(groupId))
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots()
        .map((s) => s.docs.map((d) => d.data()).toList());
  }

  /// Get settlement events for a group (one-time fetch).
  Future<List<Map<String, dynamic>>> getSettlementEvents(String groupId) async {
    final snap = await _firestore
        .collection(FirestorePaths.groupSettlementEvents(groupId))
        .orderBy('timestamp', descending: true)
        .limit(20)
        .get();
    return snap.docs.map((d) => d.data()).toList();
  }

  static const int _deleteBatchSize = 500;

  /// Deletes all documents in [ref] in batches (Firestore batch limit 500).
  Future<void> _deleteCollection(CollectionReference<Map<String, dynamic>> ref) async {
    Query<Map<String, dynamic>> query = ref.limit(_deleteBatchSize);
    while (true) {
      final snap = await query.get();
      if (snap.docs.isEmpty) break;
      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      if (snap.docs.length < _deleteBatchSize) break;
    }
  }

  /// Deletes the group and all its data. Group document is deleted first so that any late or
  /// pending write to a subcollection is rejected by rules (create/update allowed only when group
  /// exists), preventing an empty document from being recreated. Then subcollections are deleted
  /// (rules allow read/delete when group does not exist for cleanup).
  /// Only the creator should call this.
  Future<void> deleteGroup(String groupId) async {
    final groupRef = _firestore.doc(FirestorePaths.groupDoc(groupId));
    final settledSnap = await _firestore
        .doc(FirestorePaths.groupDoc(groupId))
        .collection(FirestorePaths.settledCycles)
        .get();
    await groupRef.delete();
    await _deleteCollection(_firestore.collection(FirestorePaths.groupExpenses(groupId)));
    for (final cycleDoc in settledSnap.docs) {
      await _deleteCollection(_firestore.collection(
          FirestorePaths.groupSettledCycleExpenses(groupId, cycleDoc.id)));
      await cycleDoc.reference.delete();
    }
  }

  /// Update group fields (e.g. cycleStatus, activeCycleId).
  Future<void> updateGroup(String groupId, Map<String, dynamic> updates) async {
    Map<String, dynamic> toWrite = updates;
    if (_encryption != null && updates.isNotEmpty) {
      await _encryption!.ensureGroupKey(groupId);
      toWrite = await _encryption!.encryptGroupDataWithKey(groupId, updates);
    }
    await _firestore.doc(FirestorePaths.groupDoc(groupId)).update(toWrite);
  }

  /// Add [uid] to group.members if not already present.
  Future<void> addMemberToGroup(String groupId, String uid) async {
    final ref = _firestore.doc(FirestorePaths.groupDoc(groupId));
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data()!;
      final members = List<String>.from(data['members'] as List? ?? []);
      if (!members.contains(uid)) {
        members.add(uid);
        tx.update(ref, {'members': members});
      }
    });
  }

  /// Add a pending member (phone + name) when inviting by phone (no UID yet).
  /// Uses unencrypted pendingMembers with schema: { phone, name, invitedAt, invitedBy }
  Future<void> addPendingMemberToGroup(String groupId, String phone, String name, {String? invitedBy}) async {
    final normalizedPhone = _normalizePhone(phone);
    final ref = _firestore.doc(FirestorePaths.groupDoc(groupId));
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data()!;
      
      List<Map<String, dynamic>> list = _extractPendingMembersList(data['pendingMembers']);
      List<String> pendingPhones = List<String>.from(data['pendingPhones'] as List? ?? []);
      
      if (!list.any((e) => _normalizePhone(e['phone'] ?? '') == normalizedPhone)) {
        list.add({
          'phone': phone,
          'name': name,
          'invitedAt': DateTime.now().millisecondsSinceEpoch,
          'invitedBy': invitedBy ?? '',
        });
        if (!pendingPhones.contains(normalizedPhone)) {
          pendingPhones.add(normalizedPhone);
        }
        tx.update(ref, {'pendingMembers': list, 'pendingPhones': pendingPhones});
      }
    });
  }
  
  /// Extracts pendingMembers list, handling legacy encrypted data gracefully.
  /// If data is a String (legacy encrypted), returns empty list - pendingPhones is source of truth.
  static List<Map<String, dynamic>> _extractPendingMembersList(dynamic rawPending) {
    if (rawPending is List) {
      return List<Map<String, dynamic>>.from(
        rawPending.map((e) => Map<String, dynamic>.from(e as Map)),
      );
    }
    return [];
  }

  static String _normalizePhone(String raw) {
    final trimmed = raw.trim();
    if (trimmed.startsWith('+')) {
      return trimmed.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    }
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 10) return digits.substring(digits.length - 10);
    return digits;
  }

  /// Remove a member UID from group.
  Future<void> removeMemberFromGroup(String groupId, String uid) async {
    final ref = _firestore.doc(FirestorePaths.groupDoc(groupId));
    await ref.update({
      'members': FieldValue.arrayRemove([uid]),
    });
  }

  /// Remove a pending member by phone.
  /// Handles legacy encrypted pendingMembers by treating them as empty list.
  Future<void> removePendingMemberFromGroup(String groupId, String phone) async {
    final normalizedPhone = _normalizePhone(phone);
    final ref = _firestore.doc(FirestorePaths.groupDoc(groupId));
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data()!;
      
      List<Map<String, dynamic>> list = _extractPendingMembersList(data['pendingMembers']);
      List<String> pendingPhones = List<String>.from(data['pendingPhones'] as List? ?? []);
      
      list.removeWhere((e) => _normalizePhone(e['phone'] ?? '') == normalizedPhone);
      pendingPhones.remove(normalizedPhone);
      
      tx.update(ref, {'pendingMembers': list, 'pendingPhones': pendingPhones});
    });
  }

  /// Add expense to group's current cycle (subcollection expenses).
  Future<void> addExpense(String groupId, Map<String, dynamic> expenseData) async {
    final id = expenseData['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString();
    Map<String, dynamic> toWrite = {...expenseData, 'id': id};
    if (_encryption != null) {
      await _encryption!.ensureGroupKey(groupId);
      toWrite = await _encryption!.encryptExpenseData(groupId, toWrite);
    }
    final ref = _firestore.collection(FirestorePaths.groupExpenses(groupId)).doc(id);
    await ref.set(toWrite);
  }

  /// Update expense in current cycle.
  Future<void> updateExpense(String groupId, String expenseId, Map<String, dynamic> updates) async {
    Map<String, dynamic> toWrite = updates;
    if (_encryption != null && updates.isNotEmpty) {
      await _encryption!.ensureGroupKey(groupId);
      toWrite = await _encryption!.encryptExpenseData(groupId, updates);
    }
    await _firestore
        .collection(FirestorePaths.groupExpenses(groupId))
        .doc(expenseId)
        .update(toWrite);
  }

  /// Soft-delete: marks expense as deleted (compensation model).
  /// The expense document remains but is marked deleted for audit trail.
  Future<void> markExpenseDeleted(String groupId, String expenseId) async {
    final ref = _firestore.collection(FirestorePaths.groupDeletedExpenses(groupId)).doc(expenseId);
    await ref.set({'deletedAt': FieldValue.serverTimestamp()});
  }

  /// Hard-delete expense from current cycle (legacy method, use markExpenseDeleted for audit trail).
  Future<void> deleteExpense(String groupId, String expenseId) async {
    await _firestore
        .collection(FirestorePaths.groupExpenses(groupId))
        .doc(expenseId)
        .delete();
  }

  /// Add an expense revision record (for edit tracking).
  Future<void> addExpenseRevision(String groupId, {
    required String expenseId,
    String? replacesExpenseId,
  }) async {
    final ref = _firestore.collection(FirestorePaths.groupExpenseRevisions(groupId)).doc(expenseId);
    await ref.set({
      'expenseId': expenseId,
      if (replacesExpenseId != null) 'replacesExpenseId': replacesExpenseId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Stream of expense revisions for a group (for lifecycle tracking).
  Stream<List<Map<String, dynamic>>> expenseRevisionsStream(String groupId) {
    return _firestore
        .collection(FirestorePaths.groupExpenseRevisions(groupId))
        .snapshots()
        .map((s) => s.docs.map((d) => {'id': d.id, ...d.data()}).toList());
  }

  /// Stream of deleted expense IDs for a group.
  Stream<Set<String>> deletedExpenseIdsStream(String groupId) {
    return _firestore
        .collection(FirestorePaths.groupDeletedExpenses(groupId))
        .snapshots()
        .map((s) => s.docs.map((d) => d.id).toSet());
  }

  /// Get all expense revisions for a group (one-time fetch).
  Future<List<Map<String, dynamic>>> getExpenseRevisions(String groupId) async {
    final snap = await _firestore.collection(FirestorePaths.groupExpenseRevisions(groupId)).get();
    return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  /// Get all deleted expense IDs for a group (one-time fetch).
  Future<Set<String>> getDeletedExpenseIds(String groupId) async {
    final snap = await _firestore.collection(FirestorePaths.groupDeletedExpenses(groupId)).get();
    return snap.docs.map((d) => d.id).toSet();
  }

  /// Stream of current-cycle expenses for a group. Sorted by dateSortKey (then date string) in memory.
  Stream<List<DocView>> expensesStream(String groupId) {
    return _firestore
        .collection(FirestorePaths.groupExpenses(groupId))
        .snapshots()
        .asyncMap((s) async {
          final docs = s.docs;
          if (_encryption != null && docs.isNotEmpty) {
            await _encryption!.ensureGroupKey(groupId);
            final decrypted = await Future.wait(docs.map((d) async {
              final data = await _encryption!.decryptExpenseData(d.data(), groupId);
              return _DecryptedDocView(d.id, data) as DocView;
            }));
            decrypted.sort((a, b) => _compareExpenseDocs(a, b));
            return decrypted;
          }
          final list = docs.map((d) => _SnapshotDocView(d) as DocView).toList();
          list.sort((a, b) => _compareExpenseDocs(a, b));
          return list;
        });
  }

  static int _compareExpenseDocs(DocView a, DocView b) {
    final ka = a.data()['dateSortKey'] as int?;
    final kb = b.data()['dateSortKey'] as int?;
    if (ka != null && kb != null) return ka.compareTo(kb);
    if (ka != null) return -1;
    if (kb != null) return 1;
    final da = a.data()['date'] as String? ?? '';
    final db = b.data()['date'] as String? ?? '';
    return da.compareTo(db);
  }

  /// Write a settled cycle doc and copy current-cycle expenses into it; then clear current expenses.
  /// [cycleId] = group's current activeCycleId. Caller must set group's new activeCycleId and cycleStatus after.
  Future<void> archiveCycleExpenses(
    String groupId,
    String cycleId, {
    required String startDate,
    required String endDate,
  }) async {
    final batch = _firestore.batch();
    final currentRef = _firestore.collection(FirestorePaths.groupExpenses(groupId));
    final settledMetaRef = _firestore.doc(FirestorePaths.groupSettledCycle(groupId, cycleId));
    final settledExpensesRef =
        _firestore.collection(FirestorePaths.groupSettledCycleExpenses(groupId, cycleId));

    final snap = await currentRef.get();
    batch.set(settledMetaRef, {'startDate': startDate, 'endDate': endDate});
    for (final doc in snap.docs) {
      batch.set(settledExpensesRef.doc(doc.id), doc.data());
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  /// List settled cycle docs for a group (for history). Ordered by endDate descending.
  Future<List<DocView>> getSettledCycles(String groupId) async {
    final snap = await _firestore
        .doc(FirestorePaths.groupDoc(groupId))
        .collection(FirestorePaths.settledCycles)
        .orderBy('endDate', descending: true)
        .get();
    return snap.docs.map((d) => _SnapshotDocView(d) as DocView).toList();
  }

  /// Get expenses for a settled cycle.
  Future<List<DocView>> getSettledCycleExpenses(
    String groupId,
    String cycleId,
  ) async {
    final snap = await _firestore
        .collection(FirestorePaths.groupSettledCycleExpenses(groupId, cycleId))
        .get();
    final docs = snap.docs;
    if (_encryption != null && docs.isNotEmpty) {
      await _encryption!.ensureGroupKey(groupId);
      final decrypted = await Future.wait(docs.map((d) async {
        final data = await _encryption!.decryptExpenseData(d.data(), groupId);
        return _DecryptedDocView(d.id, data) as DocView;
      }));
      decrypted.sort((a, b) => _compareExpenseDocs(a, b));
      return decrypted;
    }
    final list = docs.map((d) => _SnapshotDocView(d) as DocView).toList();
    list.sort((a, b) => _compareExpenseDocs(a, b));
    return list;
  }

  // ============================================================
  // PAYMENT ATTEMPTS
  // ============================================================

  /// Create or update a payment attempt.
  Future<void> setPaymentAttempt(
    String groupId,
    String attemptId,
    Map<String, dynamic> data,
  ) async {
    final ref = _firestore
        .collection(FirestorePaths.groupPaymentAttempts(groupId))
        .doc(attemptId);
    await ref.set(data, SetOptions(merge: true));
  }

  /// Get all payment attempts for a group's current cycle.
  Future<List<DocView>> getPaymentAttempts(String groupId, String cycleId) async {
    final snap = await _firestore
        .collection(FirestorePaths.groupPaymentAttempts(groupId))
        .where('cycleId', isEqualTo: cycleId)
        .get();
    return snap.docs.map((d) => _SnapshotDocView(d) as DocView).toList();
  }

  /// Stream payment attempts for a group's current cycle.
  Stream<List<DocView>> paymentAttemptsStream(String groupId, String cycleId) {
    return _firestore
        .collection(FirestorePaths.groupPaymentAttempts(groupId))
        .where('cycleId', isEqualTo: cycleId)
        .snapshots()
        .map((snap) => snap.docs.map((d) => _SnapshotDocView(d) as DocView).toList());
  }

  /// Update payment attempt status.
  Future<void> updatePaymentAttemptStatus(
    String groupId,
    String attemptId,
    String status, {
    int? initiatedAt,
    int? confirmedAt,
    String? upiTransactionId,
    String? upiResponseCode,
  }) async {
    final ref = _firestore
        .collection(FirestorePaths.groupPaymentAttempts(groupId))
        .doc(attemptId);
    final data = <String, dynamic>{'status': status};
    if (initiatedAt != null) data['initiatedAt'] = initiatedAt;
    if (confirmedAt != null) data['confirmedAt'] = confirmedAt;
    if (upiTransactionId != null) data['upiTransactionId'] = upiTransactionId;
    if (upiResponseCode != null) data['upiResponseCode'] = upiResponseCode;
    await ref.update(data);
  }

  /// Delete all payment attempts for a cycle (called when archiving).
  Future<void> deletePaymentAttemptsForCycle(String groupId, String cycleId) async {
    final snap = await _firestore
        .collection(FirestorePaths.groupPaymentAttempts(groupId))
        .where('cycleId', isEqualTo: cycleId)
        .get();
    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // ============================================================
  // FCM TOKENS
  // ============================================================

  Future<void> storeFcmToken(String userId, String token, String platform) async {
    final tokenId = token.hashCode.toRadixString(16);
    final ref = _firestore
        .collection(FirestorePaths.users)
        .doc(userId)
        .collection('fcmTokens')
        .doc(tokenId);
    await ref.set({
      'token': token,
      'platform': platform,
      'createdAt': FieldValue.serverTimestamp(),
      'lastRefresh': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteFcmToken(String userId, String token) async {
    final tokenId = token.hashCode.toRadixString(16);
    final ref = _firestore
        .collection(FirestorePaths.users)
        .doc(userId)
        .collection('fcmTokens')
        .doc(tokenId);
    await ref.delete();
  }

}

