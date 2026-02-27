import 'package:shared_preferences/shared_preferences.dart';

/// Local cache for user profile data (name, photoURL, upiId).
/// Enables instant UI rendering on cold start before Firestore responds.
class UserProfileCache {
  UserProfileCache._();

  static final UserProfileCache _instance = UserProfileCache._();
  static UserProfileCache get instance => _instance;

  static const String _keyUserId = 'cached_user_id';
  static const String _keyDisplayName = 'cached_display_name';
  static const String _keyPhotoURL = 'cached_photo_url';
  static const String _keyUpiId = 'cached_upi_id';
  static const String _keyPhone = 'cached_phone';
  static const String _keyCurrencyCode = 'cached_currency_code';

  SharedPreferences? _prefs;
  bool _loaded = false;

  String? _userId;
  String? _displayName;
  String? _photoURL;
  String? _upiId;
  String? _phone;
  String? _currencyCode;

  String? get userId => _userId;
  String? get displayName => _displayName;
  String? get photoURL => _photoURL;
  String? get upiId => _upiId;
  String? get phone => _phone;
  String? get currencyCode => _currencyCode;

  bool get hasCache => _userId != null && _userId!.isNotEmpty;

  /// Initialize and load from SharedPreferences. Call once at app start.
  Future<void> load() async {
    if (_loaded) return;
    _prefs = await SharedPreferences.getInstance();
    _userId = _prefs!.getString(_keyUserId);
    _displayName = _prefs!.getString(_keyDisplayName);
    _photoURL = _prefs!.getString(_keyPhotoURL);
    _upiId = _prefs!.getString(_keyUpiId);
    _phone = _prefs!.getString(_keyPhone);
    _currencyCode = _prefs!.getString(_keyCurrencyCode);
    _loaded = true;
  }

  /// Synchronous read after load() has completed. Returns cached values immediately.
  CachedUserProfile? getCachedProfile() {
    if (!_loaded || _userId == null || _userId!.isEmpty) return null;
    return CachedUserProfile(
      userId: _userId!,
      displayName: _displayName ?? '',
      photoURL: _photoURL,
      upiId: _upiId,
      phone: _phone ?? '',
      currencyCode: _currencyCode,
    );
  }

  /// Persist user profile to local cache. Call after Firestore updates.
  Future<void> save({
    required String userId,
    required String displayName,
    String? photoURL,
    String? upiId,
    String? phone,
    String? currencyCode,
  }) async {
    _prefs ??= await SharedPreferences.getInstance();
    _userId = userId;
    _displayName = displayName;
    _photoURL = photoURL;
    _upiId = upiId;
    _phone = phone;
    _currencyCode = currencyCode;

    await Future.wait([
      _prefs!.setString(_keyUserId, userId),
      _prefs!.setString(_keyDisplayName, displayName),
      if (photoURL != null)
        _prefs!.setString(_keyPhotoURL, photoURL)
      else
        _prefs!.remove(_keyPhotoURL),
      if (upiId != null)
        _prefs!.setString(_keyUpiId, upiId)
      else
        _prefs!.remove(_keyUpiId),
      if (phone != null)
        _prefs!.setString(_keyPhone, phone)
      else
        _prefs!.remove(_keyPhone),
      if (currencyCode != null)
        _prefs!.setString(_keyCurrencyCode, currencyCode)
      else
        _prefs!.remove(_keyCurrencyCode),
    ]);
  }

  /// Update just the photoURL (after avatar upload).
  Future<void> updatePhotoURL(String? photoURL) async {
    _prefs ??= await SharedPreferences.getInstance();
    _photoURL = photoURL;
    if (photoURL != null) {
      await _prefs!.setString(_keyPhotoURL, photoURL);
    } else {
      await _prefs!.remove(_keyPhotoURL);
    }
  }

  /// Update just the UPI ID.
  Future<void> updateUpiId(String? upiId) async {
    _prefs ??= await SharedPreferences.getInstance();
    _upiId = upiId;
    if (upiId != null) {
      await _prefs!.setString(_keyUpiId, upiId);
    } else {
      await _prefs!.remove(_keyUpiId);
    }
  }

  /// Clear cache on logout.
  Future<void> clear() async {
    _prefs ??= await SharedPreferences.getInstance();
    _userId = null;
    _displayName = null;
    _photoURL = null;
    _upiId = null;
    _phone = null;
    _currencyCode = null;
    await Future.wait([
      _prefs!.remove(_keyUserId),
      _prefs!.remove(_keyDisplayName),
      _prefs!.remove(_keyPhotoURL),
      _prefs!.remove(_keyUpiId),
      _prefs!.remove(_keyPhone),
      _prefs!.remove(_keyCurrencyCode),
    ]);
  }
}

class CachedUserProfile {
  final String userId;
  final String displayName;
  final String? photoURL;
  final String? upiId;
  final String phone;
  final String? currencyCode;

  CachedUserProfile({
    required this.userId,
    required this.displayName,
    this.photoURL,
    this.upiId,
    required this.phone,
    this.currencyCode,
  });
}
