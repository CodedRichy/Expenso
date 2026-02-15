import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../repositories/cycle_repository.dart';

class PhoneAuth extends StatefulWidget {
  const PhoneAuth({super.key});

  @override
  State<PhoneAuth> createState() => _PhoneAuthState();
}

class _PhoneAuthState extends State<PhoneAuth> {
  String phone = '';
  String otp = '';
  String step = 'phone'; // 'phone' or 'otp'

  void handlePhoneSubmit() {
    if (phone.length == 10) {
      setState(() {
        step = 'otp';
      });
    }
  }

  void handleOtpSubmit() {
    if (otp.length == 6) {
      final formattedPhone = _formatPhone(phone);
      CycleRepository.instance.setGlobalProfile(formattedPhone, '');
      // Home route (/) listens to repo and will rebuild to show OnboardingNameScreen or GroupsList.
    }
  }

  static String _formatPhone(String digits) {
    if (digits.length == 10) {
      return '+91 ${digits.substring(0, 5)} ${digits.substring(5)}';
    }
    return digits.isEmpty ? '' : '+91 $digits';
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
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: phone.length == 10 ? handlePhoneSubmit : null,
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
                  child: Text(
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

    // OTP step
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
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: otp.length == 6 ? handleOtpSubmit : null,
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
                child: Text(
                  'Verify',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  setState(() {
                    step = 'phone';
                    otp = '';
                  });
                },
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
