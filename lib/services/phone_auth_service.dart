import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralized auth: phone (OTP) only using Supabase.
class PhoneAuthService {
  PhoneAuthService._();

  static final PhoneAuthService _instance = PhoneAuthService._();

  static PhoneAuthService get instance => _instance;

  static const String testPhoneDigits = '7902203218';
  static const String devTestCode = '123456';

  SupabaseClient get _supabase => Supabase.instance.client;

  /// Stream of auth state.
  Stream<User?> get authStateChanges =>
      _supabase.auth.onAuthStateChange.map((event) => event.session?.user);

  /// Current Supabase user; null if signed out.
  User? get currentUser => _supabase.auth.currentUser;

  /// E.164 for Supabase: +91 and 10 digits, no spaces.
  static String toE164(String digits) {
    final clean = digits.replaceAll(RegExp(r'\D'), '');
    if (clean.length == 10) return '+91$clean';
    return digits.isEmpty ? '' : '+91$clean';
  }

  static const String _genericMessage =
      'Something went wrong. Please try again.';

  static String messageForError(dynamic error) {
    if (error is AuthException) {
      if (error.message.toLowerCase().contains('invalid')) {
        return 'Invalid code or phone number. Please try again.';
      } else if (error.message.toLowerCase().contains('rate limit')) {
        return 'Too many attempts. Please try again later.';
      }
      return error.message;
    }
    return _genericMessage;
  }

  static bool isTestNumber(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return digits.endsWith(testPhoneDigits) || digits == testPhoneDigits;
  }

  Future<void> sendOtp({
    required String phoneNumber,
    required void Function() onCodeSent,
    required void Function(String message) onError,
  }) async {
    final e164 = phoneNumber.length == 10 ? toE164(phoneNumber) : phoneNumber;
    debugPrint('PhoneAuth: sendOtp called with E.164=$e164');
    try {
      await _supabase.auth.signInWithOtp(phone: e164);
      onCodeSent();
    } on AuthException catch (e) {
      debugPrint('PhoneAuth error: ${e.message}');
      onError(messageForError(e));
    } catch (e) {
      debugPrint('PhoneAuth generic error: $e');
      onError(messageForError(e));
    }
  }

  Future<void> verifyOtp({
    required String phoneNumber,
    required String token,
  }) async {
    final e164 = phoneNumber.length == 10 ? toE164(phoneNumber) : phoneNumber;
    await _supabase.auth.verifyOTP(phone: e164, token: token, type: OtpType.sms);
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}
