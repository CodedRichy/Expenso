import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../utils/country_codes.dart';
import '../../design/colors.dart';
import '../../design/typography.dart';
import '../../repositories/cycle_repository.dart';
import '../../services/auth_service.dart';
import '../../widgets/tap_scale.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/gradient_scaffold.dart';

enum AuthMethod { google, email, phone }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  AuthMethod _method = AuthMethod.google;
  bool _isLogin = true; // For Email method
  
  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  String _selectedCountryCode = '+91';
  String _step = 'input'; // For Phone: 'input' or 'otp'
  bool _loading = false;
  String? _errorMessage;
  int _resendCountdown = 0;
  Timer? _countdownTimer;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _clearError() => setState(() => _errorMessage = null);

  // ── GOOGLE ──

  Future<void> _handleGoogleSignIn() async {
    setState(() => _loading = true);
    _clearError();
    try {
      final res = await AuthService.instance.signInWithGoogle();
      final user = res.user;
      if (user != null && mounted) {
        final name = user.userMetadata?['display_name'] as String? ?? user.userMetadata?['full_name'] as String? ?? '';
        CycleRepository.instance.setGlobalProfile(
          name,
          email: user.email,
          authUserId: user.id,
        );
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── EMAIL ──

  Future<void> _handleEmailAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty) return;
    if (!_isLogin && name.isEmpty) return;

    setState(() => _loading = true);
    _clearError();
    try {
      if (_isLogin) {
        final res = await AuthService.instance.signInWithEmail(email, password);
        final user = res.user;
        if (user != null && mounted) {
           final dname = user.userMetadata?['display_name'] as String? ?? '';
           CycleRepository.instance.setGlobalProfile(dname, email: user.email, authUserId: user.id);
        }
      } else {
        final res = await AuthService.instance.signUpWithEmail(email, password, name);
        if (mounted && res.user != null) {
          CycleRepository.instance.setGlobalProfile(name, email: email, authUserId: res.user!.id);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Verification email sent!')));
        }
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── PHONE ──

  void _handlePhoneSubmit() {
    final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) return;
    _clearError();
    
    final e164 = '$_selectedCountryCode$digits';
    setState(() => _loading = true);
    
    AuthService.instance.sendOtp(
      phoneNumber: e164,
      onCodeSent: () {
        if (!mounted) return;
        setState(() {
          _step = 'otp';
          _loading = false;
        });
        _startResendTimer();
      },
      onError: (msg) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _errorMessage = msg;
        });
      },
    );
  }

  void _handleOtpSubmit() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) return;
    setState(() => _loading = true);
    _clearError();

    try {
      final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
      final e164 = '$_selectedCountryCode$digits';
      await AuthService.instance.verifyOtp(phoneNumber: e164, token: otp);
      
      final user = AuthService.instance.currentUser;
      if (user != null && mounted) {
        final currency = currencyCodeForDialCode(_selectedCountryCode) ?? 'INR';
        final name = user.userMetadata?['display_name'] as String? ?? '';
        CycleRepository.instance.setGlobalProfile(
          name,
          phone: e164,
          authUserId: user.id,
          currencyCode: currency,
        );
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startResendTimer() {
    _countdownTimer?.cancel();
    setState(() => _resendCountdown = 30);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      if (_resendCountdown == 1) {
        setState(() => _resendCountdown = 0);
        timer.cancel();
      } else {
        setState(() => _resendCountdown--);
      }
    });
  }

  // ── UI HELPERS ──

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CountryPickerSheet(
        onSelect: (country) => setState(() => _selectedCountryCode = country.dialCode),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Text('Welcome to', style: context.bodyLarge.copyWith(color: context.colorTextSecondary)),
              Text('Expenso', style: context.heroTitle.copyWith(fontSize: 40, height: 1.1)),
              const SizedBox(height: 8),
              Text('Track expenses together, seamlessly.', style: context.bodySecondary),
              const SizedBox(height: 48),
              
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      if (_method == AuthMethod.google) _buildGoogleUI(),
                      if (_method == AuthMethod.email) _buildEmailUI(),
                      if (_method == AuthMethod.phone) _buildPhoneUI(),
                      
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Text(_errorMessage!, style: context.bodySecondary.copyWith(color: context.colorError), textAlign: TextAlign.center),
                      ],
                    ],
                  ),
                ),
              ),

              _buildMethodSwitcher(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleUI() {
    return Column(
      children: [
        const SizedBox(height: 20),
        TapScale(
          onTap: _loading ? null : _handleGoogleSignIn,
          child: GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 16),
            borderRadius: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_loading)
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                else ...[
                  Image.network('https://upload.wikimedia.org/wikipedia/commons/5/53/Google_%22G%22_Logo.svg', height: 24, 
                    errorBuilder: (_, error, stackTrace) => const Icon(Icons.account_circle, size: 24)),
                  const SizedBox(width: 12),
                  Text('Continue with Google', style: context.labelLarge.copyWith(fontWeight: FontWeight.bold)),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmailUI() {
    return Column(
      children: [
        if (!_isLogin) ...[
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(hintText: 'Full Name', prefixIcon: Icon(Icons.person_outline)),
            style: context.input,
          ),
          const SizedBox(height: 16),
        ],
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(hintText: 'Email Address', prefixIcon: Icon(Icons.email_outlined)),
          style: context.input,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: const InputDecoration(hintText: 'Password', prefixIcon: Icon(Icons.lock_outline)),
          style: context.input,
        ),
        const SizedBox(height: 24),
        TapScale(
          child: ElevatedButton(
            onPressed: _loading ? null : _handleEmailAuth,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _loading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(_isLogin ? 'Login' : 'Sign Up', style: AppTypography.button),
          ),
        ),
        TextButton(
          onPressed: () => setState(() => _isLogin = !_isLogin),
          child: Text(_isLogin ? "Don't have an account? Sign Up" : "Already have an account? Login", style: context.bodySecondary),
        ),
      ],
    );
  }

  Widget _buildPhoneUI() {
    if (_step == 'otp') {
      return Column(
        children: [
          Text('Enter the 6-digit code sent to your phone', style: context.bodySecondary, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
            decoration: const InputDecoration(hintText: '000000'),
            style: context.input.copyWith(letterSpacing: 12, fontSize: 24),
            onChanged: (v) { if (v.length == 6) _handleOtpSubmit(); },
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _resendCountdown == 0 ? _handlePhoneSubmit : null,
            child: Text(_resendCountdown > 0 ? 'Resend in ${_resendCountdown}s' : 'Resend Code', style: context.bodySecondary),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: () => setState(() => _step = 'input'), child: const Text('Change Phone Number')),
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            TapScale(
              onTap: _showCountryPicker,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_selectedCountryCode, style: context.bodyLarge),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(hintText: 'Phone Number'),
                style: context.input,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        TapScale(
          child: ElevatedButton(
            onPressed: _loading ? null : _handlePhoneSubmit,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _loading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Send Code', style: AppTypography.button),
          ),
        ),
      ],
    );
  }

  Widget _buildMethodSwitcher() {
    return SegmentedButton<AuthMethod>(
      segments: const [
        ButtonSegment(value: AuthMethod.google, icon: Icon(Icons.g_mobiledata), label: Text('Google')),
        ButtonSegment(value: AuthMethod.email, icon: Icon(Icons.email_outlined), label: Text('Email')),
        ButtonSegment(value: AuthMethod.phone, icon: Icon(Icons.phone_outlined), label: Text('Phone')),
      ],
      selected: {_method},
      onSelectionChanged: (set) => setState(() {
        _method = set.first;
        _errorMessage = null;
      }),
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        backgroundColor: Colors.white54,
        selectedBackgroundColor: context.colorPrimary,
        selectedForegroundColor: Colors.white,
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
                Text('Select country', style: context.subheader),
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  leading: Text(
                    _getFlagEmoji(country.countryCode),
                    style: const TextStyle(fontSize: 24),
                  ),
                  title: Text(
                    country.name,
                    style: context.bodyPrimary.copyWith(fontWeight: FontWeight.w500),
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
    return countryCode.toUpperCase().replaceAllMapped(
      RegExp(r'[A-Z]'),
      (match) => String.fromCharCode(match.group(0)!.codeUnitAt(0) + 127397),
    );
  }
}
