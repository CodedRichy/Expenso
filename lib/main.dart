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
import 'widgets/expenso_loader.dart';
import 'screens/create_group.dart';
import 'models/models.dart';
import 'screens/invite_members.dart';
import 'screens/group_detail.dart';
import 'screens/expense_input.dart';
import 'screens/undo_expense.dart';
import 'screens/edit_expense.dart';
import 'screens/group_members.dart';
import 'screens/member_change.dart';
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
import 'services/theme_service.dart';
import 'services/locale_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load local profile cache and theme FIRST (instant, before any network)
  await Future.wait([
    UserProfileCache.instance.load(),
    ThemeService.instance.load(),
    LocaleService.instance.load(),
  ]);
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
  
  final primary = isDark ? AppColorsDark.primary : AppColors.primary;
  final surface = isDark ? AppColorsDark.surface : AppColors.surface;
  final background = isDark ? AppColorsDark.background : AppColors.background;
  final error = isDark ? AppColorsDark.error : AppColors.error;
  final textPrimary = isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
  final textSecondary = isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;
  final textTertiary = isDark ? AppColorsDark.textTertiary : AppColors.textTertiary;
  final textDisabled = isDark ? AppColorsDark.textDisabled : AppColors.textDisabled;
  final border = isDark ? AppColorsDark.border : AppColors.border;
  final borderInput = isDark ? AppColorsDark.borderInput : AppColors.borderInput;
  final borderFocused = isDark ? AppColorsDark.borderFocused : AppColors.borderFocused;
  final accent = isDark ? AppColorsDark.accent : AppColors.accent;
  final disabledBg = isDark ? AppColorsDark.disabledBackground : AppColors.disabledBackground;
  final disabledFg = isDark ? AppColorsDark.disabledForeground : AppColors.disabledForeground;

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
      color: isDark ? AppColorsDark.cardGradientStart : AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isDark ? AppColorsDark.cardBorder : AppColors.cardBorder),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: isDark ? AppColorsDark.cardGradientStart : AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: isDark ? AppColorsDark.cardGradientStart : AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: isDark ? AppColorsDark.cardGradientEnd : const Color(0xFF323232),
      contentTextStyle: AppTypography.bodyPrimary.copyWith(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeService.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'Expenso',
          debugShowCheckedModeBanner: false,
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          themeMode: ThemeService.instance.themeMode,
          navigatorObservers: [
            FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
          ],
          initialRoute: '/splash',
          routes: {
        '/splash': (context) => const SplashScreen(),
        '/groups': (context) => const GroupsList(),
        '/create-group': (context) => const CreateGroup(),
        '/invite-members': (context) {
          final group = ModalRoute.of(context)?.settings.arguments as Group?;
          return InviteMembers(group: group, groupName: group?.name ?? 'Group');
        },
        '/group-detail': (context) {
          final group = ModalRoute.of(context)?.settings.arguments as Group?;
          return GroupDetail(group: group);
        },
        '/expense-input': (context) {
          final group = ModalRoute.of(context)?.settings.arguments as Group?;
          return ExpenseInput(group: group);
        },
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
        '/group-members': (context) {
          final group = ModalRoute.of(context)?.settings.arguments as Group?;
          return GroupMembers(group: group);
        },
        '/member-change': (context) => const MemberChange(),
        '/settlement-confirmation': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          final group = args is Group ? args : (args is Map<String, dynamic> ? args['group'] as Group? : null);
          return SettlementConfirmation(group: group);
        },
        '/payment-result': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          Group? group;
          String status = 'success';
          double? amount;
          String? transactionId;
          if (args is Group) {
            group = args;
          } else if (args is Map<String, dynamic>) {
            group = args['group'] as Group?;
            status = args['status'] as String? ?? status;
            amount = (args['amount'] as num?)?.toDouble();
            transactionId = args['transactionId'] as String?;
          }
          return PaymentResult(group: group, status: status, amount: amount, transactionId: transactionId);
        },
        '/cycle-settled': (context) {
          final group = ModalRoute.of(context)?.settings.arguments as Group?;
          return CycleSettled(group: group);
        },
        '/cycle-history': (context) {
          final group = ModalRoute.of(context)?.settings.arguments as Group?;
          return CycleHistory(group: group);
        },
        '/cycle-history-detail': (context) => const CycleHistoryDetail(),
        '/empty-states': (context) => const EmptyStates(),
        '/error-states': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          return ErrorStates(type: args?['type'] as String? ?? 'generic');
        },
        '/profile': (context) => const ProfileScreen(),
        },
        onGenerateRoute: (settings) {
          if (settings.name == '/') {
            return PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const RootScreen(),
              transitionDuration: const Duration(milliseconds: 200),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            );
          }
          return null;
        },
      );
    },
  );
  }
}

class RootScreen extends StatelessWidget {
  const RootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: PhoneAuthService.instance.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: ExpensoLoader()),
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
            if (repo.currentUserName.isEmpty) return const OnboardingNameScreen();
            return const GroupsList();
          },
        );
      },
    );
  }
}
