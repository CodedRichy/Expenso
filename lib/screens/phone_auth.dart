import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../design/colors.dart';
import '../design/typography.dart';
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
                      style: context.heroTitle.copyWith(height: 1.2),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'You will receive a verification code',
                      style: context.bodySecondary,
                    ),
                  ],
                ),
                const SizedBox(height: 48),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '+91',
                        style: context.bodySecondary,
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
                        decoration: const InputDecoration(hintText: 'Phone number'),
                        style: context.input,
                      ),
                    ),
                  ],
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _errorMessage!,
                    style: context.bodySecondary.copyWith(color: AppColors.error),
                  ),
                ],
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: (phone.length == 10 && !_loading) ? handlePhoneSubmit : null,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.surface,
                          ),
                        )
                      : const Text('Continue', style: AppTypography.button),
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
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
                    style: context.heroTitle.copyWith(height: 1.2),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Sent to +91 $phone',
                    style: context.bodySecondary,
                  ),
                  if (PhoneAuthService.isTestNumber(phone)) ...[
                    const SizedBox(height: 8),
                    Text(
                      'For this test number, use the code ${PhoneAuthService.devTestCode}.',
                      style: context.caption.copyWith(
                        color: AppColors.accent,
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
                decoration: const InputDecoration(hintText: '6-digit code'),
                style: context.input.copyWith(letterSpacing: 8),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: context.bodySecondary.copyWith(color: AppColors.error),
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: (otp.length == 6 && !_loading) ? handleOtpSubmit : null,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.surface,
                        ),
                      )
                    : const Text('Verify', style: AppTypography.button),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _loading ? null : _goBackToPhone,
                child: Text(
                  'Change number',
                  style: context.bodySecondary.copyWith(
                    fontWeight: FontWeight.w500,
                    color: AppColors.accent,
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
