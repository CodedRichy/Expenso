import 'dart:async';

import 'package:flutter/material.dart';
import 'design/theme.dart';
import 'repositories/cycle_repository.dart';
import 'services/user_profile_cache.dart';
import 'screens/groups/groups_list.dart';
import 'screens/groups/create_group.dart';
import 'models/models.dart';
import 'screens/groups/invite_members.dart';
import 'screens/groups/group_detail.dart';
import 'screens/expenses/expense_input.dart';
import 'screens/expenses/edit_expense.dart';
import 'screens/groups/group_members.dart';
import 'screens/settlement/settlement_confirmation.dart';
import 'screens/settlement/payment_result.dart';
import 'screens/settlement/cycle_settled.dart';
import 'screens/settlement/cycle_history.dart';
import 'screens/settlement/cycle_history_detail.dart';
import 'screens/settings/profile.dart';
import 'screens/auth/root_screen.dart';

import 'services/locale_service.dart';
import 'screens/groups/invite_resolver.dart';
import 'package:app_links/app_links.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env explicitly
  await dotenv.load(fileName: ".env");

  // Initialize Supabase. Read credentials from .env
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  // Load local profile cache FIRST (instant, before any network)
  await Future.wait([
    UserProfileCache.instance.load(),
    LocaleService.instance.load(),
  ]);
  CycleRepository.instance.loadFromLocalCache();

  runApp(const MyApp());
}

final GlobalKey<NavigatorState> globalNavigatorKey =
    GlobalKey<NavigatorState>();

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    // Check initial link if app was cold-started by a deep link
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) _handleLink(initialUri);
    } catch (e) {
      debugPrint('Error getting initial app link: $e');
    }

    // Listen to links while app is running/backgrounded
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        _handleLink(uri);
      },
      onError: (err) {
        debugPrint('Error listening to app links: $err');
      },
    );
  }

  void _handleLink(Uri uri) {
    debugPrint('Received deep link: $uri');

    String? groupId;
    String? token;

    if (uri.scheme == 'expenso' || uri.scheme.contains('expenso')) {
      final path = uri.path.replaceAll(RegExp(r'^/'), '');
      if (uri.host == 'invite' || path.startsWith('invite/')) {
        // format: expenso://invite/groupId/token
        final segments = uri.host == 'invite'
            ? uri.pathSegments
            : path.split('/').skip(1).toList();

        if (segments.length >= 2) {
          groupId = segments[0];
          token = segments[1];
        }
      }
    } else if (uri.scheme == 'https' &&
        (uri.host == 'expenso-e138a.web.app' ||
            uri.host == 'expenso-e138a.firebaseapp.com')) {
      // format: https://expenso-e138a.web.app/invite/groupId/token
      if (uri.pathSegments.length >= 3 && uri.pathSegments[0] == 'invite') {
        groupId = uri.pathSegments[1];
        token = uri.pathSegments[2];
      }
    }

    if (groupId != null && token != null) {
      final repo = CycleRepository.instance;
      if (Supabase.instance.client.auth.currentUser == null) {
        repo.pendingInvitation = {'groupId': groupId, 'token': token};
        debugPrint('Stored pending invitation: ${repo.pendingInvitation}');
        return;
      }

      // Delay pushing to allow app to finish initializing if it's a cold boot
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 500), () {
          globalNavigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (context) =>
                  InviteResolverScreen(groupId: groupId!, token: token!),
            ),
          );
        });
      });
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final observers = <NavigatorObserver>[];
    
    return MaterialApp(
      navigatorKey: globalNavigatorKey,
      title: 'Expenso',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      navigatorObservers: observers,
      initialRoute: '/',
      routes: {
        '/': (context) => const RootScreen(),
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
        '/edit-expense': (context) => const EditExpense(),
        '/group-members': (context) {
          final group = ModalRoute.of(context)?.settings.arguments as Group?;
          return GroupMembers(group: group);
        },
        '/settlement-confirmation': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          final group = args is Group
              ? args
              : (args is Map<String, dynamic> ? args['group'] as Group? : null);
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
          return PaymentResult(
            group: group,
            status: status,
            amount: amount,
            transactionId: transactionId,
          );
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
        '/profile': (context) => const ProfileScreen(),
      },
    );
  }
}
