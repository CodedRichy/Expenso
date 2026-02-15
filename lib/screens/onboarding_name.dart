import 'package:flutter/material.dart';
import '../repositories/cycle_repository.dart';

class OnboardingNameScreen extends StatefulWidget {
  const OnboardingNameScreen({super.key});

  @override
  State<OnboardingNameScreen> createState() => _OnboardingNameScreenState();
}

class _OnboardingNameScreenState extends State<OnboardingNameScreen> {
  final TextEditingController _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void handleGetStarted() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final repo = CycleRepository.instance;
    repo.setGlobalProfile(repo.currentUserPhone, name);
    // Home route (/) is ListenableBuilder; it will rebuild and show GroupsList.
  }

  @override
  Widget build(BuildContext context) {
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
                    'What should we call you?',
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
                    'This name will appear in groups and expense logs.',
                    style: TextStyle(
                      fontSize: 17,
                      color: const Color(0xFF6B6B6B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48),
              TextField(
                controller: _nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => handleGetStarted(),
                decoration: InputDecoration(
                  hintText: 'Your name',
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
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _nameController.text.trim().isNotEmpty ? handleGetStarted : null,
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
                  'Get Started',
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
}
