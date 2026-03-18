import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/data_encryption_service.dart';
import '../services/firestore_service.dart';
import '../services/user_profile_cache.dart';
import '../services/feature_flag_service.dart';
import '../services/identity_service.dart';
import '../utils/app_logger.dart';
import './base_repository.dart';

class AuthRepository extends BaseRepository {
  AuthRepository._();
  static final AuthRepository _instance = AuthRepository._();
  static AuthRepository get instance => _instance;

  String _currentUserId = '';
  String _currentUserPhone = '';
  String _currentUserName = '';
  DataEncryptionService? _encryption;
  final Map<String, Map<String, dynamic>> _userCache = {};

  String get currentUserId => _currentUserId;
  String get currentUserPhone => _currentUserPhone;
  String get currentUserName => _currentUserName;
  DataEncryptionService? get encryption => _encryption;

  String? get currentUserPhotoURL =>
      _userCache[_currentUserId]?['photoURL'] as String?;

  String? get currentUserUpiId =>
      _userCache[_currentUserId]?['upiId'] as String?;

  String get currentUserCurrencyCode =>
      _userCache[_currentUserId]?['currencyCode'] as String? ?? 'INR';

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
        AppLogger.error('setGlobalProfile write failed', name: 'AuthRepository', error: e, stackTrace: st);
      });
      UserProfileCache.instance.save(
        userId: _currentUserId,
        displayName: _currentUserName,
        photoURL: currentUserPhotoURL,
        upiId: currentUserUpiId,
        phone: _currentUserPhone,
        currencyCode: currentUserCurrencyCode,
      );
    }
    notify();
  }

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
    FeatureFlagService.instance.refresh();
  }

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

  Future<void> continueAuthFromFirebaseUser() async {
    if (_currentUserId.isEmpty) return;
    _encryption = DataEncryptionService(region: 'asia-south1');
    try {
      await _encryption!.ensureUserKey();
    } catch (e) {
      debugPrint('AuthRepository encryption key fetch failed: $e');
      _encryption = null;
    }
    FirestoreService.instance.setEncryptionService(_encryption);
    _writeCurrentUserProfile().catchError((e, st) {
      AppLogger.error('continueAuthFromFirebaseUser write failed', name: 'AuthRepository', error: e, stackTrace: st);
    });
    _loadCurrentUserProfileFromFirestore();
    FeatureFlagService.instance.refresh();
    notify();
  }

  Future<void> _loadCurrentUserProfileFromFirestore() async {
    try {
      final u = await FirestoreService.instance.getUser(_currentUserId);
      if (u != null && _userCache.containsKey(_currentUserId)) {
        final cur = Map<String, dynamic>.from(_userCache[_currentUserId]!);
        if (u['photoURL'] != null) cur['photoURL'] = u['photoURL'];
        if (u['upiId'] != null) cur['upiId'] = u['upiId'];
        if (u['currencyCode'] != null) cur['currencyCode'] = u['currencyCode'];
        _userCache[_currentUserId] = cur;

        UserProfileCache.instance.save(
          userId: _currentUserId,
          displayName: _currentUserName,
          photoURL: u['photoURL'] as String?,
          upiId: u['upiId'] as String?,
          phone: _currentUserPhone,
          currencyCode: cur['currencyCode'] as String?,
        );
        notify();
      }
    } catch (e, st) {
      AppLogger.error('_loadCurrentUserProfileFromFirestore failed', name: 'AuthRepository', error: e, stackTrace: st);
    }
  }

  Future<void> _writeCurrentUserProfile() async {
    final cache = _userCache[_currentUserId];
    await FirestoreService.instance.setUser(
      _currentUserId,
      displayName: _currentUserName,
      phoneNumber: _currentUserPhone,
      photoURL: cache?['photoURL'] as String?,
      upiId: cache?['upiId'] as String?,
      currencyCode: cache?['currencyCode'] as String?,
    );
  }

  Future<void> updateCurrentUserPhotoURL(String? photoURL) async {
    if (_currentUserId.isEmpty) return;
    _userCache[_currentUserId] ??= <String, dynamic>{};
    final previous = _userCache[_currentUserId]!['photoURL'];
    _userCache[_currentUserId]!['photoURL'] = photoURL;
    try {
      await _writeCurrentUserProfile();
      UserProfileCache.instance.updatePhotoURL(photoURL);
      notify();
    } catch (e, st) {
      _userCache[_currentUserId]!['photoURL'] = previous;
      notify();
      AppLogger.error('updateCurrentUserPhotoURL write failed', name: 'AuthRepository', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> updateCurrentUserUpiId(String? upiId) async {
    if (_currentUserId.isEmpty) return;
    _userCache[_currentUserId] ??= <String, dynamic>{};
    _userCache[_currentUserId]!['upiId'] = upiId;
    await _writeCurrentUserProfile();
    UserProfileCache.instance.updateUpiId(upiId);
    notify();
  }

  void clearAuth() {
    _encryption?.clearKeys();
    _encryption = null;
    FirestoreService.instance.setEncryptionService(null);
    _currentUserId = '';
    _currentUserPhone = '';
    _currentUserName = '';
    _userCache.clear();
    UserProfileCache.instance.clear();
    IdentityService.instance.clear();
    notify();
  }

  Map<String, dynamic>? getUserCache(String uid) => _userCache[uid];
  void updateUserCache(String uid, Map<String, dynamic> data) => _userCache[uid] = data;
}
