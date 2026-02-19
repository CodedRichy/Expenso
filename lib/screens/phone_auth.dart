import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../firebase_app.dart';
import '../repositories/cycle_repository.dart';
import '../services/phone_auth_service.dart';

class PhoneAuth extends StatefulWidget {
  const PhoneAuth({super.key});

  @override
  State<PhoneAuth> createState() => _PhoneAuthState();
}

class _PhoneAuthState extends State<PhoneAuth> {
  String phone = '';
  String otp = '';
  String step = 'phone'; // 'phone' or 'otp'
  String? _verificationId;
  int? _resendToken;
  bool _loading = false;
  String? _errorMessage;

  /// E.164 for Firebase: +91 and 10 digits, no spaces.
  static String _e164(String digits) {
    if (digits.length == 10) return '+91$digits';
    return digits.isEmpty ? '' : '+91$digits';
  }

  static String _formatPhone(String digits) {
    if (digits.length == 10) {
      return '+91 ${digits.substring(0, 5)} ${digits.substring(5)}';
    }
    return digits.isEmpty ? '' : '+91 $digits';
  }

  void _clearError() {
    if (_errorMessage != null) setState(() => _errorMessage = null);
  }

  void handlePhoneSubmit() {
    if (phone.length != 10) return;
    _clearError();
    if (!firebaseAuthAvailable) {
      setState(() => step = 'otp');
      return;
    }
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    PhoneAuthService.instance.verifyPhoneNumber(
      phoneNumber: _e164(phone),
      onVerificationCompleted: (PhoneAuthCredential credential) {
        if (!mounted) return;
        _signInWithCredential(credential);
      },
      onError: (String message) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _errorMessage = message;
        });
      },
      onCodeSent: (String verificationId, int? resendToken) {
        if (!mounted) return;
        setState(() {
          _verificationId = verificationId;
          _resendToken = resendToken;
          step = 'otp';
          _loading = false;
          _errorMessage = null;
        });
      },
      resendToken: _resendToken,
    );
  }

  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    try {
      await PhoneAuthService.instance.signInWithCredential(credential);
      final user = PhoneAuthService.instance.currentUser;
      if (!mounted || user == null) return;
      final formattedPhone = _formatPhone(phone);
      CycleRepository.instance.setGlobalProfile(
        formattedPhone,
        user.displayName ?? '',
        authUserId: user.uid,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = PhoneAuthService.messageForError(e);
      });
    }
  }

  void handleOtpSubmit() async {
    if (otp.length != 6) return;
    _clearError();
    final formattedPhone = _formatPhone(phone);
    if (!firebaseAuthAvailable) {
      CycleRepository.instance.setGlobalProfile(formattedPhone, '');
      return;
    }
    final verificationId = _verificationId;
    if (verificationId == null) {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/error-states', arguments: {'type': 'session-expired'});
      return;
    }
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: otp,
    );
    await _signInWithCredential(credential);
    if (!mounted) return;
    setState(() => _loading = false);
  }

  void _goBackToPhone() {
    setState(() {
      step = 'phone';
      otp = '';
      _verificationId = null;
      _resendToken = null;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (step == 'phone') {
      return Scaffold(
        backgroundColor: const Color(0xFFF7F7F8),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enter phone number',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A1A1A),
                        letterSpacing: -0.6,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'You will receive a verification code',
                      style: TextStyle(
                        fontSize: 17,
                        color: const Color(0xFF6B6B6B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 48),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFE5E5E5)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '+91',
                        style: TextStyle(
                          fontSize: 17,
                          color: const Color(0xFF6B6B6B),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        autofocus: true,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        onChanged: (value) {
                          setState(() {
                            phone = value;
                          });
                        },
                        onSubmitted: (_) => handlePhoneSubmit(),
                        decoration: InputDecoration(
                          hintText: 'Phone number',
                          hintStyle: TextStyle(
                            color: const Color(0xFFB0B0B0),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFD0D0D0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFD0D0D0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF1A1A1A)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                        style: TextStyle(
                          fontSize: 17,
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFFB00020),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: (phone.length == 10 && !_loading) ? handlePhoneSubmit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1A1A),
                    disabledBackgroundColor: const Color(0xFFE5E5E5),
                    foregroundColor: Colors.white,
                    disabledForegroundColor: const Color(0xFFB0B0B0),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter verification code',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A1A1A),
                      letterSpacing: -0.6,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
              Text(
                  'Sent to +91 $phone',
                  style: TextStyle(
                    fontSize: 17,
                    color: const Color(0xFF6B6B6B),
                  ),
                ),
                if (PhoneAuthService.isTestNumber(phone)) ...[
                  const SizedBox(height: 8),
                  Text(
                    'For this test number, use the code ${PhoneAuthService.devTestCode}.',
                    style: TextStyle(
                      fontSize: 14,
                      color: const Color(0xFF5B7C99),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 48),
            TextField(
                autofocus: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                onChanged: (value) {
                  setState(() {
                    otp = value;
                  });
                },
                onSubmitted: (_) => handleOtpSubmit(),
                decoration: InputDecoration(
                  hintText: '6-digit code',
                  hintStyle: TextStyle(
                    color: const Color(0xFFB0B0B0),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFD0D0D0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFD0D0D0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF1A1A1A)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                style: TextStyle(
                  fontSize: 17,
                  color: const Color(0xFF1A1A1A),
                  letterSpacing: 8,
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFFB00020),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: (otp.length == 6 && !_loading) ? handleOtpSubmit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A1A1A),
                  disabledBackgroundColor: const Color(0xFFE5E5E5),
                  foregroundColor: Colors.white,
                  disabledForegroundColor: const Color(0xFFB0B0B0),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Verify',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _loading ? null : _goBackToPhone,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  'Change number',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF5B7C99),
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
