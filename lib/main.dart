import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'design/colors.dart';
import 'design/typography.dart';
import 'firebase_app.dart';
import 'firebase_options.dart';
import 'repositories/cycle_repository.dart';
import 'services/phone_auth_service.dart';
import 'services/user_profile_cache.dart';
import 'screens/phone_auth.dart';
import 'screens/onboarding_name.dart';
import 'screens/groups_list.dart';
import 'screens/group_list_skeleton.dart';
import 'screens/create_group.dart';
import 'screens/invite_members.dart';
import 'screens/group_detail.dart';
import 'screens/expense_input.dart';
import 'screens/undo_expense.dart';
import 'screens/edit_expense.dart';
import 'screens/group_members.dart';
import 'screens/member_change.dart';
import 'screens/delete_group.dart';
import 'screens/settlement_confirmation.dart';
import 'screens/payment_result.dart';
import 'screens/cycle_settled.dart';
import 'screens/cycle_history.dart';
import 'screens/cycle_history_detail.dart';
import 'screens/empty_states.dart';
import 'screens/error_states.dart';
import 'screens/global_balances.dart';
import 'screens/profile.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load local profile cache FIRST (instant, before any network)
  // This enables immediate avatar rendering on cold start
  await UserProfileCache.instance.load();
  CycleRepository.instance.loadFromLocalCache();
  
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('dotenv: .env not loaded (optional): $e');
  }
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    setFirebaseAuthAvailable(true);
    FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
    debugPrint("Firebase initialized.");
  } catch (e, st) {
    debugPrint("Firebase not configured (run: dart run flutterfire configure): $e");
    debugPrint("$st");
    setFirebaseAuthAvailable(false);
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expenso',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          surface: AppColors.surface,
          error: AppColors.error,
        ),
        scaffoldBackgroundColor: AppColors.background,
        textTheme: const TextTheme(
          displayLarge: AppTypography.heroTitle,
          headlineLarge: AppTypography.screenTitle,
          headlineMedium: AppTypography.subheader,
          titleLarge: AppTypography.appBarTitle,
          titleMedium: AppTypography.listItemTitle,
          bodyLarge: AppTypography.bodyPrimary,
          bodyMedium: AppTypography.bodySecondary,
          labelLarge: AppTypography.button,
          labelMedium: AppTypography.sectionLabel,
          bodySmall: AppTypography.caption,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            disabledBackgroundColor: AppColors.disabledBackground,
            foregroundColor: AppColors.surface,
            disabledForegroundColor: AppColors.disabledForeground,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 0,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.textPrimary,
            side: const BorderSide(color: AppColors.border),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.accent,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surface,
          hintStyle: AppTypography.hint,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.borderInput),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.borderInput),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.borderFocused),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.error),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.border,
          thickness: 1,
          space: 0,
        ),
      ),
      navigatorObservers: [
        FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
      ],
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/': (context) => StreamBuilder<User?>(
          stream: PhoneAuthService.instance.authStateChanges,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Scaffold(
                backgroundColor: AppColors.background,
                body: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(24, 40, 24, 32),
                        child: Text('Groups', style: AppTypography.heroTitle),
                      ),
                      const Expanded(child: GroupListSkeleton()),
                    ],
                  ),
                ),
              );
            }
            final user = snapshot.data;
            final repo = CycleRepository.instance;
            if (user == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) => repo.clearAuth());
              return const PhoneAuth();
            }
            repo.setAuthFromFirebaseUserSync(
              user.uid,
              user.phoneNumber,
              user.displayName,
            );
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              await repo.continueAuthFromFirebaseUser();
            });
            return ListenableBuilder(
              listenable: repo,
              builder: (context, _) {
                if (repo.currentUserName.isEmpty) return const OnboardingNameScreen();
                return const GroupsList();
              },
            );
          },
        ),
        '/groups': (context) => const GroupsList(),
        '/create-group': (context) => const CreateGroup(),
        '/invite-members': (context) => const InviteMembers(),
        '/group-detail': (context) => const GroupDetail(),
        '/expense-input': (context) => const ExpenseInput(),
        '/undo-expense': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return UndoExpense(
            groupId: args?['groupId'] as String?,
            expenseId: args?['expenseId'] as String?,
            description: args?['description'] as String?,
            amount: (args?['amount'] as num?)?.toDouble(),
          );
        },
        '/edit-expense': (context) => const EditExpense(),
        '/group-members': (context) => const GroupMembers(),
        '/member-change': (context) => const MemberChange(),
        '/delete-group': (context) => const DeleteGroup(),
        '/settlement-confirmation': (context) => const SettlementConfirmation(),
        '/payment-result': (context) => const PaymentResult(),
        '/cycle-settled': (context) => const CycleSettled(),
        '/cycle-history': (context) => const CycleHistory(),
        '/cycle-history-detail': (context) => const CycleHistoryDetail(),
        '/empty-states': (context) => const EmptyStates(),
        '/error-states': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return ErrorStates(type: args?['type'] as String? ?? 'generic');
        },
        '/profile': (context) => const ProfileScreen(),
        '/global-balances': (context) => const GlobalBalancesScreen(),
      },
    );
  }
}
