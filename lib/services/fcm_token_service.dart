import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'firestore_service.dart';

class FcmTokenService {
  FcmTokenService._internal();

  static final FcmTokenService _instance = FcmTokenService._internal();
  static FcmTokenService get instance => _instance;

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
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
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      debugPrint('FCM: Permission status: ${settings.authorizationStatus}');
    } catch (e) {
      debugPrint('FCM: Permission request failed: $e');
    }
  }

  Future<void> _getAndStoreToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null && token != _currentToken) {
        _currentToken = token;
        await _storeToken(token);
        debugPrint('FCM: Token registered');
      }
    } catch (e) {
      debugPrint('FCM: Get token failed: $e');
    }
  }

  void _listenForTokenRefresh() {
    _messaging.onTokenRefresh.listen((token) async {
      if (token != _currentToken) {
        _currentToken = token;
        await _storeToken(token);
        debugPrint('FCM: Token refreshed');
      }
    });
  }

  Future<void> _storeToken(String token) async {
    if (_userId == null || _userId!.isEmpty) return;
    
    try {
      final platform = Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'unknown');
      await FirestoreService.instance.storeFcmToken(
        _userId!,
        token,
        platform,
      );
    } catch (e) {
      debugPrint('FCM: Store token failed: $e');
    }
  }

  Future<void> deleteToken() async {
    try {
      if (_currentToken != null && _userId != null) {
        await FirestoreService.instance.deleteFcmToken(_userId!, _currentToken!);
      }
      await _messaging.deleteToken();
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
