import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:cryptography/cryptography.dart';

const _prefix = 'e:';

final _aes = AesGcm.with256bits();

List<int> _decodeKey(String base64Key) {
  return base64.decode(base64Key);
}

String _encodeCiphertext(List<int> nonce, List<int> ciphertext, List<int> tag) {
  final bytes = [...nonce, ...ciphertext, ...tag];
  return _prefix + base64.encode(bytes);
}

Future<String> _encrypt(List<int> keyBytes, String plaintext) async {
  final key = SecretKey(keyBytes);
  final nonce = _aes.newNonce();
  final secretBox = await _aes.encrypt(
    utf8.encode(plaintext),
    secretKey: key,
    nonce: nonce,
  );
  return _encodeCiphertext(
    nonce,
    secretBox.cipherText,
    secretBox.mac.bytes,
  );
}

Future<String> _decrypt(List<int> keyBytes, String ciphertext) async {
  if (!ciphertext.startsWith(_prefix)) return ciphertext;
  final bytes = base64.decode(ciphertext.substring(_prefix.length));
  if (bytes.length < 12 + 16) return ciphertext;
  final nonce = bytes.sublist(0, 12);
  final tag = bytes.sublist(bytes.length - 16);
  final ct = bytes.sublist(12, bytes.length - 16);
  final secretBox = SecretBox(ct, nonce: nonce, mac: Mac(tag));
  final key = SecretKey(keyBytes);
  final decrypted = await _aes.decrypt(secretBox, secretKey: key);
  return utf8.decode(decrypted);
}

bool _isEncrypted(dynamic v) =>
    v is String && v.startsWith(_prefix) && v.length > _prefix.length;

class DataEncryptionService {
  DataEncryptionService({required this.region});

  final String region;
  List<int>? _userKey;
  final Map<String, List<int>> _groupKeys = {};

  Future<void> ensureUserKey() async {
    if (_userKey != null) return;
    final result = await FirebaseFunctions.instanceFor(region: region).httpsCallable('getUserEncryptionKey').call();
    final key = result.data['key'] as String?;
    if (key == null || key.isEmpty) return;
    _userKey = _decodeKey(key);
  }

  Future<void> ensureGroupKey(String groupId) async {
    if (_groupKeys.containsKey(groupId)) return;
    final result = await FirebaseFunctions.instanceFor(region: region).httpsCallable('getGroupEncryptionKey').call({'groupId': groupId});
    final key = result.data['key'] as String?;
    if (key == null || key.isEmpty) return;
    _groupKeys[groupId] = _decodeKey(key);
  }

  Future<void> ensureGroupKeys(List<String> groupIds) async {
    await Future.wait(groupIds.map((id) => ensureGroupKey(id)));
  }

  void clearKeys() {
    _userKey = null;
    _groupKeys.clear();
  }

  static const _userFields = ['displayName', 'phoneNumber', 'photoURL', 'upiId'];
  static const _groupFields = ['groupName'];
  static const _expenseFields = [
    'description', 'amount', 'date', 'dateSortKey', 'payerId',
    'participantIds', 'splits', 'splitType', 'category',
  ];
  static const _settledMetaFields = ['startDate', 'endDate'];

  Future<Map<String, dynamic>> _encryptMap(List<int>? key, Map<String, dynamic> data, List<String> fields) async {
    if (key == null) return data;
    final out = Map<String, dynamic>.from(data);
    for (final k in fields) {
      if (!out.containsKey(k)) continue;
      final v = out[k];
      if (v == null) continue;
      String plain;
      if (v is List || v is Map) {
        plain = jsonEncode(v);
      } else {
        plain = v.toString();
      }
      out[k] = await _encrypt(key, plain);
    }
    return out;
  }

  Future<Map<String, dynamic>> _decryptMap(List<int>? key, Map<String, dynamic> data, List<String> fields, dynamic Function(String, String) typeRestore) async {
    if (key == null) return _restoreTypes(data, fields, typeRestore);
    final out = Map<String, dynamic>.from(data);
    for (final k in fields) {
      if (!out.containsKey(k)) continue;
      final v = out[k];
      if (!_isEncrypted(v)) continue;
      final plain = await _decrypt(key, v as String);
      out[k] = plain;
    }
    return _restoreTypes(out, fields, typeRestore);
  }

  Map<String, dynamic> _restoreTypes(Map<String, dynamic> data, List<String> fields, dynamic Function(String, String) typeRestore) {
    final out = Map<String, dynamic>.from(data);
    for (final k in fields) {
      if (!out.containsKey(k)) continue;
      final v = out[k];
      if (v is! String) continue;
      out[k] = typeRestore(k, v);
    }
    return out;
  }

  static dynamic _userTypeRestore(String k, String v) {
    return v;
  }

  static dynamic _groupTypeRestore(String k, String v) {
    if (k == 'pendingMembers') {
      try {
        final list = jsonDecode(v) as List?;
        return list?.map((e) => Map<String, String>.from((e as Map).map((x, y) => MapEntry(x.toString(), y?.toString() ?? '')))).toList() ?? <Map<String, String>>[];
      } catch (_) {}
    }
    return v;
  }

  static dynamic _expenseTypeRestore(String k, String v) {
    if (k == 'amount') return num.tryParse(v) ?? 0.0;
    if (k == 'dateSortKey') return int.tryParse(v);
    if (k == 'participantIds') {
      try {
        final list = jsonDecode(v) as List?;
        return list?.map((e) => e?.toString()).whereType<String>().toList() ?? [];
      } catch (_) {}
    }
    if (k == 'splits') {
      try {
        final map = jsonDecode(v) as Map?;
        if (map == null) return null;
        return map.map((a, b) => MapEntry(a.toString(), (b is num) ? b.toDouble() : double.tryParse(b?.toString() ?? '') ?? 0.0));
      } catch (_) {}
    }
    return v;
  }

  Future<Map<String, dynamic>> encryptUserData(Map<String, dynamic> data) =>
      _encryptMap(_userKey, data, _userFields);

  Future<Map<String, dynamic>?> decryptUserData(Map<String, dynamic>? data) async {
    if (data == null) return null;
    return _decryptMap(_userKey, data, _userFields, (_, v) => v);
  }

  Future<Map<String, dynamic>> encryptGroupDataWithKey(String groupId, Map<String, dynamic> data) async {
    final key = _groupKeys[groupId];
    return _encryptMap(key, data, _groupFields);
  }

  Future<Map<String, dynamic>> decryptGroupData(Map<String, dynamic> data, String groupId) async {
    final key = _groupKeys[groupId];
    return _decryptMap(key, data, _groupFields, _groupTypeRestore);
  }

  Future<Map<String, dynamic>> encryptExpenseData(String groupId, Map<String, dynamic> data) async {
    final key = _groupKeys[groupId];
    final out = Map<String, dynamic>.from(data);
    for (final k in _expenseFields) {
      if (!out.containsKey(k)) continue;
      final v = out[k];
      if (v == null) continue;
      String plain;
      if (v is List || v is Map) {
        plain = jsonEncode(v);
      } else {
        plain = v.toString();
      }
      if (key != null) out[k] = await _encrypt(key, plain);
    }
    return out;
  }

  Future<Map<String, dynamic>> decryptExpenseData(Map<String, dynamic> data, String groupId) async {
    final key = _groupKeys[groupId];
    return _decryptMap(key, data, _expenseFields, _expenseTypeRestore);
  }

  Future<Map<String, dynamic>> encryptSettledMeta(String groupId, Map<String, dynamic> data) async {
    final key = _groupKeys[groupId];
    return _encryptMap(key, data, _settledMetaFields);
  }

  Future<Map<String, dynamic>> decryptSettledMeta(Map<String, dynamic> data, String groupId) async {
    final key = _groupKeys[groupId];
    return _decryptMap(key, data, _settledMetaFields, (_, v) => v);
  }
}
