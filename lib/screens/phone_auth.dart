import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../country_codes.dart';
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
  String _selectedCountryCode = '+91';

  /// E.164 for Firebase: selected code + digits, no spaces.
  static String _e164(String code, String digits) {
    final normalized = digits.replaceAll(RegExp(r'\D'), '');
    if (normalized.isEmpty) return '';
    return '$code$normalized';
  }

  static String _formatPhone(String code, String digits) {
    final normalized = digits.replaceAll(RegExp(r'\D'), '');
    if (normalized.isEmpty) return '';
    if (normalized.length >= 10) {
      return '$code ${normalized.substring(0, normalized.length.clamp(0, 5))} ${normalized.substring(5)}';
    }
    return '$code $normalized';
  }

  void _clearError() {
    if (_errorMessage != null) setState(() => _errorMessage = null);
  }

  void handlePhoneSubmit() {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) return;
    _clearError();
    final e164 = _e164(_selectedCountryCode, digits);
    if (e164.isEmpty) return;
    if (!firebaseAuthAvailable) {
      setState(() => step = 'otp');
      return;
    }
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    PhoneAuthService.instance.verifyPhoneNumber(
      phoneNumber: e164,
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
      final formattedPhone = _formatPhone(_selectedCountryCode, phone);
      final currencyCode = currencyCodeForDialCode(_selectedCountryCode) ?? 'INR';
      CycleRepository.instance.setGlobalProfile(
        formattedPhone,
        user.displayName ?? '',
        authUserId: user.uid,
        currencyCode: currencyCode,
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
    final formattedPhone = _formatPhone(_selectedCountryCode, phone);
    if (!firebaseAuthAvailable) {
      final currencyCode = currencyCodeForDialCode(_selectedCountryCode) ?? 'INR';
      CycleRepository.instance.setGlobalProfile(formattedPhone, '', currencyCode: currencyCode);
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
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: step == 'phone'
              ? KeyedSubtree(
                  key: const ValueKey('phone'),
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
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                border: Border.all(color: Theme.of(context).dividerColor),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: PopupMenuButton<String>(
                                onSelected: (code) => setState(() => _selectedCountryCode = code),
                                offset: const Offset(0, 48),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                itemBuilder: (context) => countryCodesWithCurrency.map((c) => PopupMenuItem<String>(
                                  value: c.dialCode,
                                  child: Text(
                                    '${c.dialCode} ${c.countryCode}',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                )).toList(),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _selectedCountryCode,
                                        style: context.bodySecondary,
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(Icons.arrow_drop_down, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                    ],
                                  ),
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
                                  LengthLimitingTextInputFormatter(15),
                                ],
                                onChanged: (value) {
                                  setState(() => phone = value);
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
                            style: context.bodySecondary.copyWith(color: context.colorError),
                          ),
                        ],
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: (phone.replaceAll(RegExp(r'\D'), '').length >= 10 && !_loading) ? handlePhoneSubmit : null,
                          child: _loading
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                )
                              : const Text('Continue', style: AppTypography.button),
                        ),
                        const Spacer(),
                      ],
                    ),
                  ),
                )
              : KeyedSubtree(
                  key: const ValueKey('otp'),
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
                              'Sent to $_selectedCountryCode $phone',
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
                            style: context.bodySecondary.copyWith(color: context.colorError),
                          ),
                        ],
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: (otp.length == 6 && !_loading) ? handleOtpSubmit : null,
                          child: _loading
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Theme.of(context).colorScheme.primary,
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
        ),
      ),
    );
  }
}
