import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../design/typography.dart';
import '../../repositories/cycle_repository.dart';
import '../../widgets/fade_in.dart';
import '../../widgets/tap_scale.dart';

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
    HapticFeedback.lightImpact();
    final repo = CycleRepository.instance;
    repo.setGlobalProfile(repo.currentUserPhone, name);
    FirebaseAuth.instance.currentUser?.updateDisplayName(name);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FadeIn(
                        delay: const Duration(milliseconds: 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'What should we call you?',
                              style: context.heroTitle.copyWith(height: 1.2),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'This name will appear in groups and expense logs.',
                              style: context.bodySecondary,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 48),
                      FadeIn(
                        delay: const Duration(milliseconds: 100),
                        child: TextField(
                          controller: _nameController,
                          autofocus: true,
                          textCapitalization: TextCapitalization.words,
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => handleGetStarted(),
                          decoration:
                              const InputDecoration(hintText: 'Your name'),
                          style: context.input,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: FadeIn(
                delay: const Duration(milliseconds: 200),
                child: TapScale(
                  child: ElevatedButton(
                    onPressed: _nameController.text.trim().isNotEmpty
                        ? handleGetStarted
                        : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                      minimumSize: const Size(double.infinity, 0),
                    ),
                    child: const Text(
                      'Get Started',
                      style: AppTypography.button,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
