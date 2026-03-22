import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

class FcmTokenService {
  FcmTokenService._internal();

  static final FcmTokenService _instance = FcmTokenService._internal();
  static FcmTokenService get instance => _instance;

  String? _currentToken;
  String? _userId;

  String? get currentToken => _currentToken;

  Future<void> initialize(String userId) async {
    _userId = userId;
    await _requestPermission();
    await _getAndStoreToken();
    _listenForTokenRefresh();
  }

  Future<void> _requestPermission() async {
    // Stubbed until Supabase FCM replaces it
  }

  Future<void> _getAndStoreToken() async {
    // Stubbed
  }

  void _listenForTokenRefresh() {
    // Stubbed
  }

  Future<void> deleteToken() async {
    try {
      if (_currentToken != null && _userId != null) {
        await SupabaseService.instance.deleteFcmToken(
          _userId!,
          _currentToken!,
        );
      }
      _currentToken = null;
      debugPrint('FCM: Token deleted');
    } catch (e) {
      debugPrint('FCM: Delete token failed: $e');
    }
  }

  void clear() {
    _userId = null;
    _currentToken = null;
  }
}
