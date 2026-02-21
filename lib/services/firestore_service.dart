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

  DataEncryptionService? _encryption;
  void setEncryptionService(DataEncryptionService? s) => _encryption = s;

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  /// Set or merge user profile. Document ID = [uid].
  Future<void> setUser(String uid, {
    String? displayName,
    String? phoneNumber,
    String? photoURL,
    String? upiId,
  }) async {
    final ref = _firestore.collection(FirestorePaths.users).doc(uid);
    final data = <String, dynamic>{};
    if (displayName != null) data['displayName'] = displayName;
    if (phoneNumber != null) data['phoneNumber'] = phoneNumber;
    if (photoURL != null) data['photoURL'] = photoURL;
    if (upiId != null) data['upiId'] = upiId;
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
  }) async {
    final ref = _firestore.doc(FirestorePaths.groupDoc(groupId));
    await ref.set({
      'groupName': groupName,
      'members': [creatorId],
      'creatorId': creatorId,
      'activeCycleId': activeCycleId ?? _nextCycleId(),
      'cycleStatus': 'active',
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
  Future<void> addPendingMemberToGroup(String groupId, String phone, String name) async {
    final ref = _firestore.doc(FirestorePaths.groupDoc(groupId));
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data()!;
      List<Map<String, dynamic>> list = List<Map<String, dynamic>>.from(
        (data['pendingMembers'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)) ?? [],
      );
      if (!list.any((e) => e['phone'] == phone)) {
        list.add({'phone': phone, 'name': name});
        Map<String, dynamic> toWrite = {'pendingMembers': list};
        if (_encryption != null) {
          await _encryption!.ensureGroupKey(groupId);
          toWrite = await _encryption!.encryptGroupDataWithKey(groupId, toWrite);
        }
        tx.update(ref, toWrite);
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
      Map<String, dynamic> toWrite = {'pendingMembers': list};
      if (_encryption != null) {
        await _encryption!.ensureGroupKey(groupId);
        toWrite = await _encryption!.encryptGroupDataWithKey(groupId, toWrite);
      }
      tx.update(ref, toWrite);
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

  /// Delete expense from current cycle.
  Future<void> deleteExpense(String groupId, String expenseId) async {
    await _firestore
        .collection(FirestorePaths.groupExpenses(groupId))
        .doc(expenseId)
        .delete();
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
}
