import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Centralized phone auth using [FirebaseAuth.instance.verifyPhoneNumber].
/// Handles [codeSent] (OTP screen), [verificationCompleted] (instant sign-in),
/// and specific error handling for invalid-verification-code and too-many-requests.
class PhoneAuthService {
  PhoneAuthService._();

  static final PhoneAuthService _instance = PhoneAuthService._();

  static PhoneAuthService get instance => _instance;

  /// Test number registered in Firebase Console; show dev code hint when used.
  static const String testPhoneDigits = '7902203218';
  static const String devTestCode = '123456';

  FirebaseAuth get _auth => FirebaseAuth.instance;

  /// Stream of auth state. Use for routing: null → login; non-null → app (ledger).
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Current Firebase user; null if signed out.
  User? get currentUser => _auth.currentUser;

  /// E.164 for Firebase: +91 and 10 digits, no spaces.
  static String toE164(String digits) {
    final clean = digits.replaceAll(RegExp(r'\D'), '');
    if (clean.length == 10) return '+91$clean';
    return digits.isEmpty ? '' : '+91$clean';
  }

  /// User-friendly message for Firebase auth errors (invalid code, rate limit, test hint).
  static String messageForError(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-verification-code':
          return 'Invalid code. For the test number +91 79022 03218, use the code $devTestCode.';
        case 'too-many-requests':
          return 'Too many attempts. Please try again later.';
        default:
          return error.message ?? error.code;
      }
    }
    return error.toString();
  }

  /// Whether the given phone (10 digits or E.164) is the registered test number.
  static bool isTestNumber(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return digits.endsWith(testPhoneDigits) || digits == testPhoneDigits;
  }

  /// Starts phone verification. Callbacks drive UI: [onCodeSent] → show OTP screen; [onVerificationCompleted] → sign-in done.
  void verifyPhoneNumber({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(PhoneAuthCredential credential) onVerificationCompleted,
    required void Function(String message) onError,
    int? resendToken,
  }) {
    final e164 = phoneNumber.length == 10 ? toE164(phoneNumber) : phoneNumber;
    debugPrint('PhoneAuth: verifyPhoneNumber called with E.164=$e164');
    _auth.verifyPhoneNumber(
      phoneNumber: e164,
      verificationCompleted: (PhoneAuthCredential credential) {
        debugPrint('PhoneAuth: verificationCompleted (auto sign-in)');
        onVerificationCompleted(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        debugPrint('PhoneAuth: verificationFailed code=${e.code} message=${e.message}');
        onError(messageForError(e));
      },
      codeSent: (String verificationId, int? token) {
        debugPrint('PhoneAuth: codeSent verificationId=${verificationId.substring(0, 20)}...');
        onCodeSent(verificationId, token);
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        debugPrint('PhoneAuth: codeAutoRetrievalTimeout');
      },
      timeout: const Duration(seconds: 120),
      forceResendingToken: resendToken,
    );
  }

  /// Sign in with OTP credential (from manual OTP entry or auto-retrieval).
  Future<void> signInWithCredential(PhoneAuthCredential credential) async {
    await _auth.signInWithCredential(credential);
  }

  /// Sign out. Auth state stream will emit null; app should show login.
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
