import 'package:flutter/material.dart';
import 'screens/PhoneAuth.dart';
import 'screens/GroupsList.dart';
import 'screens/CreateGroup.dart';
import 'screens/InviteMembers.dart';
import 'screens/GroupDetail.dart';
import 'screens/ExpenseInput.dart';
import 'screens/UndoExpense.dart';
import 'screens/EditExpense.dart';
import 'screens/GroupMembers.dart';
import 'screens/MemberChange.dart';
import 'screens/DeleteGroup.dart';
import 'screens/SettlementConfirmation.dart';
import 'screens/PaymentResult.dart';
import 'screens/CycleSettled.dart';
import 'screens/CycleHistory.dart';
import 'screens/CycleHistoryDetail.dart';
import 'screens/EmptyStates.dart';
import 'screens/ErrorStates.dart';

void main() {
  print("APP STARTING...");
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
        '/': (context) => const PhoneAuth(),
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
