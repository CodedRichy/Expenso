import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import '../../design/colors.dart';
import '../../design/spacing.dart';
import '../../design/typography.dart';
import '../../models/models.dart';
import '../../repositories/cycle_repository.dart';
import '../../services/connectivity_service.dart';
import '../../services/groq_expense_parser_service.dart';
import '../../services/locale_service.dart';
import '../../services/receipt_scanner_service.dart';
import '../../services/feature_flag_service.dart';
import '../../utils/expense_normalization.dart';
import '../../utils/money_format.dart';
import '../../utils/route_args.dart';
import '../../utils/settlement_engine.dart';
import '../../widgets/expenso_loader.dart';
import '../../widgets/gradient_scaffold.dart';
import '../../widgets/member_avatar.dart';
import '../../widgets/offline_banner.dart';
import '../../widgets/settlement_activity_feed.dart';
import '../../widgets/settlement_progress_indicator.dart';
import '../../widgets/staggered_list_item.dart';
import '../../widgets/undo_toast.dart';
import '../common/empty_states.dart';
import '../../widgets/tap_scale.dart';

part 'group_detail_smart_bar.dart';
class _StyledDescription {
  final String main;
  final String? suffix;

  _StyledDescription(this.main, this.suffix);
}

_StyledDescription _buildViewerRelativeDescription({
  required Expense expense,
  required CycleRepository repo,
}) {
  final baseDesc = expense.description;
  final currentUserId = repo.currentUserId;
  final participantIds = expense.participantIds;

  final otherParticipants = participantIds
      .where((id) => id != currentUserId)
      .toList();

  final withPattern = RegExp(r'\s*[-–—]\s*with\s+.+$', caseSensitive: false);
  final cleanDesc = baseDesc.replaceAll(withPattern, '').trim();

  if (otherParticipants.isEmpty) {
    return _StyledDescription(cleanDesc, null);
  }

  final otherCount = otherParticipants.length;

  if (otherCount >= 4) {
    return _StyledDescription(cleanDesc, 'with $otherCount others');
  }

  final withNames = otherParticipants
      .map((id) => repo.getMemberDisplayNameById(id))
      .toList();

  final descLower = cleanDesc.toLowerCase();
  final namesNotInDesc = withNames
      .where((n) => !descLower.contains(n.toLowerCase()))
      .toList();

  if (namesNotInDesc.isEmpty) {
    return _StyledDescription(cleanDesc, null);
  }

  return _StyledDescription(cleanDesc, 'with ${namesNotInDesc.join(', ')}');
}


class GroupDetail extends StatefulWidget {
  final Group? group;

  const GroupDetail({super.key, this.group});

  @override
  State<GroupDetail> createState() => _GroupDetailState();
}

class _GroupDetailState extends State<GroupDetail> {
  bool _profilesRefreshed = false;
  String? _initializedGroupId;

  @override
  void dispose() {
    if (_initializedGroupId != null) {
      CycleRepository.instance.unfocusGroupStreams(_initializedGroupId!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = CycleRepository.instance;
    final routeGroup = RouteArgs.getGroup(context);
    final resolvedGroup = routeGroup ?? widget.group;
    if (resolvedGroup == null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => Navigator.maybePop(context),
      );
      return const Scaffold(body: SizedBox.shrink());
    }
    final groupId = resolvedGroup.id;

    if (!_profilesRefreshed) {
      _profilesRefreshed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        repo.refreshGroupMemberProfiles(groupId);
        repo.ensureGroupStreams(groupId);
      });
      _initializedGroupId = groupId;
    }

    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final defaultGroup = repo.getGroup(groupId);
        if (defaultGroup == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          });
          return const Scaffold(body: Center(child: ExpensoLoader()));
        }
        final activeCycle = repo.getActiveCycle(groupId);
        final expenses = repo.getExpenses(activeCycle.id);
        final systemMessages = repo.getSystemMessages(groupId);
        final isPassive = activeCycle.status == CycleStatus.settling;
        final isSettled =
            activeCycle.status == CycleStatus.closed ||
            defaultGroup.status == 'settled';
        final hasExpenses = expenses.isNotEmpty || systemMessages.isNotEmpty;
        final theme = Theme.of(context);

        return GradientScaffold(
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OfflineBanner(
                  onRetry: () => ConnectivityService.instance.checkNow(),
                ),
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _StickyHeaderDelegate(
                          height: 52,
                          backgroundColor: theme.brightness == Brightness.dark
                              ? AppColorsDark.backgroundGradientStart
                              : AppColors.background,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TapScale(
                                  child: IconButton(
                                    onPressed: () => Navigator.pop(context),
                                    icon: const Icon(
                                      Icons.chevron_left,
                                      size: 24,
                                    ),
                                    color: theme.colorScheme.onSurface,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    style: IconButton.styleFrom(
                                      minimumSize: const Size(32, 32),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    defaultGroup.name,
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.onSurface,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                ),
                                TapScale(
                                  child: IconButton(
                                    onPressed: () {
                                      Navigator.pushNamed(
                                        context,
                                        '/group-members',
                                        arguments: defaultGroup,
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.people_outline,
                                      size: 24,
                                    ),
                                    color: theme.colorScheme.onSurface,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    style: IconButton.styleFrom(
                                      minimumSize: const Size(32, 32),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (expenses.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                            child: _DecisionClarityCard(
                              repo: repo,
                              groupId: groupId,
                              groupName: defaultGroup.name,
                              expenses: expenses,
                              isSettled: isSettled,
                              isPassive: isPassive,
                            ),
                          ),
                        ),
                      if (isPassive)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                            child: SettlementProgressIndicator(
                              groupId: groupId,
                            ),
                          ),
                        ),
                      if (!isSettled)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                            child: SettlementActivityTapToExpand(
                              groupId: groupId,
                            ),
                          ),
                        ),
                      if (!isSettled &&
                          (repo.getGroupPendingAmount(groupId) > 0 ||
                              isPassive))
                        SliverToBoxAdapter(
                          child: Builder(
                            builder: (context) {
                              final fullySettled =
                                  isPassive && repo.isFullySettled(groupId);
                              final isCreator = repo.isCurrentUserCreator(
                                groupId,
                              );

                              return Padding(
                                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TapScale(
                                      child: ElevatedButton(
                                        onPressed: () {
                                          Navigator.pushNamed(
                                            context,
                                            '/settlement-confirmation',
                                            arguments: {
                                              'group': defaultGroup,
                                              'method': 'upi',
                                            },
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          elevation: 0,
                                          minimumSize: const Size(
                                            double.infinity,
                                            0,
                                          ),
                                        ),
                                        child: const Text(
                                          'Settlement',
                                          style: AppTypography.button,
                                        ),
                                      ),
                                    ),
                                    if (isCreator) ...[
                                      const SizedBox(height: 10),
                                      TapScale(
                                        child: ElevatedButton(
                                          onPressed: () async {
                                            if (isPassive) {
                                              final confirmed = await showDialog<bool>(
                                                context: context,
                                                builder: (ctx) => AlertDialog(
                                                  title: const Text(
                                                    'Start new cycle?',
                                                  ),
                                                  content: Text(
                                                    fullySettled
                                                        ? 'All payments are complete. Ready to start a fresh cycle.'
                                                        : 'This will archive current expenses and start a fresh cycle.',
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                            ctx,
                                                            false,
                                                          ),
                                                      child: const Text(
                                                        'Cancel',
                                                      ),
                                                    ),
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                            ctx,
                                                            true,
                                                          ),
                                                      child: const Text(
                                                        'Confirm',
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                              if (confirmed != true ||
                                                  !context.mounted) {
                                                return;
                                              }
                                            } else {
                                              _showSettleConfirmDialog(
                                                context,
                                                repo,
                                                groupId,
                                              );
                                              return;
                                            }
                                            if (ConnectivityService
                                                .instance
                                                .isOffline) {
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Cannot start new cycle while offline',
                                                    ),
                                                    behavior: SnackBarBehavior
                                                        .floating,
                                                  ),
                                                );
                                              }
                                              return;
                                            }
                                            try {
                                              await repo.archiveAndRestart(
                                                groupId,
                                              );
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'New cycle started.',
                                                    ),
                                                    behavior: SnackBarBehavior
                                                        .floating,
                                                  ),
                                                );
                                              }
                                            } catch (e) {
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Could not start new cycle: ${e.toString().replaceFirst(RegExp(r'^Exception:?\s*'), '')}',
                                                    ),
                                                    behavior: SnackBarBehavior
                                                        .floating,
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 14,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            elevation: 0,
                                            minimumSize: const Size(
                                              double.infinity,
                                              0,
                                            ),
                                          ),
                                          child: Text(
                                            isPassive
                                                ? (fullySettled
                                                      ? 'Start New Cycle ✓'
                                                      : 'Start New Cycle')
                                                : 'Close cycle',
                                            style: AppTypography.button,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ...(hasExpenses
                          ? <Widget>[
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(
                                  24,
                                  16,
                                  24,
                                  16,
                                ),
                                sliver: SliverToBoxAdapter(
                                  child: Text(
                                    'EXPENSE LOG',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              ),
                              SliverList(
                                delegate: SliverChildBuilderDelegate((
                                  context,
                                  index,
                                ) {
                                  final expense = expenses[index];
                                  return StaggeredListItem(
                                    index: index,
                                    child: TapScale(
                                      scaleDown: 0.99,
                                      child: InkWell(
                                        onTap: isPassive
                                            ? null
                                            : () {
                                                Navigator.pushNamed(
                                                  context,
                                                  '/edit-expense',
                                                  arguments: {
                                                    'expenseId': expense.id,
                                                    'groupId': defaultGroup.id,
                                                  },
                                                );
                                              },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 24,
                                            vertical: 14,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border(
                                              top: index > 0
                                                  ? BorderSide(
                                                      color: Theme.of(
                                                        context,
                                                      ).dividerColor,
                                                      width: 1,
                                                    )
                                                  : BorderSide.none,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Builder(
                                                      builder: (context) {
                                                        final desc =
                                                            _buildViewerRelativeDescription(
                                                              expense: expense,
                                                              repo: repo,
                                                            );
                                                        return Text.rich(
                                                          TextSpan(
                                                            children: [
                                                              TextSpan(
                                                                text: desc.main,
                                                                style: TextStyle(
                                                                  fontSize: 17,
                                                                  color: Theme.of(
                                                                    context,
                                                                  ).colorScheme.onSurface,
                                                                ),
                                                              ),
                                                              if (desc.suffix !=
                                                                  null) ...[
                                                                const TextSpan(
                                                                  text: '  ',
                                                                ),
                                                                TextSpan(
                                                                  text: desc
                                                                      .suffix,
                                                                  style: TextStyle(
                                                                    fontSize:
                                                                        14,
                                                                    color: Theme.of(
                                                                      context,
                                                                    ).colorScheme.onSurfaceVariant,
                                                                  ),
                                                                ),
                                                              ],
                                                            ],
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      expense.displayDate,
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              Text(
                                                formatMoneyFromMajor(
                                                  expense.amount,
                                                  defaultGroup.currencyCode,
                                                  LocaleService
                                                      .instance
                                                      .localeCode,
                                                ),
                                                style: TextStyle(
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.w600,
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.onSurface,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }, childCount: expenses.length),
                              ),
                              SliverList(
                                delegate: SliverChildBuilderDelegate((
                                  context,
                                  index,
                                ) {
                                  final msg = systemMessages[index];
                                  String text;
                                  switch (msg.type) {
                                    case 'joined':
                                      text = '${msg.userName} joined the group';
                                      break;
                                    case 'declined':
                                      text =
                                          '${msg.userName} declined the invitation';
                                      break;
                                    case 'left':
                                      text = '${msg.userName} left the group';
                                      break;
                                    case 'created':
                                      text =
                                          '${msg.userName} created the group';
                                      break;
                                    default:
                                      text = '${msg.userName} ${msg.type}';
                                  }
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            text,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          msg.date,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }, childCount: systemMessages.length),
                              ),
                            ]
                          : [
                              SliverFillRemaining(
                                hasScrollBody: false,
                                child: EmptyStates(
                                  type: 'no-expenses-new-cycle',
                                ),
                              ),
                            ]),
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    ],
                  ),
                ),
                if (!isSettled)
                  isPassive
                      ? _LockedSpendBar(group: defaultGroup)
                      : _SmartBarSection(group: defaultGroup),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSettleConfirmDialog(
    BuildContext context,
    CycleRepository repo,
    String groupId,
  ) {
    final theme = Theme.of(context);
    final instructions = repo.getSettlementInstructions(groupId);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Settle & Restart',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                instructions.isEmpty
                    ? 'No balances to settle.'
                    : 'The following will close this cycle:',
                style: TextStyle(
                  fontSize: 15,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (instructions.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...instructions.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      s,
                      style: TextStyle(
                        fontSize: 15,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (ConnectivityService.instance.isOffline) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Cannot settle while offline'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
                return;
              }
              try {
                await repo.archiveAndRestart(groupId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Cycle settled. New cycle started.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Could not settle: ${e.toString().replaceFirst(RegExp(r'^Exception:?\s*'), '')}',
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: Text(
              'Confirm',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;
  final Color backgroundColor;

  _StickyHeaderDelegate({
    required this.height,
    required this.child,
    required this.backgroundColor,
  });

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(height: height, color: backgroundColor, child: child);
  }

  @override
  bool shouldRebuild(covariant _StickyHeaderDelegate oldDelegate) =>
      oldDelegate.height != height ||
      oldDelegate.backgroundColor != backgroundColor;
}

String _formatAmount(double value, String currencyCode) {
  if (value.isNaN || value.isInfinite) {
    return formatMoneyFromMajor(
      0,
      currencyCode,
      LocaleService.instance.localeCode,
    );
  }
  return formatMoneyFromMajor(
    value,
    currencyCode,
    LocaleService.instance.localeCode,
  );
}

class _DecisionClarityCard extends StatelessWidget {
  final CycleRepository repo;
  final String groupId;
  final String groupName;
  final List<Expense> expenses;
  final bool isSettled;
  final bool isPassive;

  const _DecisionClarityCard({
    required this.repo,
    required this.groupId,
    required this.groupName,
    required this.expenses,
    required this.isSettled,
    required this.isPassive,
  });

  static const double _minHeight = 132.0;

  void _showSettlementDetails(BuildContext context) {
    final members = repo.getMembersForGroup(groupId);
    final currencyCode = repo.getGroup(groupId)?.currencyCode ?? 'INR';
    final netMinor = repo.getNetBalancesAfterSettlementsMinor(groupId);
    final routes = SettlementEngine.computePaymentRoutes(
      netMinor,
      currencyCode,
    );
    final debts = routes
        .map(
          (r) => Debt(
            fromId: r.fromMemberId,
            toId: r.toMemberId,
            amount: r.amount,
          ),
        )
        .toList();
    final myId = repo.currentUserId;
    final netBalances = SettlementEngine.computeNetBalancesAsDouble(
      expenses,
      members,
    );
    double myNet = netBalances[myId] ?? 0.0;
    if (myNet.isNaN || myNet.isInfinite) myNet = 0.0;
    final myRemaining = repo.getRemainingBalance(groupId, myId);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SettlementDetailsSheet(
        repo: repo,
        groupId: groupId,
        groupName: groupName,
        currencyCode: currencyCode,
        debts: debts,
        myId: myId,
        myNet: myNet,
        myRemaining: myRemaining,
        isPassive: isPassive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEmpty = expenses.isEmpty;
    final currencyCode = repo.getGroup(groupId)?.currencyCode ?? 'INR';
    final cycleTotal = expenses.fold<double>(0.0, (s, e) => s + e.amount);
    final members = repo.getMembersForGroup(groupId);
    final netBalances = SettlementEngine.computeNetBalancesAsDouble(
      expenses,
      members,
    );
    final myId = repo.currentUserId;

    double youPaid = 0.0;
    for (final e in expenses) {
      if (e.paidById == myId) {
        youPaid += e.amount;
      }
    }
    final settledPaid = repo.getSettlementPaidByMember(groupId, myId);

    double myNet = netBalances[myId] ?? 0.0;
    if (myNet.isNaN || myNet.isInfinite) myNet = 0.0;

    final myRemaining = repo.getRemainingBalance(groupId, myId);
    final hasPaymentProgress = (myNet - myRemaining).abs() > 0.01;

    final isCredit = myRemaining > 0;
    final isDebt = myRemaining < 0;
    final isBalanceClear = myRemaining.abs() < 0.01;

    final isMuted = isPassive;

    final semanticsLabel = isEmpty
        ? 'Balance summary. Zero-waste cycle. Add expenses to see totals.'
        : 'Balance summary. Cycle total ${_formatAmount(cycleTotal, currencyCode)}. '
              'You paid ${_formatAmount(youPaid, currencyCode)}. '
              '${isBalanceClear
                  ? "All clear."
                  : isCredit
                  ? "You are owed ${_formatAmount(myRemaining.abs(), currencyCode)}."
                  : "You owe ${_formatAmount(myRemaining.abs(), currencyCode)}."}';

    return Semantics(
      label: semanticsLabel,
      button: !isEmpty,
      child: GestureDetector(
        onTap: isEmpty ? null : () => _showSettlementDetails(context),
        child: TapScale(
          scaleDown: 0.98,
          child: Opacity(
            opacity: isMuted ? 0.6 : 1.0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: Container(
                constraints: const BoxConstraints(minHeight: _minHeight),
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                  // 1. Primary Deep Liquid (Top Right)
                  Positioned(
                    top: -120,
                    right: -60,
                    child: Container(
                      width: 380,
                      height: 380,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            theme.colorScheme.primary.withValues(alpha: 0.6),
                            theme.colorScheme.primary.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // 2. Fire/Gold Liquid Flow (Left)
                  Positioned(
                    top: 20,
                    left: -120,
                    child: Container(
                      width: 320,
                      height: 320,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFFFFAB40).withValues(alpha: 0.5), // Electric Orange
                            const Color(0xFFFFAB40).withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // 3. Deep Sea Liquid (Bottom Right)
                  Positioned(
                    bottom: -100,
                    right: 40,
                    child: Container(
                      width: 350,
                      height: 350,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF00E5FF).withValues(alpha: 0.4), // Cyan Glow
                            const Color(0xFF00E5FF).withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.brightness == Brightness.dark
                              ? Colors.white.withValues(alpha: 0.02)
                              : Colors.white.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(
                            color: (theme.brightness == Brightness.dark 
                                ? Colors.white 
                                : Colors.black).withValues(alpha: 0.25),
                            width: 1.5,
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              (theme.brightness == Brightness.dark ? Colors.white : Colors.black).withValues(alpha: 0.15),
                              (theme.brightness == Brightness.dark ? Colors.white : Colors.black).withValues(alpha: 0.02),
                            ],
                          ),
                        ),
                        padding: EdgeInsets.all(AppSpacing.space2xl),
                        child: Stack(
                          children: [
                            // "Wet" Surface Highlight
                            Positioned(
                              top: -100,
                              left: -100,
                              child: Container(
                                width: 300,
                                height: 200,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      (theme.brightness == Brightness.dark ? Colors.white : Colors.black).withValues(alpha: 0.1),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // Liquid refractive depth (Bottom Right)
                            Positioned(
                              bottom: -60,
                              right: -40,
                              child: Container(
                                width: 200,
                                height: 200,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      (theme.brightness == Brightness.dark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            isEmpty
                                ? EmptyStates(type: 'zero-waste-cycle', forDarkCard: true)
                                : _buildContent(
                                    context,
                                    currencyCode: currencyCode,
                                    cycleTotal: cycleTotal,
                                    youPaid: youPaid,
                                    settledPaid: settledPaid,
                                    myNet: myNet,
                                    myRemaining: myRemaining,
                                    hasPaymentProgress: hasPaymentProgress,
                                    isCredit: isCredit,
                                    isDebt: isDebt,
                                    isBalanceClear: isBalanceClear,
                                    isMuted: isMuted,
                                  ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context, {
    required String currencyCode,
    required double cycleTotal,
    required double youPaid,
    required double settledPaid,
    required double myNet,
    required double myRemaining,
    required bool hasPaymentProgress,
    required bool isCredit,
    required bool isDebt,
    required bool isBalanceClear,
    required bool isMuted,
  }) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final statusColor = isBalanceClear
        ? onSurface.withValues(alpha: 0.7)
        : isCredit
        ? context.colorSuccessLight
        : context.colorDebtRed;

    final statusText = isMuted
        ? 'Cycle settled — pending restart'
        : isBalanceClear
        ? 'All clear'
        : '${isCredit ? '+' : '-'}${_formatAmount(myRemaining.abs(), currencyCode)}';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cycle Total',
          style: AppTypography.sectionLabel.copyWith(
            color: onSurface.withValues(alpha: 0.7),
          ),
        ),
        SizedBox(height: AppSpacing.spaceXs),
        Text(
          _formatAmount(cycleTotal, currencyCode),
          style: AppTypography.amountLG.copyWith(color: onSurface),
        ),
        SizedBox(height: AppSpacing.spaceXl),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Text(
                      'You Paid',
                      style: AppTypography.captionSmall.copyWith(
                        color: onSurface.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: AppSpacing.space2xs),
                    Text(
                      _formatAmount(youPaid, currencyCode),
                      style: AppTypography.amountSM.copyWith(
                        color: onSurface.withValues(alpha: 0.95),
                      ),
                    ),
                    if (settledPaid > 0.01) ...[
                      SizedBox(height: AppSpacing.spaceXs),
                      Text(
                        'Settled',
                        style: AppTypography.captionSmall.copyWith(
                          color: onSurface.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: AppSpacing.space2xs),
                      Text(
                        _formatAmount(settledPaid, currencyCode),
                        style: AppTypography.amountSM.copyWith(
                          color: onSurface.withValues(alpha: 0.95),
                        ),
                      ),
                    ],
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Status',
                    style: AppTypography.captionSmall.copyWith(
                      color: onSurface.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: AppSpacing.space2xs),
                  Text(
                    statusText,
                    style: AppTypography.amountSM.copyWith(color: statusColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SettlementDetailsSheet extends StatelessWidget {
  final CycleRepository repo;
  final String groupId;
  final String groupName;
  final String currencyCode;
  final List<Debt> debts;
  final String myId;
  final double myNet;
  final double myRemaining;
  final bool isPassive;

  const _SettlementDetailsSheet({
    required this.repo,
    required this.groupId,
    required this.groupName,
    required this.currencyCode,
    required this.debts,
    required this.myId,
    required this.myNet,
    required this.myRemaining,
    required this.isPassive,
  });

  @override
  Widget build(BuildContext context) {
    final isCredit = myRemaining > 0;
    final isDebt = myRemaining < 0;
    final isBalanceClear = myRemaining.abs() < 0.01;
    final onDark = Theme.of(context).brightness == Brightness.dark
        ? context.colorPrimary
        : context.colorSurface;

    final myDebts = debts
        .where((d) => d.fromId == myId || d.toId == myId)
        .toList();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [context.colorGradientStart, context.colorGradientEnd],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: AppSpacing.spaceLg),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: onDark.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: AppSpacing.spaceXl),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPaddingH,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Settlement details',
                    style: context.screenTitle.copyWith(color: onDark),
                  ),
                  SizedBox(height: AppSpacing.spaceXs),
                  Text(
                    groupName,
                    style: context.bodySecondary.copyWith(
                      color: onDark.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: AppSpacing.sectionGap),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPaddingH,
              ),
              child: _buildYourPosition(
                context,
                isCredit,
                isDebt,
                isBalanceClear,
                currencyCode,
              ),
            ),
            SizedBox(height: AppSpacing.sectionGap),
            if (myDebts.isEmpty || isBalanceClear)
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenPaddingH,
                ),
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: AppSpacing.space4xl,
                    ),
                    child: Text(
                      'All settled 🎉',
                      style: context.subheader.copyWith(color: onDark),
                    ),
                  ),
                ),
              )
            else
              _buildDebtsList(context, myDebts, currencyCode),
            SizedBox(height: AppSpacing.space3xl),
          ],
        ),
      ),
    );
  }

  Widget _buildYourPosition(
    BuildContext context,
    bool isCredit,
    bool isDebt,
    bool isBalanceClear,
    String currencyCode,
  ) {
    if (isBalanceClear) {
      return Container(
        padding: EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: context.colorSurfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: context.colorSuccess,
              size: 28,
            ),
            SizedBox(width: AppSpacing.spaceLg),
            Expanded(
              child: Text(
                'You\'re all settled up',
                style: AppTypography.listItemTitle,
              ),
            ),
          ],
        ),
      );
    }

    final color = isCredit ? context.colorSuccess : context.colorError;
    final label = isCredit ? 'You will receive' : 'You owe';
    final amount = _formatAmount(myRemaining.abs(), currencyCode);

    return Container(
      padding: EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: isCredit
            ? context.colorSuccessBackground
            : context.colorErrorBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.caption.copyWith(color: color)),
          SizedBox(height: AppSpacing.spaceXs),
          Text(amount, style: AppTypography.amountLG.copyWith(color: color)),
        ],
      ),
    );
  }

  Widget _buildDebtsList(
    BuildContext context,
    List<Debt> myDebts,
    String currencyCode,
  ) {
    final onDark = Theme.of(context).brightness == Brightness.dark
        ? context.colorPrimary
        : context.colorSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenPaddingH),
          child: Text(
            'BREAKDOWN',
            style: AppTypography.sectionLabel.copyWith(
              color: onDark.withValues(alpha: 0.7),
            ),
          ),
        ),
        SizedBox(height: AppSpacing.spaceLg),
        ...myDebts.map((debt) {
          final iOwe = debt.fromId == myId;
          final otherId = iOwe ? debt.toId : debt.fromId;
          final otherName = repo.getMemberDisplayNameById(otherId);
          final photoUrl = repo.getMemberPhotoURL(otherId);
          final direction = iOwe ? 'Pay' : 'Receive';
          final directionColor = iOwe
              ? context.colorError
              : context.colorSuccess;
          final amountDisplay = MoneyConversion.toDisplay(debt.amount);

          final showPendingBadge =
              isPassive && !iOwe && !repo.isMemberSettled(groupId, otherId);

          return Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPaddingH,
              vertical: AppSpacing.spaceLg,
            ),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: onDark.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                MemberAvatar(
                  displayName: otherName,
                  photoURL: photoUrl,
                  size: 44,
                ),
                SizedBox(width: AppSpacing.spaceLg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            otherName,
                            style: AppTypography.listItemTitle.copyWith(
                              color: onDark,
                            ),
                          ),
                          if (showPendingBadge) ...[
                            SizedBox(width: AppSpacing.spaceSm),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: context.colorWarningBackground,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Pending',
                                style: AppTypography.captionSmall.copyWith(
                                  color: context.colorWarning,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: AppSpacing.space2xs),
                      Text(
                        direction,
                        style: AppTypography.captionSmall.copyWith(
                          color: directionColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _formatAmount(amountDisplay, currencyCode),
                  style: AppTypography.amountSM.copyWith(color: directionColor),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _LockedSpendBar extends StatelessWidget {
  final Group group;
  const _LockedSpendBar({required this.group});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.error.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.lock_clock_outlined,
              size: 20,
              color: theme.colorScheme.error,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Weekly spending is locked. Please settle the current cycle to continue.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
