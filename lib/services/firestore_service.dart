import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore collection and field names. Test mode; all writes use real User.uid.
class FirestorePaths {
  static const String users = 'users';
  static const String groups = 'groups';
  static const String expenses = 'expenses';
  static const String settledCycles = 'settled_cycles';

  static String groupDoc(String groupId) => '$groups/$groupId';
  static String groupExpenses(String groupId) => '$groups/$groupId/$expenses';
  static String groupSettledCycle(String groupId, String cycleId) =>
      '$groups/$groupId/$settledCycles/$cycleId';
  static String groupSettledCycleExpenses(String groupId, String cycleId) =>
      '$groups/$groupId/$settledCycles/$cycleId/$expenses';
}

/// Low-level Firestore access for users, groups, and expenses.
/// All writes must use the authenticated User.uid (e.g. test number +91 79022 03218).
class FirestoreService {
  FirestoreService._();

  static final FirestoreService _instance = FirestoreService._();

  static FirestoreService get instance => _instance;

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  /// Set or merge user profile. Document ID = [uid].
  Future<void> setUser(String uid, {
    String? displayName,
    String? phoneNumber,
    String? photoURL,
  }) async {
    final ref = _firestore.collection(FirestorePaths.users).doc(uid);
    final data = <String, dynamic>{};
    if (displayName != null) data['displayName'] = displayName;
    if (phoneNumber != null) data['phoneNumber'] = phoneNumber;
    if (photoURL != null) data['photoURL'] = photoURL;
    if (data.isEmpty) return;
    await ref.set(data, SetOptions(merge: true));
  }

  /// Get user doc. Returns null if missing.
  Future<Map<String, dynamic>?> getUser(String uid) async {
    final snap = await _firestore.collection(FirestorePaths.users).doc(uid).get();
    return snap.exists ? snap.data() : null;
  }

  /// Stream of a single user (for display name / phone).
  Stream<Map<String, dynamic>?> userStream(String uid) {
    return _firestore.collection(FirestorePaths.users).doc(uid).snapshots().map((s) {
      return s.exists ? s.data() : null;
    });
  }

  /// Create a group. [groupId] e.g. g_xxx. [creatorId] = Firebase UID.
  Future<void> createGroup(String groupId, {
    required String groupName,
    required String creatorId,
    String? activeCycleId,
    List<Map<String, String>>? pendingMembers,
  }) async {
    final ref = _firestore.doc(FirestorePaths.groupDoc(groupId));
    await ref.set({
      'groupName': groupName,
      'members': [creatorId],
      'creatorId': creatorId,
      'activeCycleId': activeCycleId ?? _nextCycleId(),
      'cycleStatus': 'active',
      if (pendingMembers != null && pendingMembers.isNotEmpty) 'pendingMembers': pendingMembers,
    });
  }

  static String _nextCycleId() => 'c_${DateTime.now().millisecondsSinceEpoch}';

  /// Stream of groups where [uid] is in members.
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> groupsStream(String uid) {
    return _firestore
        .collection(FirestorePaths.groups)
        .where('members', arrayContains: uid)
        .snapshots()
        .map((s) => s.docs);
  }

  /// Get a single group doc.
  Future<DocumentSnapshot<Map<String, dynamic>>> getGroup(String groupId) async {
    return _firestore.doc(FirestorePaths.groupDoc(groupId)).get();
  }

  /// Delete a group document. Only the creator should call this. Subcollections (expenses, settled_cycles) are not deleted.
  Future<void> deleteGroup(String groupId) async {
    await _firestore.doc(FirestorePaths.groupDoc(groupId)).delete();
  }

  /// Update group fields (e.g. cycleStatus, activeCycleId).
  Future<void> updateGroup(String groupId, Map<String, dynamic> updates) async {
    await _firestore.doc(FirestorePaths.groupDoc(groupId)).update(updates);
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
  Future<void> addPendingMemberToGroup(String groupId, String phone, String name) async {
    final ref = _firestore.doc(FirestorePaths.groupDoc(groupId));
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data()!;
      final list = List<Map<String, dynamic>>.from(
        (data['pendingMembers'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)) ?? [],
      );
      if (!list.any((e) => e['phone'] == phone)) {
        list.add({'phone': phone, 'name': name});
        tx.update(ref, {'pendingMembers': list});
      }
    });
  }

  /// Remove a member UID from group.
  Future<void> removeMemberFromGroup(String groupId, String uid) async {
    final ref = _firestore.doc(FirestorePaths.groupDoc(groupId));
    await ref.update({
      'members': FieldValue.arrayRemove([uid]),
    });
  }

  /// Remove a pending member by phone.
  Future<void> removePendingMemberFromGroup(String groupId, String phone) async {
    final ref = _firestore.doc(FirestorePaths.groupDoc(groupId));
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data()!;
      final list = List<Map<String, dynamic>>.from(
        (data['pendingMembers'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)) ?? [],
      );
      list.removeWhere((e) => e['phone'] == phone);
      tx.update(ref, {'pendingMembers': list});
    });
  }

  /// Add expense to group's current cycle (subcollection expenses).
  Future<void> addExpense(String groupId, Map<String, dynamic> expenseData) async {
    final id = expenseData['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString();
    final ref = _firestore.collection(FirestorePaths.groupExpenses(groupId)).doc(id);
    await ref.set({...expenseData, 'id': id});
  }

  /// Update expense in current cycle.
  Future<void> updateExpense(String groupId, String expenseId, Map<String, dynamic> updates) async {
    await _firestore
        .collection(FirestorePaths.groupExpenses(groupId))
        .doc(expenseId)
        .update(updates);
  }

  /// Delete expense from current cycle.
  Future<void> deleteExpense(String groupId, String expenseId) async {
    await _firestore
        .collection(FirestorePaths.groupExpenses(groupId))
        .doc(expenseId)
        .delete();
  }

  /// Stream of current-cycle expenses for a group. Sorted by date in memory to avoid index.
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> expensesStream(String groupId) {
    return _firestore
        .collection(FirestorePaths.groupExpenses(groupId))
        .snapshots()
        .map((s) {
          final docs = s.docs;
          docs.sort((a, b) {
            final da = a.data()['date'] as String? ?? '';
            final db = b.data()['date'] as String? ?? '';
            return da.compareTo(db);
          });
          return docs;
        });
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
  Future<List<DocumentSnapshot<Map<String, dynamic>>>> getSettledCycles(String groupId) async {
    final snap = await _firestore
        .doc(FirestorePaths.groupDoc(groupId))
        .collection(FirestorePaths.settledCycles)
        .orderBy('endDate', descending: true)
        .get();
    return snap.docs;
  }

  /// Get expenses for a settled cycle.
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> getSettledCycleExpenses(
    String groupId,
    String cycleId,
  ) async {
    final snap = await _firestore
        .collection(FirestorePaths.groupSettledCycleExpenses(groupId, cycleId))
        .get();
    final docs = snap.docs;
    docs.sort((a, b) {
      final da = a.data()['date'] as String? ?? '';
      final db = b.data()['date'] as String? ?? '';
      return da.compareTo(db);
    });
    return docs;
  }
}
