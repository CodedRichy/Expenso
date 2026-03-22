import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../design/typography.dart';
import '../../design/colors.dart';
import '../../repositories/cycle_repository.dart';
import '../../widgets/fade_in.dart';
import '../../widgets/tap_scale.dart';
import '../../widgets/gradient_scaffold.dart';
import '../../widgets/glass_card.dart';

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
    HapticFeedback.mediumImpact();
    final repo = CycleRepository.instance;
    repo.setGlobalProfile(name, phone: repo.currentUserPhone, email: repo.currentUserEmail);
    Supabase.instance.client.auth.updateUser(UserAttributes(data: {'display_name': name}));
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
              const SizedBox(height: 64),
              FadeIn(
                delay: const Duration(milliseconds: 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.colorPrimary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.face_unlock_rounded,
                        color: context.colorPrimary,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Welcome to Expenso',
                      style: context.headingLarge.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'What should we call you?',
                      style: context.bodyPrimary.copyWith(
                        color: context.colorTextSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              FadeIn(
                delay: const Duration(milliseconds: 300),
                child: GlassCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      TextField(
                        controller: _nameController,
                        autofocus: true,
                        textCapitalization: TextCapitalization.words,
                        textAlign: TextAlign.center,
                        onChanged: (_) => setState(() {}),
                        onSubmitted: (_) => handleGetStarted(),
                        style: context.displayMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Your Name',
                          hintStyle: context.displayMedium.copyWith(
                            color: context.colorTextTertiary.withValues(alpha: 0.3),
                            fontWeight: FontWeight.w600,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 2,
                        width: 120,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              context.colorPrimary.withValues(alpha: 0),
                              context.colorPrimary,
                              context.colorPrimary.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              FadeIn(
                delay: const Duration(milliseconds: 500),
                child: TapScale(
                  onTap: _nameController.text.trim().isNotEmpty
                      ? handleGetStarted
                      : null,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      color: _nameController.text.trim().isNotEmpty 
                        ? context.colorTextPrimary
                        : context.colorTextPrimary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: _nameController.text.trim().isNotEmpty ? [
                        BoxShadow(
                          color: context.colorTextPrimary.withValues(alpha: 0.15),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        )
                      ] : null,
                    ),
                    child: Center(
                      child: Text(
                        'Get Started',
                        style: context.labelLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
