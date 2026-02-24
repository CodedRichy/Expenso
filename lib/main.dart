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
import 'screens/profile.dart';
import 'screens/splash_screen.dart';
import 'services/fcm_token_service.dart';

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

ThemeData _buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  
  final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;
  final surface = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
  final background = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
  final error = isDark ? AppColors.errorDark : AppColors.errorLight;
  final textPrimary = isDark ? const Color(0xFFF5F5F5) : const Color(0xFF1A1A1A);
  final textSecondary = isDark ? const Color(0xFFB0B0B0) : const Color(0xFF6B6B6B);
  final textTertiary = isDark ? const Color(0xFF808080) : const Color(0xFF9B9B9B);
  final textDisabled = isDark ? const Color(0xFF606060) : const Color(0xFFB0B0B0);
  final border = isDark ? const Color(0xFF3A3A3A) : const Color(0xFFE5E5E5);
  final borderInput = isDark ? const Color(0xFF4A4A4A) : const Color(0xFFD0D0D0);
  final borderFocused = isDark ? const Color(0xFFE5E5E5) : const Color(0xFF1A1A1A);
  final accent = isDark ? const Color(0xFF7BA3C4) : const Color(0xFF5B7C99);
  final disabledBg = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E5E5);
  final disabledFg = isDark ? const Color(0xFF606060) : const Color(0xFFB0B0B0);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
      surface: surface,
      error: error,
    ),
    scaffoldBackgroundColor: background,
    textTheme: TextTheme(
      displayLarge: AppTypography.heroTitle.copyWith(color: textPrimary),
      headlineLarge: AppTypography.screenTitle.copyWith(color: textPrimary),
      headlineMedium: AppTypography.subheader.copyWith(color: textPrimary),
      titleLarge: AppTypography.appBarTitle.copyWith(color: textPrimary),
      titleMedium: AppTypography.listItemTitle.copyWith(color: textPrimary),
      bodyLarge: AppTypography.bodyPrimary.copyWith(color: textPrimary),
      bodyMedium: AppTypography.bodySecondary.copyWith(color: textSecondary),
      labelLarge: AppTypography.button.copyWith(color: textPrimary),
      labelMedium: AppTypography.sectionLabel.copyWith(color: textTertiary),
      bodySmall: AppTypography.caption.copyWith(color: textTertiary),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        disabledBackgroundColor: disabledBg,
        foregroundColor: surface,
        disabledForegroundColor: disabledFg,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        side: BorderSide(color: border),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: accent,
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      hintStyle: AppTypography.hint.copyWith(color: textDisabled),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: borderInput),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: borderInput),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: borderFocused),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: error),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    dividerTheme: DividerThemeData(color: border, thickness: 1, space: 0),
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: textPrimary,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: border),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFF323232),
      contentTextStyle: AppTypography.bodyPrimary.copyWith(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expenso',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
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
                body: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
                        child: Text('Groups', style: Theme.of(context).textTheme.displayLarge),
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
              // Initialize FCM after auth is complete
              FcmTokenService.instance.initialize(user.uid);
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
      },
    );
  }
}
