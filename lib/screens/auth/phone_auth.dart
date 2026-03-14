import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/country_codes.dart';
import '../../design/colors.dart';
import '../../design/typography.dart';
import '../../firebase_app.dart';
import '../../repositories/cycle_repository.dart';
import '../../services/phone_auth_service.dart';
import '../../widgets/tap_scale.dart';

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
  int _resendCountdown = 0;
  Timer? _countdownTimer;

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
      debugPrint('PhoneAuth: Firebase not available, using mock OTP step');
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
        _startResendTimer();
      },
      resendToken: _resendToken,
    );
  }

  void _startResendTimer() {
    _countdownTimer?.cancel();
    setState(() => _resendCountdown = 30);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCountdown == 1) {
        setState(() => _resendCountdown = 0);
        timer.cancel();
      } else {
        setState(() => _resendCountdown--);
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _signInWithCredential(PhoneAuthCredential credential) async {
    try {
      await PhoneAuthService.instance.signInWithCredential(credential);
      final user = PhoneAuthService.instance.currentUser;
      if (!mounted || user == null) return;
      final formattedPhone = _formatPhone(_selectedCountryCode, phone);
      final currencyCode =
          currencyCodeForDialCode(_selectedCountryCode) ?? 'INR';
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
      final currencyCode =
          currencyCodeForDialCode(_selectedCountryCode) ?? 'INR';
      CycleRepository.instance.setGlobalProfile(
        formattedPhone,
        '',
        currencyCode: currencyCode,
      );
      return;
    }
    final verificationId = _verificationId;
    if (verificationId == null) {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(
        '/error-states',
        arguments: {'type': 'session-expired'},
      );
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

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CountryPickerSheet(
        onSelect: (country) {
          setState(() {
            _selectedCountryCode = country.dialCode;
            final maxLen = country.maxPhoneDigits;
            final digits = phone.replaceAll(RegExp(r'\D'), '');
            if (digits.length > maxLen) {
              phone = digits.substring(0, maxLen);
            }
          });
        },
      ),
    );
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
                  child: Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const SizedBox(height: 32),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Enter phone number',
                                        style: context.heroTitle.copyWith(
                                          height: 1.2,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'You will receive a verification code',
                                        style: context.bodySecondary,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 42),
                                  Row(
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.surface,
                                          border: Border.all(
                                            color: Theme.of(context).inputDecorationTheme.enabledBorder?.borderSide.color ?? Theme.of(context).dividerColor,
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: TapScale(
                                          onTap: _showCountryPicker,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 16,
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  _selectedCountryCode,
                                                  style: context.bodySecondary,
                                                ),
                                                const SizedBox(width: 4),
                                                Icon(
                                                  Icons.arrow_drop_down,
                                                  size: 20,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
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
                                            FilteringTextInputFormatter
                                                .digitsOnly,
                                            LengthLimitingTextInputFormatter(
                                              maxPhoneDigitsForDialCode(
                                                _selectedCountryCode,
                                              ),
                                            ),
                                          ],
                                          onChanged: (value) {
                                            setState(() => phone = value);
                                          },
                                          onSubmitted:
                                              (_) => handlePhoneSubmit(),
                                          decoration: const InputDecoration(
                                            hintText: 'Phone number',
                                          ),
                                          style: context.input,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_errorMessage != null) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      _errorMessage!,
                                      style: context.bodySecondary.copyWith(
                                        color: context.colorError,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                        child: TapScale(
                          child: ElevatedButton(
                            onPressed:
                                (() {
                                  final digits = phone.replaceAll(
                                    RegExp(r'\D'),
                                    '',
                                  );
                                  final maxLen = maxPhoneDigitsForDialCode(
                                    _selectedCountryCode,
                                  );
                                  return digits.length == maxLen && !_loading;
                                })()
                                ? handlePhoneSubmit
                                : null,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                              minimumSize: const Size(double.infinity, 0),
                            ),
                            child:
                                _loading
                                    ? SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color:
                                            Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                      ),
                                    )
                                    : const Text(
                                      'Continue',
                                      style: AppTypography.button,
                                    ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : KeyedSubtree(
                  key: const ValueKey('otp'),
                  child: Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const SizedBox(height: 32),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Enter verification code',
                                        style: context.heroTitle.copyWith(
                                          height: 1.2,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Sent to $_selectedCountryCode $phone',
                                        style: context.bodySecondary,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 42),
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
                                    decoration: const InputDecoration(
                                      hintText: '6-digit code',
                                    ),
                                    style: context.input.copyWith(
                                      letterSpacing: 8,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Center(
                                    child: TextButton(
                                      onPressed: (_resendCountdown == 0 && !_loading)
                                          ? handlePhoneSubmit
                                          : null,
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                      ),
                                      child: Text(
                                        _resendCountdown > 0
                                            ? 'Resend code in ${_resendCountdown}s'
                                            : 'Resend code',
                                        style: context.bodySecondary.copyWith(
                                          fontWeight: FontWeight.w500,
                                          color: _resendCountdown > 0
                                              ? context.colorTextDisabled
                                              : AppColors.accent,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (_errorMessage != null) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      _errorMessage!,
                                      style: context.bodySecondary.copyWith(
                                        color: context.colorError,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TapScale(
                                child: ElevatedButton(
                                  onPressed:
                                      (otp.length == 6 && !_loading)
                                          ? handleOtpSubmit
                                          : null,
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                    minimumSize: const Size(double.infinity, 0),
                                  ),
                                  child:
                                      _loading
                                          ? SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color:
                                                  Theme.of(
                                                    context,
                                                  ).colorScheme.primary,
                                            ),
                                          )
                                          : const Text(
                                            'Verify',
                                            style: AppTypography.button,
                                          ),
                                ),
                              ),
                              const SizedBox(height: 8),
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
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _CountryPickerSheet extends StatelessWidget {
  final Function(CountryEntry) onSelect;

  const _CountryPickerSheet({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Text(
                  'Select country',
                  style: context.subheader,
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: countryCodesWithCurrency.length,
              itemBuilder: (context, index) {
                final country = countryCodesWithCurrency[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: Text(
                    _getFlagEmoji(country.countryCode),
                    style: const TextStyle(fontSize: 24),
                  ),
                  title: Text(
                    country.name,
                    style: context.bodyPrimary.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  trailing: Text(
                    country.dialCode,
                    style: context.bodySecondary.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    onSelect(country);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getFlagEmoji(String countryCode) {
    // Converts ISO country code to emoji flag
    return countryCode.toUpperCase().replaceAllMapped(
          RegExp(r'[A-Z]'),
          (match) => String.fromCharCode(match.group(0)!.codeUnitAt(0) + 127397),
        );
  }
}
