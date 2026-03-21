import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/phone_auth_service.dart';
import '../../repositories/cycle_repository.dart';
import '../../widgets/expenso_loader.dart';
import 'phone_auth.dart';
import 'onboarding_name.dart';
import '../groups/groups_list.dart';
import '../groups/invite_resolver.dart';
import '../../services/fcm_token_service.dart';

class RootScreen extends StatelessWidget {
  const RootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _buildBody(),
    );
  }
  
  Widget _buildBody() {
    // Wrap in try-catch to handle Supabase initialization failures
    try {
      return StreamBuilder<User?>(
        initialData: Supabase.instance.client.auth.currentUser,
        stream: PhoneAuthService.instance.authStateChanges,
        builder: (context, snapshot) {
          // Handle errors in stream
          if (snapshot.hasError) {
            debugPrint('RootScreen: Auth stream error: ${snapshot.error}');
            // Fall back to login screen on error
            return const PhoneAuth();
          }
          
          if (snapshot.connectionState == ConnectionState.waiting &&
              snapshot.data == null) {
            return const Center(child: ExpensoLoader());
          }

          final user = snapshot.data;
          final repo = CycleRepository.instance;

          if (user == null) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => repo.clearAuth(),
            );
            return const PhoneAuth();
          }

          repo.setAuthUserSync(
            user.id,
            user.phone,
            user.userMetadata?['display_name'] as String?,
            photoURL: user.userMetadata?['avatar_url'] as String?,
          );

          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await repo.continueAuth();
            FcmTokenService.instance.initialize(user.id);
          });

          return ListenableBuilder(
            listenable: repo,
            builder: (context, _) {
              if (repo.currentUserName.isEmpty) {
                return const OnboardingNameScreen();
              }

              if (repo.pendingInvitation != null) {
                final invite = repo.pendingInvitation!;
                repo.pendingInvitation = null;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => InviteResolverScreen(
                        groupId: invite['groupId']!,
                        token: invite['token']!,
                      ),
                    ),
                  );
                });
              }

              return const GroupsList();
            },
          );
        },
      );
    } catch (e) {
      debugPrint('RootScreen: Supabase Auth failed: $e');
      // Show login screen if Firebase fails
      return const PhoneAuth();
    }
  }
}
