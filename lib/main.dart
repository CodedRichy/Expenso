import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_app.dart';
import 'firebase_options.dart';
import 'repositories/cycle_repository.dart';
import 'services/phone_auth_service.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('dotenv: .env not loaded (optional): $e');
  }
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    setFirebaseAuthAvailable(true);
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
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A1A1A)),
      ),
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/': (context) => StreamBuilder<User?>(
          stream: PhoneAuthService.instance.authStateChanges,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Scaffold(
                backgroundColor: const Color(0xFFF7F7F8),
                body: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(24, 40, 24, 32),
                        child: Text(
                          'Groups',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                            letterSpacing: -0.6,
                          ),
                        ),
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
            WidgetsBinding.instance.addPostFrameCallback((_) {
              repo.continueAuthFromFirebaseUser();
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
