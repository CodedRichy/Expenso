import 'dart:ui' show PlatformDispatcher;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'design/theme.dart';
import 'firebase_app.dart';
import 'firebase_options.dart';
import 'repositories/cycle_repository.dart';
import 'services/user_profile_cache.dart';
import 'screens/phone_auth.dart';
import 'screens/onboarding_name.dart';
import 'screens/groups_list.dart';
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
import 'screens/root_screen.dart';

import 'services/locale_service.dart';
import 'screens/invite_resolver.dart';
import 'dart:async';
import 'package:app_links/app_links.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load local profile cache FIRST (instant, before any network)
  await Future.wait([
    UserProfileCache.instance.load(),
    LocaleService.instance.load(),
  ]);
  CycleRepository.instance.loadFromLocalCache();

  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('dotenv: .env not loaded (optional): $e');
  }
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    setFirebaseAuthAvailable(true);
    FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);

    // --- Crashlytics setup ---
    // Pass all Flutter framework errors to Crashlytics.
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    // Pass all async/platform errors that Flutter doesn’t catch internally.
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);

    // --- Performance monitoring ---
    await FirebasePerformance.instance.setPerformanceCollectionEnabled(true);

    debugPrint('Firebase initialized (Crashlytics + Performance enabled).');
  } catch (e, st) {
    debugPrint(
      'Firebase not configured (run: dart run flutterfire configure): $e',
    );
    debugPrint('$st');
    setFirebaseAuthAvailable(false);
  }
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
    if (uri.scheme == 'expenso' || uri.scheme.contains('expenso')) {
      final path = uri.path.replaceAll(RegExp(r'^/'), '');
      if (uri.host == 'invite' || path.startsWith('invite/')) {
        // format: expenso://invite/groupId/token
        // If host is empty but path is invite/groupId/token, handle appropriately
        final segments = uri.host == 'invite'
            ? uri.pathSegments
            : path.split('/').skip(1).toList();

        if (segments.length == 2) {
          final groupId = segments[0];
          final token = segments[1];
          // Delay pushing to allow app to finish initializing if it's a cold boot
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Future.delayed(const Duration(milliseconds: 500), () {
              globalNavigatorKey.currentState?.push(
                MaterialPageRoute(
                  builder: (context) =>
                      InviteResolverScreen(groupId: groupId, token: token),
                ),
              );
            });
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: globalNavigatorKey,
      title: 'Expenso',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      navigatorObservers: [
        FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
      ],
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
        '/undo-expense': (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>?;
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
        '/empty-states': (context) => const EmptyStates(),
        '/error-states': (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>?;
          return ErrorStates(type: args?['type'] as String? ?? 'generic');
        },
        '/profile': (context) => const ProfileScreen(),
      },
    );
  }
}
