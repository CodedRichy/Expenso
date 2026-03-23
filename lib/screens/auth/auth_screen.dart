import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/country_codes.dart';
import '../../design/colors.dart';
import '../../design/typography.dart';
import '../../repositories/cycle_repository.dart';
import '../../services/auth_service.dart';
import '../../utils/error_logger.dart';
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
  AuthMethod _method = AuthMethod.phone;
  bool _isLogin = true; // For Email method
  
  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
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
    _confirmPasswordController.dispose();
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
    var name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty) return;
    if (!_isLogin && name.isEmpty) {
      name = email.split('@').first;
    }

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
    
    // For testing: Always accept any phone number and show OTP screen
    ErrorLogger.instance.logInfo('Testing phone auth for: $e164');
    
    // Simulate OTP sending delay
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _step = 'otp';
          _loading = false;
        });
        _startResendTimer();
      }
    });
  }

  void _handleOtpSubmit() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) return;
    setState(() => _loading = true);
    _clearError();

    try {
      // Check for dummy OTP
      if (otp == '123456') {
        final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
        final e164 = '$_selectedCountryCode$digits';
        
        ErrorLogger.instance.logInfo('Dummy OTP verification successful for: $e164');
        
        // Create dummy user in Supabase
        final response = await Supabase.instance.client.auth.signUp(
          phone: e164,
          password: 'dummy_password_${DateTime.now().millisecondsSinceEpoch}',
        );

        if (response.user != null && mounted) {
          final currency = currencyCodeForDialCode(_selectedCountryCode) ?? 'INR';
          final name = 'Test User';
          
          // Set user profile
          CycleRepository.instance.setGlobalProfile(
            name,
            phone: e164,
            authUserId: response.user!.id,
            currencyCode: currency,
          );
          
          // Navigate to main app
          Navigator.of(context).pushReplacementNamed('/root');
        }
      } else {
        setState(() {
          _errorMessage = 'Invalid OTP. Use 123456 for testing';
        });
      }
    } catch (e, stackTrace) {
      ErrorLogger.instance.logError('OTP verification failed', context: e.toString(), stackTrace: stackTrace);
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
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 980;
    final compactCardWidth = (width - 32).clamp(280.0, 360.0).toDouble();

    return Scaffold(
      backgroundColor: const Color(0xFFE9E9E9),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
            child: isWide
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildWelcomeCard(240),
                      const SizedBox(width: 28),
                      _buildLoginCard(320),
                      const SizedBox(width: 28),
                      _buildSignUpCard(320),
                    ],
                  )
                : Column(
                    children: [
                      _buildWelcomeCard(compactCardWidth),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: () => setState(() => _isLogin = true),
                            child: Text(
                              'Login',
                              style: context.bodyMedium.copyWith(
                                fontWeight: FontWeight.w700,
                                color: _isLogin ? context.colorPrimary : context.colorTextSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () => setState(() => _isLogin = false),
                            child: Text(
                              'Sign up',
                              style: context.bodyMedium.copyWith(
                                fontWeight: FontWeight.w700,
                                color: !_isLogin ? context.colorPrimary : context.colorTextSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: _isLogin
                            ? _buildLoginCard(compactCardWidth, key: const ValueKey('login-card-mobile'))
                            : _buildSignUpCard(compactCardWidth, key: const ValueKey('signup-card-mobile')),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(double width, {Key? key}) {
    return _buildReferenceCardContainer(
      key: key,
      width: width,
      height: 470,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Wel\ncom\ne',
            style: context.displayLarge.copyWith(
              color: const Color(0xFFEF5A61),
              fontSize: 76,
              height: 0.83,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '“Story telling is the\nmost powerful way\nto put ideas into the\nworld today”\n-Robert Mckee',
            style: context.labelLarge.copyWith(color: const Color(0xFF8A8A8A), height: 1.35),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() => _isLogin = true),
            child: Text(
              'Login',
              style: context.headingMedium.copyWith(
                color: const Color(0xFF2F2F2F),
                decoration: TextDecoration.underline,
                decorationColor: const Color(0xFF2AAE8A),
                decorationThickness: 4,
              ),
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => setState(() => _isLogin = false),
            child: Text(
              'Register?',
              style: context.headingMedium.copyWith(
                color: const Color(0xFF2F2F2F),
                decoration: TextDecoration.underline,
                decorationColor: const Color(0xFFE7C35E),
                decorationThickness: 4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginCard(double width, {Key? key}) {
    return _buildReferenceCardContainer(
      key: key,
      width: width,
      height: 530,
      color: const Color(0xFFF1C86D),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.chevron_left, color: Colors.white),
          const SizedBox(height: 4),
          Text(
            'Log\nin',
            style: context.displayLarge.copyWith(
              color: Colors.white,
              fontSize: 74,
              height: 0.88,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Happy to see you\nagain. Now let\'s\nmake memories.',
            style: context.bodyMedium.copyWith(color: Colors.white.withValues(alpha: 0.9)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _socialDot(icon: Icons.g_mobiledata),
              const SizedBox(width: 10),
              _socialDot(icon: Icons.facebook),
            ],
          ),
          const SizedBox(height: 16),
          _outlinedField(
            controller: _emailController,
            hint: 'Email',
            icon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
            textColor: Colors.white,
          ),
          const SizedBox(height: 14),
          _outlinedField(
            controller: _passwordController,
            hint: 'Password',
            icon: Icons.lock_outline,
            obscureText: true,
            textColor: Colors.white,
          ),
          const Spacer(),
          Row(
            children: [
              TapScale(
                onTap: _loading
                    ? null
                    : () {
                        setState(() => _isLogin = true);
                        _handleEmailAuth();
                      },
                child: Text(
                  _loading ? 'Loading…' : 'Login',
                  style: context.headingMedium.copyWith(
                    color: Colors.white,
                    decoration: TextDecoration.underline,
                    decorationColor: const Color(0xFF2AAE8A),
                    decorationThickness: 4,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'Forgot\nPassword?',
                style: context.labelLarge.copyWith(color: Colors.white.withValues(alpha: 0.9)),
              ),
            ],
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              _errorMessage!,
              style: context.labelSmall.copyWith(color: const Color(0xFF7A1B1B)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSignUpCard(double width, {Key? key}) {
    return _buildReferenceCardContainer(
      key: key,
      width: width,
      height: 530,
      color: const Color(0xFF4FB989),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.chevron_left, color: Colors.white),
          const SizedBox(height: 4),
          Text(
            'Sign\nup',
            style: context.displayLarge.copyWith(
              color: Colors.white,
              fontSize: 74,
              height: 0.88,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'One step, one\nway',
            style: context.bodyMedium.copyWith(color: Colors.white.withValues(alpha: 0.9)),
          ),
          const SizedBox(height: 16),
          _outlinedField(
            controller: _emailController,
            hint: 'Email',
            icon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
            textColor: Colors.white,
          ),
          const SizedBox(height: 14),
          _outlinedField(
            controller: _passwordController,
            hint: 'Password',
            icon: Icons.lock_outline,
            obscureText: true,
            textColor: Colors.white,
          ),
          const SizedBox(height: 14),
          _outlinedField(
            controller: _confirmPasswordController,
            hint: 'Confirm Password',
            icon: Icons.lock_outline,
            obscureText: true,
            textColor: Colors.white,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Checkbox(
                value: true,
                onChanged: (_) {},
                side: BorderSide(color: Colors.white.withValues(alpha: 0.8)),
                checkColor: const Color(0xFF4FB989),
                fillColor: const WidgetStatePropertyAll(Colors.white),
                visualDensity: VisualDensity.compact,
              ),
              Expanded(
                child: Text(
                  'Accept Terms and Condition.',
                  style: context.labelLarge.copyWith(color: Colors.white.withValues(alpha: 0.9)),
                ),
              ),
            ],
          ),
          const Spacer(),
          TapScale(
            onTap: _loading
                ? null
                : () {
                    if (_passwordController.text != _confirmPasswordController.text) {
                      setState(() => _errorMessage = 'Passwords do not match');
                      return;
                    }
                    setState(() => _isLogin = false);
                    _handleEmailAuth();
                  },
            child: Text(
              _loading ? 'Loading…' : 'SignUp',
              style: context.headingMedium.copyWith(
                color: Colors.white,
                decoration: TextDecoration.underline,
                decorationColor: const Color(0xFF2AAE8A),
                decorationThickness: 4,
              ),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              _errorMessage!,
              style: context.labelSmall.copyWith(color: const Color(0xFF4A0D0D)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReferenceCardContainer({
    required double width,
    required double height,
    required Color color,
    required Widget child,
    Key? key,
  }) {
    return Container(
      key: key,
      width: width,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _socialDot({required IconData icon}) {
    return Container(
      width: 30,
      height: 30,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 18, color: const Color(0xFF737373)),
    );
  }

  Widget _outlinedField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Color textColor,
    bool obscureText = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: context.bodyMedium.copyWith(color: textColor),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: context.bodyMedium.copyWith(color: textColor.withValues(alpha: 0.8)),
        prefixIcon: Icon(icon, size: 18, color: textColor.withValues(alpha: 0.85)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: textColor.withValues(alpha: 0.65), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: textColor, width: 1.2),
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
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 18,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: context.colorSurface,
                      ),
                      child: const Icon(Icons.flag, size: 12),
                    ),
                    const SizedBox(width: 8),
                    Text(_selectedCountryCode, style: context.bodyLarge),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_down, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10), // Max 10 digits for phone number
                ],
                decoration: const InputDecoration(hintText: 'Phone number'),
                style: context.input,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        TapScale(
          onTap: _loading ? null : () {
            HapticFeedback.mediumImpact();
            _handlePhoneSubmit();
          },
          child: ElevatedButton(
            onPressed: _loading ? null : _handlePhoneSubmit,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              backgroundColor: context.colorSuccess,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: _loading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text('Sign in', style: AppTypography.button.copyWith(color: Colors.white)),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('OR', style: context.bodySecondary.copyWith(fontWeight: FontWeight.w500)),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 24),
        _buildSocialButtons(),
      ],
    );
  }

  Widget _buildSocialButtons() {
    return Column(
      children: [
        TapScale(
          onTap: () {
            // TODO: Add Google sign-in
            HapticFeedback.lightImpact();
          },
          child: Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              color: context.colorSurfaceGlass,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.colorBorder, width: 1),
              boxShadow: [
                BoxShadow(
                  color: context.colorGlassShadow,
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.network('https://upload.wikimedia.org/wikipedia/commons/5/53/Google_%22G%22_Logo.svg', height: 20,
                  errorBuilder: (_, error, stackTrace) => const Icon(Icons.account_circle, size: 20)),
                const SizedBox(width: 12),
                Text('Continue with Google', style: context.bodyMedium.copyWith(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        TapScale(
          onTap: () {
            // TODO: Add Apple sign-in
            HapticFeedback.lightImpact();
          },
          child: Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              color: context.colorSurfaceGlass,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.colorBorder, width: 1),
              boxShadow: [
                BoxShadow(
                  color: context.colorGlassShadow,
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.apple, size: 20),
                const SizedBox(width: 12),
                Text('Continue with Apple', style: context.bodyMedium.copyWith(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        TapScale(
          onTap: () {
            // TODO: Add Facebook sign-in
            HapticFeedback.lightImpact();
          },
          child: Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              color: context.colorSurfaceGlass,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.colorBorder, width: 1),
              boxShadow: [
                BoxShadow(
                  color: context.colorGlassShadow,
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.facebook, size: 20, color: Color(0xFF1877F2)),
                const SizedBox(width: 12),
                Text('Continue with Facebook', style: context.bodyMedium.copyWith(fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'By continuing, you agree to our Terms & Conditions and Privacy Policy',
          style: context.labelSmall.copyWith(color: context.colorTextSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'To learn more, see our communication preferences',
          style: context.labelSmall.copyWith(color: context.colorTextSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildMethodSwitcher() {
    return const SizedBox.shrink(); // Hide method switcher for cleaner look
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
