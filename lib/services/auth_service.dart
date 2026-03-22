import 'dart:async';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralized authentication service for Expenso.
/// Supports Google Sign-In, Email/Password, and Phone OTP.
class AuthService {
  AuthService._();

  static final AuthService _instance = AuthService._();

  static AuthService get instance => _instance;

  SupabaseClient get _supabase => Supabase.instance.client;

  /// Stream of auth state changes.
  Stream<User?> get authStateChanges =>
      _supabase.auth.onAuthStateChange.map((event) => event.session?.user);

  /// Current authenticated user.
  User? get currentUser => _supabase.auth.currentUser;

  // ── GOOGLE SIGN-IN ──

  /// Sign in with Google using native SDK and Supabase ID token exchange.
  Future<AuthResponse> signInWithGoogle() async {
    final webClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID'];
    final iosClientId = dotenv.env['GOOGLE_IOS_CLIENT_ID'];

    final GoogleSignIn googleSignIn = GoogleSignIn(
      clientId: iosClientId,
      serverClientId: webClientId,
    );

    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) throw const AuthException('Google sign-in cancelled');

    final googleAuth = await googleUser.authentication;
    final accessToken = googleAuth.accessToken;
    final idToken = googleAuth.idToken;

    if (idToken == null) {
      throw const AuthException('No ID Token found from Google');
    }

    return await _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  // ── EMAIL / PASSWORD ──

  /// Sign in with Email and Password.
  Future<AuthResponse> signInWithEmail(String email, String password) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Sign up with Email and Password.
  Future<AuthResponse> signUpWithEmail(String email, String password, String name) async {
    return await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {'display_name': name},
    );
  }

  /// Send a password reset email.
  Future<void> sendPasswordReset(String email) async {
    await _supabase.auth.resetPasswordForEmail(email);
  }

  // ── PHONE OTP (Legacy) ──

  static String toE164(String digits) {
    final clean = digits.replaceAll(RegExp(r'\D'), '');
    if (clean.length == 10) return '+91$clean';
    return digits.isEmpty ? '' : '+91$clean';
  }

  Future<void> sendOtp({
    required String phoneNumber,
    required void Function() onCodeSent,
    required void Function(String message) onError,
  }) async {
    final e164 = phoneNumber.length == 10 ? toE164(phoneNumber) : phoneNumber;
    try {
      await _supabase.auth.signInWithOtp(phone: e164);
      onCodeSent();
    } on AuthException catch (e) {
      onError(e.message);
    } catch (e) {
      onError('Something went wrong, please try again.');
    }
  }

  Future<void> verifyOtp({
    required String phoneNumber,
    required String token,
  }) async {
    final e164 = phoneNumber.length == 10 ? toE164(phoneNumber) : phoneNumber;
    await _supabase.auth.verifyOTP(phone: e164, token: token, type: OtpType.sms);
  }

  // ── COMMON ──

  Future<void> signOut() async {
    await _supabase.auth.signOut();
    final GoogleSignIn googleSignIn = GoogleSignIn();
    if (await googleSignIn.isSignedIn()) {
      await googleSignIn.signOut();
    }
  }
}
