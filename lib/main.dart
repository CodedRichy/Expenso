import 'package:flutter/material.dart';
import 'repositories/cycle_repository.dart';
import 'screens/phone_auth.dart';
import 'screens/onboarding_name.dart';
import 'screens/groups_list.dart';
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

void main() {
  debugPrint("APP STARTING...");
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
      initialRoute: '/',
      routes: {
        '/': (context) => ListenableBuilder(
          listenable: CycleRepository.instance,
          builder: (context, _) {
            final repo = CycleRepository.instance;
            if (repo.currentUserPhone.isEmpty) return const PhoneAuth();
            if (repo.currentUserName.isEmpty) return const OnboardingNameScreen();
            return const GroupsList();
          },
        ),
        '/groups': (context) => const GroupsList(),
        '/create-group': (context) => const CreateGroup(),
        '/invite-members': (context) => const InviteMembers(),
        '/group-detail': (context) => const GroupDetail(),
        '/expense-input': (context) => const ExpenseInput(),
        '/undo-expense': (context) => const UndoExpense(),
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
        '/error-states': (context) => const ErrorStates(),
      },
    );
  }
}
