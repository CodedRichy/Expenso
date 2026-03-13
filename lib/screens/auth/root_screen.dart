import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
      body: StreamBuilder<User?>(
        // initialData lets us resolve auth synchronously on warm restarts.
        // For cold starts the stream is in 'waiting' briefly — we show the
        // loader during that window so it is tied to real work, not a timer.
        initialData: FirebaseAuth.instance.currentUser,
        stream: PhoneAuthService.instance.authStateChanges,
        builder: (context, snapshot) {
          // Show branded loader while auth stream warms up (genuine async work).
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

          repo.setAuthFromFirebaseUserSync(
            user.uid,
            user.phoneNumber,
            user.displayName,
            photoURL: user.photoURL,
          );

          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await repo.continueAuthFromFirebaseUser();
            // Initialize FCM after auth is complete
            FcmTokenService.instance.initialize(user.uid);
          });

          return ListenableBuilder(
            listenable: repo,
            builder: (context, _) {
              if (repo.currentUserName.isEmpty) {
                return const OnboardingNameScreen();
              }

              // Check for a pending invite link that was clicked while signed out
              if (repo.pendingInvitation != null) {
                final invite = repo.pendingInvitation!;
                repo.pendingInvitation = null; // Clear it
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
      ),
    );
  }
}
