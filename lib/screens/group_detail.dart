import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../models/models.dart';
import '../models/cycle.dart';
import '../models/normalized_expense.dart';
import '../repositories/cycle_repository.dart';
import '../services/connectivity_service.dart';
import '../services/groq_expense_parser_service.dart';
import '../utils/expense_normalization.dart';
import '../utils/settlement_engine.dart';
import '../models/money_minor.dart';
import '../widgets/expenso_loader.dart';
import '../widgets/member_avatar.dart';
import '../widgets/offline_banner.dart';
import '../widgets/settlement_activity_feed.dart';
import '../widgets/settlement_progress_indicator.dart';
import '../widgets/skeleton_placeholders.dart';
import 'empty_states.dart';

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
  
  final otherParticipants = participantIds.where((id) => id != currentUserId).toList();
  
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

void _showUndoExpenseOverlay(
  BuildContext context, {
  required String groupId,
  required String expenseId,
  required String description,
  required double amount,
}) {
  final repo = CycleRepository.instance;
  showDialog(
    context: context,
    barrierColor: Colors.transparent,
    barrierDismissible: false,
    builder: (ctx) => _UndoExpenseOverlayContent(
      description: description,
      amount: amount,
      onUndo: () {
        repo.deleteExpense(groupId, expenseId);
        repo.clearLastAdded();
        Navigator.pop(ctx);
      },
      onDismiss: () {
        repo.clearLastAdded();
        Navigator.pop(ctx);
      },
    ),
  );
}

class _UndoExpenseOverlayContent extends StatefulWidget {
  final String description;
  final double amount;
  final VoidCallback onUndo;
  final VoidCallback onDismiss;

  const _UndoExpenseOverlayContent({
    required this.description,
    required this.amount,
    required this.onUndo,
    required this.onDismiss,
  });

  @override
  State<_UndoExpenseOverlayContent> createState() => _UndoExpenseOverlayContentState();
}

class _UndoExpenseOverlayContentState extends State<_UndoExpenseOverlayContent> {
  static const int _countdownSeconds = 5;
  int _timeLeft = _countdownSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _timer?.cancel();
        return;
      }
      if (_timeLeft <= 1) {
        _timer?.cancel();
        if (mounted) widget.onDismiss();
      } else {
        setState(() => _timeLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned(
            bottom: 32,
            left: 24,
            right: 24,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 430),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Expense added',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.description} · ₹${widget.amount.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: const Color(0xFFB0B0B0),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  TextButton.icon(
                    onPressed: () {
                      _timer?.cancel();
                      widget.onUndo();
                    },
                    icon: const Icon(Icons.refresh, size: 16, color: Colors.white),
                    label: Text(
                      'Undo',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GroupDetail extends StatefulWidget {
  final Group? group;

  const GroupDetail({
    super.key,
    this.group,
  });

  @override
  State<GroupDetail> createState() => _GroupDetailState();
}

class _GroupDetailState extends State<GroupDetail> {
  bool _profilesRefreshed = false;

  @override
  Widget build(BuildContext context) {
    final repo = CycleRepository.instance;
    final routeGroup = ModalRoute.of(context)?.settings.arguments as Group?;
    final resolvedGroup = routeGroup ?? widget.group;
    if (resolvedGroup == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.maybePop(context));
      return const Scaffold(body: SizedBox.shrink());
    }
    final groupId = resolvedGroup.id;

    if (!_profilesRefreshed) {
      _profilesRefreshed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        repo.refreshGroupMemberProfiles(groupId);
      });
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
          return const Scaffold(
            body: Center(child: ExpensoLoader()),
          );
        }
        final activeCycle = repo.getActiveCycle(groupId);
        final expenses = repo.getExpenses(activeCycle.id);
        final systemMessages = repo.getSystemMessages(groupId);
        final isPassive = activeCycle.status == CycleStatus.settling;
        final isSettled = activeCycle.status == CycleStatus.closed || defaultGroup.status == 'settled';
        final hasExpenses = expenses.isNotEmpty || systemMessages.isNotEmpty;

        return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OfflineBanner(
              onRetry: () => ConnectivityService.instance.checkNow(),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.chevron_left, size: 24),
                    color: const Color(0xFF1A1A1A),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(32, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      defaultGroup.name,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        '/group-members',
                        arguments: defaultGroup,
                      );
                    },
                    icon: const Icon(Icons.people_outline, size: 24),
                    color: const Color(0xFF1A1A1A),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(32, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: _DecisionClarityCard(
                repo: repo,
                groupId: groupId,
                groupName: defaultGroup.name,
                expenses: expenses,
                isSettled: isSettled,
                isPassive: isPassive,
              ),
            ),
            if (isPassive) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: SettlementProgressIndicator(groupId: groupId),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: SettlementActivityFeed(groupId: groupId, maxItems: 5),
              ),
            ],
            if (!isSettled && (repo.getGroupPendingAmount(groupId) > 0 || isPassive)) ...[
              Builder(
                builder: (context) {
                  final fullySettled = isPassive && repo.isFullySettled(groupId);
                  final isCreator = repo.isCurrentUserCreator(groupId);
                  
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                    child: ElevatedButton(
                      onPressed: () async {
                        if (isPassive) {
                          if (isCreator) {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Start new cycle?'),
                                content: Text(
                                  fullySettled
                                      ? 'All payments are complete. Ready to start a fresh cycle.'
                                      : 'This will archive current expenses and start a fresh cycle.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Confirm'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed != true || !context.mounted) return;
                            try {
                              await repo.archiveAndRestart(groupId);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('New cycle started.'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Could not start new cycle: ${e.toString().replaceFirst(RegExp(r'^Exception:?\s*'), '')}'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Only the group creator can start a new cycle.'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } else {
                          _showSettlementOptions(context, defaultGroup, groupId);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: fullySettled ? AppColors.success : const Color(0xFF1A1A1A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                        minimumSize: const Size(double.infinity, 0),
                      ),
                      child: Text(
                        isPassive
                            ? (isCreator 
                                ? (fullySettled ? 'Start New Cycle ✓' : 'Start New Cycle')
                                : 'Waiting for creator to restart')
                            : 'Settle now',
                        style: AppTypography.button,
                      ),
                    ),
                  );
                },
              ),
            ],
            if (hasExpenses)
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                      sliver: SliverToBoxAdapter(
                        child: Text(
                          'EXPENSE LOG',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF9B9B9B),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final expense = expenses[index];
                          return InkWell(
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
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                              decoration: BoxDecoration(
                                border: Border(
                                  top: index > 0
                                      ? const BorderSide(color: Color(0xFFE5E5E5), width: 1)
                                      : BorderSide.none,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Builder(
                                          builder: (context) {
                                            final desc = _buildViewerRelativeDescription(
                                              expense: expense,
                                              repo: repo,
                                            );
                                            return Text.rich(
                                              TextSpan(
                                                children: [
                                                  TextSpan(
                                                    text: desc.main,
                                                    style: const TextStyle(
                                                      fontSize: 17,
                                                      color: Color(0xFF1A1A1A),
                                                    ),
                                                  ),
                                                  if (desc.suffix != null) ...[
                                                    const TextSpan(text: '  '),
                                                    TextSpan(
                                                      text: desc.suffix,
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                        color: Color(0xFF9B9B9B),
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
                                            color: const Color(0xFF9B9B9B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Text(
                                    '₹${expense.amount.toStringAsFixed(0).replaceAllMapped(
                                      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                                      (Match m) => '${m[1]},',
                                    )}',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF1A1A1A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        childCount: expenses.length,
                      ),
                    ),
                    if (systemMessages.isNotEmpty)
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final msg = systemMessages[index];
                            String text;
                            switch (msg.type) {
                              case 'joined':
                                text = '${msg.userName} joined the group';
                                break;
                              case 'declined':
                                text = '${msg.userName} declined the invitation';
                                break;
                              case 'left':
                                text = '${msg.userName} left the group';
                                break;
                              case 'created':
                                text = '${msg.userName} created the group';
                                break;
                              default:
                                text = '${msg.userName} ${msg.type}';
                            }
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              child: Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF9B9B9B),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      text,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: const Color(0xFF9B9B9B),
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    msg.date,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: const Color(0xFFB0B0B0),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                          childCount: systemMessages.length,
                        ),
                      ),
                  ],
                ),
              )
            else
              Expanded(child: EmptyStates(type: 'no-expenses-new-cycle')),
                ],
              ),
            ),
            if (!isSettled && !isPassive)
              _SmartBarSection(group: defaultGroup),
          ],
        ),
      ),
    );
      },
    );
  }

  void _showSettlementOptions(BuildContext context, Group group, String groupId) {
    final repo = CycleRepository.instance;
    final members = repo.getMembersForGroup(groupId);
    final cycle = repo.getActiveCycle(groupId);
    final netBalances = SettlementEngine.computeNetBalances(cycle.expenses, members);
    final allRoutes = SettlementEngine.computePaymentRoutes(netBalances, 'INR');
    final myRoutes = SettlementEngine.getPaymentsForMember(repo.currentUserId, allRoutes);
    final hasDues = myRoutes.isNotEmpty;
    final isCreator = repo.isCurrentUserCreator(groupId);

    if (!hasDues) {
      if (isCreator) {
        _showSettleConfirmDialog(context, repo, groupId);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You have no payments to make. The group creator can close the cycle.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    Navigator.pushNamed(
      context,
      '/settlement-confirmation',
      arguments: {'group': group, 'method': 'upi'},
    );
  }

  void _showSettleConfirmDialog(BuildContext context, CycleRepository repo, String groupId) {
    final instructions = repo.getSettlementInstructions(groupId);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Settle & Restart',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1A1A1A),
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                instructions.isEmpty ? 'No balances to settle.' : 'The following will close this cycle:',
                style: TextStyle(
                  fontSize: 15,
                  color: const Color(0xFF6B6B6B),
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
                        color: const Color(0xFF1A1A1A),
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
                color: const Color(0xFF5B7C99),
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
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
                      content: Text('Could not settle: ${e.toString().replaceFirst(RegExp(r'^Exception:?\s*'), '')}'),
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
                color: const Color(0xFF1A1A1A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _fmtRupee(double value) {
  if (value.isNaN || value.isInfinite) return '0';
  return value.toStringAsFixed(0).replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (Match m) => '${m[1]},',
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
    final debts = SettlementEngine.computeDebts(expenses, members);
    final netBalances = SettlementEngine.computeNetBalancesAsDouble(expenses, members);
    final myId = repo.currentUserId;
    double myNet = netBalances[myId] ?? 0.0;
    if (myNet.isNaN || myNet.isInfinite) myNet = 0.0;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SettlementDetailsSheet(
        repo: repo,
        groupId: groupId,
        groupName: groupName,
        debts: debts,
        myId: myId,
        myNet: myNet,
        isPassive: isPassive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEmpty = expenses.isEmpty;
    final cycleTotal = expenses.fold<double>(0.0, (s, e) => s + e.amount);
    final members = repo.getMembersForGroup(groupId);
    final netBalances = SettlementEngine.computeNetBalancesAsDouble(expenses, members);
    final myId = repo.currentUserId;

    double youPaid = 0.0;
    for (final e in expenses) {
      if (e.paidById == myId) {
        youPaid += e.amount;
      }
    }

    double myNet = netBalances[myId] ?? 0.0;
    if (myNet.isNaN || myNet.isInfinite) myNet = 0.0;

    final myRemaining = repo.getRemainingBalance(groupId, myId);
    final hasPaymentProgress = (myNet - myRemaining).abs() > 0.01;

    final isCredit = myRemaining > 0;
    final isDebt = myRemaining < 0;
    final isBalanceClear = myRemaining.abs() < 0.01;

    final isMuted = isPassive;

    return GestureDetector(
      onTap: isEmpty ? null : () => _showSettlementDetails(context),
      child: Opacity(
        opacity: isMuted ? 0.6 : 1.0,
        child: Container(
          constraints: const BoxConstraints(minHeight: _minHeight),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.gradientStart, AppColors.gradientEnd],
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.space2xl),
              child: isEmpty
                  ? EmptyStates(type: 'zero-waste-cycle', forDarkCard: true)
                  : _buildContent(
                      cycleTotal: cycleTotal,
                      youPaid: youPaid,
                      myNet: myNet,
                      myRemaining: myRemaining,
                      hasPaymentProgress: hasPaymentProgress,
                      isCredit: isCredit,
                      isDebt: isDebt,
                      isBalanceClear: isBalanceClear,
                      isMuted: isMuted,
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent({
    required double cycleTotal,
    required double youPaid,
    required double myNet,
    required double myRemaining,
    required bool hasPaymentProgress,
    required bool isCredit,
    required bool isDebt,
    required bool isBalanceClear,
    required bool isMuted,
  }) {
    final statusColor = isBalanceClear
        ? Colors.white70
        : isCredit
            ? AppColors.successLight
            : AppColors.debtRed;

    final statusText = isMuted
        ? 'Cycle settled — pending restart'
        : isBalanceClear
            ? 'All clear'
            : '${isCredit ? '+' : '-'}₹${_fmtRupee(myRemaining.abs())}';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cycle Total',
          style: AppTypography.sectionLabel.copyWith(
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
        SizedBox(height: AppSpacing.spaceXs),
        Text(
          '₹${_fmtRupee(cycleTotal)}',
          style: AppTypography.amountLG.copyWith(color: Colors.white),
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
                      color: Colors.white.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: AppSpacing.space2xs),
                  Text(
                    '₹${_fmtRupee(youPaid)}',
                    style: AppTypography.amountSM.copyWith(
                      color: Colors.white.withValues(alpha: 0.95),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasPaymentProgress ? 'Remaining' : 'Your Status',
                    style: AppTypography.captionSmall.copyWith(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: AppSpacing.space2xs),
                  if (hasPaymentProgress && !isBalanceClear) ...[
                    Text(
                      statusText,
                      style: AppTypography.amountSM.copyWith(color: statusColor),
                    ),
                    SizedBox(height: AppSpacing.space2xs),
                    Text(
                      'was ${myNet < 0 ? '-' : '+'}₹${_fmtRupee(myNet.abs())}',
                      style: AppTypography.captionSmall.copyWith(
                        color: Colors.white.withValues(alpha: 0.5),
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ] else
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
  final List<Debt> debts;
  final String myId;
  final double myNet;
  final bool isPassive;

  const _SettlementDetailsSheet({
    required this.repo,
    required this.groupId,
    required this.groupName,
    required this.debts,
    required this.myId,
    required this.myNet,
    required this.isPassive,
  });

  @override
  Widget build(BuildContext context) {
    final isCredit = myNet > 0;
    final isDebt = myNet < 0;
    final isBalanceClear = myNet.abs() < 0.01;

    final myDebts = debts.where((d) => d.fromId == myId || d.toId == myId).toList();

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: AppSpacing.spaceXl),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenPaddingH),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Settlement details', style: context.screenTitle),
                  SizedBox(height: AppSpacing.spaceXs),
                  Text(groupName, style: context.bodySecondary),
                ],
              ),
            ),
            SizedBox(height: AppSpacing.sectionGap),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenPaddingH),
              child: _buildYourPosition(isCredit, isDebt, isBalanceClear),
            ),
            SizedBox(height: AppSpacing.sectionGap),
            if (myDebts.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenPaddingH),
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.space4xl),
                    child: Text(
                      'All settled 🎉',
                      style: context.subheader.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                ),
              )
            else
              _buildDebtsList(myDebts),
            SizedBox(height: AppSpacing.space3xl),
          ],
        ),
      ),
    );
  }

  Widget _buildYourPosition(bool isCredit, bool isDebt, bool isBalanceClear) {
    if (isBalanceClear) {
      return Container(
        padding: EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline, color: AppColors.success, size: 28),
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

    final color = isCredit ? AppColors.success : AppColors.error;
    final label = isCredit ? 'You will receive' : 'You owe';
    final amount = '₹${_fmtRupee(myNet.abs())}';

    return Container(
      padding: EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: isCredit ? const Color(0xFFE8F5E9) : AppColors.errorBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.caption.copyWith(color: color),
          ),
          SizedBox(height: AppSpacing.spaceXs),
          Text(
            amount,
            style: AppTypography.amountLG.copyWith(color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildDebtsList(List<Debt> myDebts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenPaddingH),
          child: Text('BREAKDOWN', style: AppTypography.sectionLabel),
        ),
        SizedBox(height: AppSpacing.spaceLg),
        ...myDebts.map((debt) {
          final iOwe = debt.fromId == myId;
          final otherId = iOwe ? debt.toId : debt.fromId;
          final otherName = repo.getMemberDisplayNameById(otherId);
          final photoUrl = repo.getMemberPhotoURL(otherId);
          final direction = iOwe ? 'Pay' : 'Receive';
          final directionColor = iOwe ? AppColors.error : AppColors.success;
          final amountDisplay = MoneyConversion.toDisplay(debt.amount);

          final showPendingBadge = isPassive && 
              !iOwe && 
              !repo.isMemberSettled(groupId, otherId);

          return Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPaddingH,
              vertical: AppSpacing.spaceLg,
            ),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.border, width: 1),
              ),
            ),
            child: Row(
              children: [
                MemberAvatar(displayName: otherName, photoURL: photoUrl, size: 44),
                SizedBox(width: AppSpacing.spaceLg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(otherName, style: AppTypography.listItemTitle),
                          if (showPendingBadge) ...[
                            SizedBox(width: AppSpacing.spaceSm),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.warningBackground,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Pending',
                                style: AppTypography.captionSmall.copyWith(
                                  color: AppColors.warning,
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
                  '₹${_fmtRupee(amountDisplay)}',
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

class _SmartBarSection extends StatefulWidget {
  final Group group;

  const _SmartBarSection({required this.group});

  @override
  State<_SmartBarSection> createState() => _SmartBarSectionState();
}

class _SmartBarSectionState extends State<_SmartBarSection> {
  final TextEditingController _controller = TextEditingController();
  bool _loading = false;
  bool _sendAllowed = false;
  Timer? _debounceTimer;
  DateTime? _cooldownUntil;
  Timer? _cooldownTimer;
  static const Duration _debounceDuration = Duration(milliseconds: 500);
  static const Duration _cooldownDuration = Duration(seconds: 30);

  Map<String, String>? _phoneToContactName;
  Map<String, List<String>>? _contactNameToNormalizedPhones;
  bool _contactCacheLoaded = false;

  static String _normalizePhoneForMatch(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 10 ? digits.substring(digits.length - 10) : digits;
  }

  Future<void> _ensureContactCache() async {
    if (_contactCacheLoaded) return;
    final perm = await fc.FlutterContacts.requestPermission();
    if (!perm || !mounted) return;
    final contacts = await fc.FlutterContacts.getContacts(withProperties: true);
    if (!mounted) return;
    final phoneToName = <String, String>{};
    final nameToPhones = <String, List<String>>{};
    for (final c in contacts) {
      final name = c.displayName.trim();
      if (name.isEmpty) continue;
      final key = name.toLowerCase();
      final phones = c.phones
          .map((p) => _normalizePhoneForMatch(p.number))
          .where((s) => s.length >= 10)
          .toSet()
          .toList();
      if (phones.isNotEmpty) {
        nameToPhones.putIfAbsent(key, () => []).addAll(phones);
      }
      for (final p in c.phones) {
        final norm = _normalizePhoneForMatch(p.number);
        if (norm.length >= 10 && !phoneToName.containsKey(norm)) {
          phoneToName[norm] = name;
        }
      }
    }
    if (mounted) {
      setState(() {
        _phoneToContactName = phoneToName;
        _contactNameToNormalizedPhones = nameToPhones;
        _contactCacheLoaded = true;
      });
    }
  }

  bool get _inCooldown =>
      _cooldownUntil != null && DateTime.now().isBefore(_cooldownUntil!);

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (_controller.text.trim().isEmpty) {
      _debounceTimer?.cancel();
      _debounceTimer = null;
      if (_sendAllowed) setState(() => _sendAllowed = false);
      return;
    }
    _debounceTimer?.cancel();
    if (_sendAllowed) setState(() => _sendAllowed = false);
    _debounceTimer = Timer(_debounceDuration, () {
      if (!mounted) return;
      setState(() => _sendAllowed = true);
    });
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    _cooldownUntil = DateTime.now().add(_cooldownDuration);
    setState(() {});
    _cooldownTimer = Timer(_cooldownDuration, () {
      if (!mounted) return;
      setState(() {
        _cooldownUntil = null;
      });
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _cooldownTimer?.cancel();
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  /// Resolves a single name to one member id, or null if ambiguous/unmatched.
  String? _resolveOneNameToId(
    CycleRepository repo,
    String groupId,
    String name, {
    Map<String, List<String>>? contactNameToNormalizedPhones,
  }) {
    final r = _resolveOneNameToIdWithGuess(
      repo,
      groupId,
      name,
      contactNameToNormalizedPhones: contactNameToNormalizedPhones,
    );
    return r.id;
  }

  static bool _nameSimilar(String parsedLower, String otherLower) {
    if (parsedLower == otherLower) return true;
    if (otherLower.contains(parsedLower) || parsedLower.contains(otherLower)) return true;
    if (otherLower.startsWith(parsedLower) || parsedLower.startsWith(otherLower)) return true;
    return false;
  }

  /// Checks if a name matches a pending member (invited but not yet joined).
  /// Returns the display name of the pending member if found, null otherwise.
  String? _findPendingMemberMatch(
    CycleRepository repo,
    String groupId,
    String name, {
    Map<String, List<String>>? contactNameToNormalizedPhones,
  }) {
    final n = name.trim().toLowerCase();
    if (n.isEmpty) return null;
    final pendingMembers = repo.getMembersForGroup(groupId).where((m) => m.id.startsWith('p_')).toList();
    if (pendingMembers.isEmpty) return null;

    Map<String, String>? phoneToContactName;
    if (contactNameToNormalizedPhones != null) {
      phoneToContactName = {};
      for (final entry in contactNameToNormalizedPhones.entries) {
        for (final p in entry.value) {
          phoneToContactName[p] = entry.key;
        }
      }
    }

    for (final m in pendingMembers) {
      final displayLower = repo.getMemberDisplayNameById(m.id).trim().toLowerCase();
      if (displayLower.isNotEmpty && _nameSimilar(n, displayLower)) {
        return repo.getMemberDisplayNameById(m.id);
      }
      final contactLower = phoneToContactName?[_normalizePhoneForMatch(m.phone)]?.trim().toLowerCase();
      if (contactLower != null && contactLower.isNotEmpty && _nameSimilar(n, contactLower)) {
        return phoneToContactName![_normalizePhoneForMatch(m.phone)];
      }
    }
    return null;
  }

  /// Resolves a parsed participant name to a group member: match against each member's
  /// display name and (if available) contact name; exact match wins, else one similar match.
  ({String? id, bool isGuessed}) _resolveOneNameToIdWithGuess(
    CycleRepository repo,
    String groupId,
    String name, {
    Map<String, List<String>>? contactNameToNormalizedPhones,
  }) {
    final n = name.trim().toLowerCase();
    if (n.isEmpty) return (id: null, isGuessed: false);
    final members = repo.getMembersForGroup(groupId).where((m) => !m.id.startsWith('p_')).toList();
    final currentName = repo.currentUserName;
    final currentId = repo.currentUserId;
    if (n == 'you' || (currentName.isNotEmpty && currentName.toLowerCase() == n)) {
      return (id: currentId.isNotEmpty ? currentId : null, isGuessed: false);
    }

    Map<String, String>? phoneToContactName;
    if (contactNameToNormalizedPhones != null) {
      phoneToContactName = {};
      for (final entry in contactNameToNormalizedPhones.entries) {
        for (final p in entry.value) {
          phoneToContactName[p] = entry.key;
        }
      }
    }

    String? exactMatch;
    final similarMatchIds = <String>{};
    for (final m in members) {
      final displayLower = repo.getMemberDisplayNameById(m.id).trim().toLowerCase();
      if (displayLower.isNotEmpty && _nameSimilar(n, displayLower)) {
        if (displayLower == n) {
          exactMatch = m.id;
          break;
        }
        similarMatchIds.add(m.id);
      }
      if (exactMatch != null) break;
      final contactLower = phoneToContactName?[_normalizePhoneForMatch(m.phone)]?.trim().toLowerCase();
      if (contactLower != null && contactLower.isNotEmpty && _nameSimilar(n, contactLower)) {
        if (contactLower == n) {
          exactMatch = m.id;
          break;
        }
        similarMatchIds.add(m.id);
      }
    }
    if (exactMatch != null) return (id: exactMatch, isGuessed: false);
    if (similarMatchIds.length == 1) return (id: similarMatchIds.single, isGuessed: true);
    return (id: null, isGuessed: false);
  }

  /// At confirmation time (for any split type): fill any unresolved slot that has exactly one
  /// unassigned member matching the slot's name (display or contact). Repeats until no such slot exists.
  void _resolveUnresolvedSlotsAtConfirmation(
    List<_ParticipantSlot> slots,
    List<Member> members,
    CycleRepository repo,
    Map<String, List<String>>? contactNameToNormalizedPhones,
  ) {
    Map<String, String>? phoneToContactName;
    if (contactNameToNormalizedPhones != null) {
      phoneToContactName = {};
      for (final entry in contactNameToNormalizedPhones.entries) {
        for (final p in entry.value) {
          phoneToContactName[p] = entry.key;
        }
      }
    }

    Set<String> _assignedIds() =>
        slots.where((s) => s.id != null && s.id!.isNotEmpty).map((s) => s.id!).toSet();
    List<Member> _unassigned(Set<String> assigned) =>
        members.where((m) => !assigned.contains(m.id)).toList();

    Set<String> _memberIdsMatchingName(String name, List<Member> candidates) {
      final n = name.trim().toLowerCase();
      if (n.isEmpty) return {};
      final ids = <String>{};
      for (final m in candidates) {
        final displayLower = repo.getMemberDisplayNameById(m.id).trim().toLowerCase();
        if (displayLower.isNotEmpty && _nameSimilar(n, displayLower)) ids.add(m.id);
        final contactLower = phoneToContactName?[_normalizePhoneForMatch(m.phone)]?.trim().toLowerCase();
        if (contactLower != null && contactLower.isNotEmpty && _nameSimilar(n, contactLower)) ids.add(m.id);
      }
      return ids;
    }

    bool changed = true;
    while (changed) {
      changed = false;
      final assigned = _assignedIds();
      final unassigned = _unassigned(assigned);
      for (var i = 0; i < slots.length; i++) {
        if (slots[i].id != null && slots[i].id!.isNotEmpty) continue;
        final matchIds = _memberIdsMatchingName(slots[i].name, unassigned);
        if (matchIds.length == 1) {
          slots[i] = _ParticipantSlot(
            name: slots[i].name,
            amount: slots[i].amount,
            id: matchIds.single,
            isGuessed: true,
          );
          changed = true;
          break;
        }
      }
    }
  }

  Future<void> _submit() async {
    final input = _controller.text.trim();
    if (input.isEmpty || _loading || !_sendAllowed || _inCooldown) return;
    final repo = CycleRepository.instance;
    final groupId = widget.group.id;
    final members = repo.getMembersForGroup(groupId);

    setState(() => _loading = true);
    try {
      await _ensureContactCache();
      if (!mounted) return;
      final memberNames = members.map((m) {
        final name = repo.getMemberDisplayNameById(m.id);
        final looksLikePhone = name.isEmpty ||
            RegExp(r'\+|\d{8,}').hasMatch(name.replaceAll(RegExp(r'\s'), ''));
        if (looksLikePhone && _phoneToContactName != null) {
          final norm = _normalizePhoneForMatch(m.phone);
          final contactName = _phoneToContactName![norm];
          if (contactName != null && contactName.trim().isNotEmpty) return contactName;
        }
        return name;
      }).toList();
      final result = await GroqExpenseParserService.parse(
        userInput: input,
        groupMemberNames: memberNames,
      );
      if (!mounted) return;
      
      // Check if any participant is a pending member
      final pendingNames = <String>[];
      for (final pName in result.participantNames) {
        final pendingMatch = _findPendingMemberMatch(
          repo, groupId, pName,
          contactNameToNormalizedPhones: _contactNameToNormalizedPhones,
        );
        if (pendingMatch != null) pendingNames.add(pendingMatch);
      }
      // Also check payer
      if (result.payerName != null && result.payerName!.trim().isNotEmpty) {
        final pendingMatch = _findPendingMemberMatch(
          repo, groupId, result.payerName!,
          contactNameToNormalizedPhones: _contactNameToNormalizedPhones,
        );
        if (pendingMatch != null) pendingNames.add(pendingMatch);
      }
      
      if (pendingNames.isNotEmpty) {
        setState(() => _loading = false);
        final uniqueNames = pendingNames.toSet().toList();
        final nameList = uniqueNames.length == 1 
            ? uniqueNames.first 
            : '${uniqueNames.sublist(0, uniqueNames.length - 1).join(', ')} and ${uniqueNames.last}';
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Member Not Joined'),
            content: Text(
              '$nameList hasn\'t accepted the invitation yet. They need to join the group before you can add them to expenses.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }
      
      setState(() => _loading = false);
      _controller.clear();
      setState(() => _sendAllowed = false);
      HapticFeedback.lightImpact();
      _showConfirmationDialog(repo, result, contactNameToNormalizedPhones: _contactNameToNormalizedPhones);
    } on GroqRateLimitException catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _startCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'AI is cooling down. Use manual entry below or try again in 30 seconds.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is Exception ? e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '') : 'Couldn\'t parse that. Try a clearer format like "Dinner 500".'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showConfirmationDialog(
    CycleRepository repo,
    ParsedExpenseResult result, {
    Map<String, List<String>>? contactNameToNormalizedPhones,
  }) async {
    final groupId = widget.group.id;
    final members = repo.getMembersForGroup(groupId).where((m) => !m.id.startsWith('p_')).toList();
    final allIds = members.map((m) => m.id).toList();

    String payerId = repo.currentUserId;
    if (result.payerName != null && result.payerName!.trim().isNotEmpty) {
      final pid = _resolveOneNameToId(
        repo,
        groupId,
        result.payerName!.trim(),
        contactNameToNormalizedPhones: contactNameToNormalizedPhones,
      );
      if (pid != null) payerId = pid;
    }

    final splitTypeCap = result.splitType == 'exact'
        ? 'Exact'
        : result.splitType == 'exclude'
            ? 'Exclude'
            : result.splitType == 'percentage'
                ? 'Percentage'
                : result.splitType == 'shares'
                    ? 'Shares'
                    : 'Even';

    final List<_ParticipantSlot> slots = [];
    final bool isExclude = result.splitType == 'exclude';

    final contactMap = contactNameToNormalizedPhones;
    if (result.splitType == 'exclude' && result.excludedNames.isNotEmpty) {
      for (final name in result.excludedNames) {
        final r = _resolveOneNameToIdWithGuess(repo, groupId, name, contactNameToNormalizedPhones: contactMap);
        slots.add(_ParticipantSlot(name: name, amount: 0, id: r.id, isGuessed: r.isGuessed));
      }
    } else if (result.splitType == 'exact' && result.exactAmountsByName.isNotEmpty) {
      for (final entry in result.exactAmountsByName.entries) {
        final r = _resolveOneNameToIdWithGuess(repo, groupId, entry.key, contactNameToNormalizedPhones: contactMap);
        slots.add(_ParticipantSlot(name: entry.key, amount: entry.value, id: r.id, isGuessed: r.isGuessed));
      }
    } else if (result.splitType == 'percentage' && result.percentageByName.isNotEmpty) {
      for (final entry in result.percentageByName.entries) {
        final name = entry.key;
        final pct = entry.value;
        final amount = result.amount * (pct / 100);
        String? id;
        String displayName = name;
        if (name.trim().toLowerCase() == 'me' || name.trim().toLowerCase() == 'i') {
          id = repo.currentUserId;
          displayName = repo.getMemberDisplayNameById(id);
        } else {
          final r = _resolveOneNameToIdWithGuess(repo, groupId, name, contactNameToNormalizedPhones: contactMap);
          id = r.id;
          displayName = name;
        }
        slots.add(_ParticipantSlot(name: displayName, amount: amount, id: id, isGuessed: false));
      }
    } else if (result.splitType == 'shares' && result.sharesByName.isNotEmpty) {
      final totalShares = result.sharesByName.values.fold<double>(0.0, (a, b) => a + b);
      if (totalShares > 0) {
        for (final entry in result.sharesByName.entries) {
          final name = entry.key;
          final personShares = entry.value;
          final amount = result.amount * (personShares / totalShares);
          String? id;
          String displayName = name;
          if (name.trim().toLowerCase() == 'me' || name.trim().toLowerCase() == 'i') {
            id = repo.currentUserId;
            displayName = repo.getMemberDisplayNameById(id);
          } else {
            final r = _resolveOneNameToIdWithGuess(repo, groupId, name, contactNameToNormalizedPhones: contactMap);
            id = r.id;
            displayName = name;
          }
          slots.add(_ParticipantSlot(name: displayName, amount: amount, id: id, isGuessed: false));
        }
      }
    } else {
      List<String> names = result.participantNames;
      if (names.isEmpty) {
        for (final m in members) {
          final displayName = repo.getMemberDisplayNameById(m.id);
          final perShare = members.isNotEmpty ? result.amount / members.length : result.amount;
          slots.add(_ParticipantSlot(name: displayName, amount: perShare, id: m.id, isGuessed: false));
        }
      } else {
        final resolvedSlots = <_ParticipantSlot>[];
        final seenIds = <String>{};
        
        for (final name in names) {
          final r = _resolveOneNameToIdWithGuess(repo, groupId, name, contactNameToNormalizedPhones: contactMap);
          if (r.id != null && r.id!.isNotEmpty) {
            if (!seenIds.contains(r.id)) {
              seenIds.add(r.id!);
              resolvedSlots.add(_ParticipantSlot(name: name, amount: 0, id: r.id, isGuessed: r.isGuessed));
            }
          } else {
            resolvedSlots.add(_ParticipantSlot(name: name, amount: 0, id: r.id, isGuessed: r.isGuessed));
          }
        }
        
        if (!seenIds.contains(repo.currentUserId)) {
          seenIds.add(repo.currentUserId);
          resolvedSlots.insert(0, _ParticipantSlot(
            name: repo.getMemberDisplayNameById(repo.currentUserId),
            amount: 0,
            id: repo.currentUserId,
            isGuessed: false,
          ));
        }
        
        final splitCount = resolvedSlots.length;
        final perShare = splitCount > 0 ? result.amount / splitCount : result.amount;
        for (final slot in resolvedSlots) {
          slots.add(_ParticipantSlot(name: slot.name, amount: perShare, id: slot.id, isGuessed: slot.isGuessed));
        }
      }
    }

    // Fill unresolved slots by name match (all split types: even, exact, percentage, shares, exclude).
    _resolveUnresolvedSlotsAtConfirmation(slots, members, repo, contactMap);

    final exactSum = result.splitType == 'exact'
        ? slots.fold<double>(0.0, (s, slot) => s + slot.amount)
        : 0.0;
    const tolerance = 0.01;
    final percentageSum = result.splitType == 'percentage' && result.percentageByName.isNotEmpty
        ? result.percentageByName.values.fold<double>(0.0, (a, b) => a + b)
        : 0.0;
    final exactValid = result.splitType == 'exact'
        ? (exactSum - result.amount).abs() <= tolerance
        : result.splitType == 'percentage'
            ? (percentageSum - 100.0).abs() <= tolerance && slots.isNotEmpty
            : result.splitType == 'shares'
                ? slots.isNotEmpty
                : true;

    final undoResult = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _ExpenseConfirmDialog(
        repo: repo,
        groupId: groupId,
        result: result,
        payerId: payerId,
        splitTypeCap: splitTypeCap,
        initialSlots: slots,
        isExclude: isExclude,
        allIds: allIds,
        exactValid: exactValid,
      ),
    );
    if (!context.mounted) return;
    if (undoResult != null && undoResult['groupId'] != null && undoResult['expenseId'] != null) {
      final gid = undoResult['groupId'] as String;
      final eid = undoResult['expenseId'] as String;
      _showUndoExpenseOverlay(context, groupId: gid, expenseId: eid, description: repo.lastAddedDescription ?? '', amount: repo.lastAddedAmount ?? 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final borderColor = isDark ? const Color(0xFF3A3A3C) : const Color(0xFFE5E5E5);
    final iconColor = theme.colorScheme.onSurfaceVariant;
    final textColor = theme.colorScheme.onSurface;
    final hintColor = theme.colorScheme.onSurfaceVariant;
    final buttonBgColor = isDark ? const Color(0xFF3A3A3C) : const Color(0xFFF0F0F0);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: borderColor, width: 1),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: (isDark ? Colors.black : const Color(0xFF1A1A1A)).withValues(alpha: isDark ? 0.3 : 0.06),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            IconButton(
              onPressed: () async {
                final result = await Navigator.pushNamed(
                  context,
                  '/expense-input',
                  arguments: widget.group,
                );
                if (!context.mounted) return;
                final map = result as Map<String, dynamic>?;
                if (map != null && map['groupId'] != null && map['expenseId'] != null) {
                  final repo = CycleRepository.instance;
                  final groupId = map['groupId'] as String;
                  final expenseId = map['expenseId'] as String;
                  if (!context.mounted) return;
                  _showUndoExpenseOverlay(context, groupId: groupId, expenseId: expenseId, description: repo.lastAddedDescription ?? '', amount: repo.lastAddedAmount ?? 0.0);
                }
              },
              icon: Icon(
                Icons.keyboard_alt_outlined,
                size: 22,
                color: iconColor,
              ),
              style: IconButton.styleFrom(
                padding: const EdgeInsets.all(8),
                minimumSize: const Size(40, 40),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: !_loading && !_inCooldown,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: _inCooldown
                      ? 'AI cooling down — use keyboard for manual entry'
                      : 'e.g. Dinner 500 with Ash',
                  hintStyle: TextStyle(
                    color: hintColor,
                    fontSize: 17,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  isDense: true,
                ),
                style: TextStyle(fontSize: 17, color: textColor),
              ),
            ),
            const SizedBox(width: 8),
            if (_loading)
              SizedBox(
                width: 36,
                height: 36,
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: textColor,
                    ),
                  ),
                ),
              )
            else
              IconButton(
                onPressed: (_sendAllowed &&
                        _controller.text.trim().isNotEmpty &&
                        !_inCooldown)
                    ? _submit
                    : null,
                icon: Icon(
                  Icons.arrow_upward_rounded,
                  color: (_sendAllowed &&
                          _controller.text.trim().isNotEmpty &&
                          !_inCooldown)
                      ? textColor
                      : hintColor,
                  size: 24,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: buttonBgColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ParticipantSlot {
  final String name;
  double amount;
  String? id;
  final bool isGuessed;
  _ParticipantSlot({required this.name, required this.amount, this.id, this.isGuessed = false});
}

class _ExpenseConfirmDialog extends StatefulWidget {
  final CycleRepository repo;
  final String groupId;
  final ParsedExpenseResult result;
  final String payerId;
  final String splitTypeCap;
  final List<_ParticipantSlot> initialSlots;
  final bool isExclude;
  final List<String> allIds;
  final bool exactValid;

  const _ExpenseConfirmDialog({
    required this.repo,
    required this.groupId,
    required this.result,
    required this.payerId,
    required this.splitTypeCap,
    required this.initialSlots,
    required this.isExclude,
    required this.allIds,
    required this.exactValid,
  });

  @override
  State<_ExpenseConfirmDialog> createState() => _ExpenseConfirmDialogState();
}

class _ExpenseConfirmDialogState extends State<_ExpenseConfirmDialog> {
  late List<_ParticipantSlot> slots;
  List<TextEditingController>? _amountControllers;
  late TextEditingController _descriptionController;
  late TextEditingController _amountController;
  late String _payerId;

  static String _formatAmountForEdit(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  @override
  void initState() {
    super.initState();
    slots = widget.initialSlots.map((s) => _ParticipantSlot(name: s.name, amount: s.amount, id: s.id, isGuessed: s.isGuessed)).toList();
    _descriptionController = TextEditingController(text: widget.result.description);
    _amountController = TextEditingController(text: _formatAmountForEdit(widget.result.amount));
    _payerId = widget.payerId;
    if (widget.splitTypeCap == 'Exact') {
      _amountControllers = List.generate(slots.length, (i) => TextEditingController(text: _formatAmountForEdit(slots[i].amount)));
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    for (final c in _amountControllers ?? <TextEditingController>[]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _allResolved => slots.every((s) => s.id != null && s.id!.isNotEmpty);

  double get _totalSplit => slots.fold<double>(0.0, (sum, slot) => sum + slot.amount);

  static const double _splitTolerance = 0.01;

  double? get _editedAmount {
    final v = double.tryParse(_amountController.text.trim());
    return v != null && v > 0 ? v : null;
  }

  bool get _isReadyToConfirm {
    final amount = _editedAmount;
    final description = _descriptionController.text.trim();
    final splitMatches = amount != null && (_totalSplit - amount).abs() < _splitTolerance;
    return amount != null && amount > 0 && description.isNotEmpty && splitMatches && _allResolved;
  }

  String? get _notReadyReason {
    final amount = _editedAmount;
    if (amount == null || amount <= 0) return 'Amount must be greater than 0.';
    if (_descriptionController.text.trim().isEmpty) return 'Description is required.';
    if ((_totalSplit - amount).abs() >= _splitTolerance) return 'Split doesn\'t match total.';
    if (!_allResolved) return 'Select a member for each slot.';
    return null;
  }

  void _redistributeEvenAmount() {
    final amount = _editedAmount;
    if (amount == null || slots.isEmpty || widget.splitTypeCap == 'Exact' || widget.splitTypeCap == 'Percentage' || widget.splitTypeCap == 'Shares') return;
    final perShare = amount / slots.length;
    for (var i = 0; i < slots.length; i++) {
      slots[i] = _ParticipantSlot(name: slots[i].name, amount: perShare, id: slots[i].id, isGuessed: slots[i].isGuessed);
    }
    setState(() {});
  }

  void _pickPayer() {
    final repo = widget.repo;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Who paid?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A1A)),
              ),
            ),
            ...repo.getMembersForGroup(widget.groupId).where((m) => !m.id.startsWith('p_')).map((m) {
              final displayName = repo.getMemberDisplayNameById(m.id);
              return ListTile(
                title: Text(displayName),
                onTap: () {
                  setState(() => _payerId = m.id);
                  Navigator.pop(ctx);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _pickMember(int slotIndex) {
    final repo = widget.repo;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Select member',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A1A)),
              ),
            ),
            ...repo.getMembersForGroup(widget.groupId).where((m) => !m.id.startsWith('p_')).map((m) {
              final displayName = repo.getMemberDisplayNameById(m.id);
              return ListTile(
                title: Text(displayName),
                onTap: () {
                  setState(() => slots[slotIndex] = _ParticipantSlot(name: slots[slotIndex].name, amount: slots[slotIndex].amount, id: m.id, isGuessed: slots[slotIndex].isGuessed));
                  Navigator.pop(ctx);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _onConfirm() async {
    if (!_isReadyToConfirm) {
      HapticFeedback.heavyImpact();
      return;
    }
    HapticFeedback.lightImpact();
    final repo = widget.repo;
    final groupId = widget.groupId;
    final amount = _editedAmount ?? widget.result.amount;
    final description = _descriptionController.text.trim();
    final expenseId = DateTime.now().millisecondsSinceEpoch.toString();

    final persistSplitType = (widget.splitTypeCap == 'Percentage' || widget.splitTypeCap == 'Shares')
        ? 'Exact'
        : widget.splitTypeCap;

    try {
      final participantSlots = slots.map((s) => ParticipantSlot(
        name: s.name,
        amount: s.amount,
        memberId: s.id,
        isGuessed: s.isGuessed,
      )).toList();

      final payerSlots = [PayerContributionSlot(memberId: _payerId, amount: amount)];

      final normalized = buildNormalizedExpenseFromSlots(
        amount: amount,
        description: description,
        category: widget.result.category,
        date: DateTime.now().millisecondsSinceEpoch.toString(),
        payerSlots: payerSlots,
        slots: participantSlots,
        splitType: persistSplitType,
        allMemberIds: widget.allIds,
        excludedIds: widget.isExclude ? slots.map((s) => s.id!).toList() : null,
      );

      await repo.addExpenseFromNormalized(
        groupId,
        id: expenseId,
        normalized: normalized,
        splitType: persistSplitType,
      );

      if (!context.mounted) return;
      Navigator.pop(context, {'groupId': groupId, 'expenseId': expenseId});
    } on NormalizedExpenseError catch (e) {
      HapticFeedback.heavyImpact();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on ArgumentError catch (e) {
      HapticFeedback.heavyImpact();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? 'Invalid expense.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      HapticFeedback.heavyImpact();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save expense. Try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  static const Color _dialogGradientStart = Color(0xFF1A1A1A);
  static const Color _dialogGradientEnd = Color(0xFF6B6B6B);

  @override
  Widget build(BuildContext context) {
    final repo = widget.repo;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F8),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1A1A1A).withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_dialogGradientStart, _dialogGradientEnd],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Confirm expense',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.95),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₹${(_editedAmount ?? widget.result.amount).toStringAsFixed(0).replaceAllMapped(
                      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                      (Match m) => '${m[1]},',
                    )}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  if (_descriptionController.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      _descriptionController.text.trim(),
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AMOUNT',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF9B9B9B), letterSpacing: 0.3),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: const Color(0xFFE5E5E5)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('₹', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: const Color(0xFF6B6B6B))),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => _redistributeEvenAmount(),
                            decoration: InputDecoration(
                              isDense: true,
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              hintText: '0',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFFD0D0D0)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFFD0D0D0)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFF1A1A1A), width: 1.5),
                              ),
                            ),
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A1A)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'DESCRIPTION',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF9B9B9B), letterSpacing: 0.3),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _descriptionController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        hintText: 'What was it for?',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFD0D0D0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFD0D0D0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF1A1A1A), width: 1.5),
                        ),
                      ),
                      style: TextStyle(fontSize: 17, color: const Color(0xFF1A1A1A)),
                    ),
                    if (widget.result.category.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(widget.result.category, style: TextStyle(fontSize: 14, color: const Color(0xFF6B6B6B))),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      'PAID BY',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF9B9B9B), letterSpacing: 0.3),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _pickPayer,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFFE5E5E5)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Text(
                              repo.getMemberDisplayNameById(_payerId),
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: const Color(0xFF1A1A1A)),
                            ),
                            const Spacer(),
                            Icon(Icons.arrow_drop_down, color: const Color(0xFF6B6B6B)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Split: ${widget.splitTypeCap}',
                      style: TextStyle(fontSize: 14, color: const Color(0xFF6B6B6B)),
                    ),
                    if (widget.splitTypeCap == 'Exact' || widget.splitTypeCap == 'Percentage' || widget.splitTypeCap == 'Shares') ...[
                      const SizedBox(height: 4),
                      Text(
                        'Total: ₹${(_editedAmount ?? 0).toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} | Assigned: ₹${_totalSplit.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                        style: TextStyle(fontSize: 13, color: const Color(0xFF6B6B6B)),
                      ),
                    ],
                    if (_editedAmount != null && (_totalSplit - _editedAmount!).abs() >= _splitTolerance && (widget.splitTypeCap == 'Exact' || widget.splitTypeCap == 'Percentage' || widget.splitTypeCap == 'Shares')) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Assigned total (₹${_totalSplit.toStringAsFixed(0)}) must match amount (₹${_editedAmount!.toStringAsFixed(0)}).',
                          style: TextStyle(fontSize: 13, color: const Color(0xFFC62828)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      'PEOPLE',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF9B9B9B), letterSpacing: 0.3),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: List.generate(slots.length, (i) {
                final slot = slots[i];
                final isPlaceholder = slot.id == null || slot.id!.isEmpty;
                final isGuessed = slot.isGuessed && !isPlaceholder;
                final isExactEditable = widget.splitTypeCap == 'Exact' && _amountControllers != null && i < _amountControllers!.length;
                final label = slot.id != null && slot.id!.isNotEmpty
                    ? '${repo.getMemberDisplayNameById(slot.id!)}${slot.isGuessed ? '?' : ''}  ₹${slot.amount.toStringAsFixed(0)}'
                    : 'Select Member  ₹${slot.amount.toStringAsFixed(0)}';
                        return GestureDetector(
                          onTap: isPlaceholder && !isExactEditable ? () => _pickMember(i) : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isPlaceholder
                                  ? const Color(0xFFE8E8E8)
                                  : isGuessed
                                      ? const Color(0xFFFFF8E1)
                                      : const Color(0xFFE5E5E5),
                              borderRadius: BorderRadius.circular(8),
                              border: isPlaceholder
                                  ? Border.all(color: const Color(0xFF5B7C99), width: 1)
                                  : isGuessed
                                      ? Border.all(color: const Color(0xFFF9A825), width: 1.5)
                                      : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isExactEditable) ...[
                                  GestureDetector(
                                    onTap: isPlaceholder ? () => _pickMember(i) : null,
                                    child: Text(
                                      slot.id != null && slot.id!.isNotEmpty
                                          ? '${repo.getMemberDisplayNameById(slot.id!)}${slot.isGuessed ? '?' : ''}'
                                          : 'Select Member',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isPlaceholder ? const Color(0xFF5B7C99) : (isGuessed ? const Color(0xFFE65100) : const Color(0xFF1A1A1A)),
                                        fontStyle: isPlaceholder ? FontStyle.italic : FontStyle.normal,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  SizedBox(
                                    width: 64,
                                    child: TextField(
                                      controller: _amountControllers![i],
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      onChanged: (v) {
                                        final n = double.tryParse(v);
                                        slots[i].amount = n ?? 0;
                                        setState(() {});
                                      },
                                      decoration: InputDecoration(
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                        hintText: '₹',
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFC62828))),
                                      ),
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                  if (isPlaceholder) const SizedBox(width: 4),
                                  if (isPlaceholder) Icon(Icons.arrow_drop_down, size: 18, color: const Color(0xFF5B7C99)),
                                  if (isGuessed) const SizedBox(width: 2),
                                  if (isGuessed) Icon(Icons.info_outline, size: 14, color: const Color(0xFFF9A825)),
                                ] else ...[
                                  Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isPlaceholder
                                          ? const Color(0xFF5B7C99)
                                          : isGuessed
                                              ? const Color(0xFFE65100)
                                              : const Color(0xFF1A1A1A),
                                      fontStyle: isPlaceholder ? FontStyle.italic : FontStyle.normal,
                                    ),
                                  ),
                                  if (isPlaceholder) const SizedBox(width: 4),
                                  if (isPlaceholder) Icon(Icons.arrow_drop_down, size: 18, color: const Color(0xFF5B7C99)),
                                  if (isGuessed) const SizedBox(width: 2),
                                  if (isGuessed) Icon(Icons.info_outline, size: 14, color: const Color(0xFFF9A825)),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                    if (slots.any((s) => s.isGuessed && s.id != null)) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Highlighted names are best guesses — verify before confirming.',
                        style: TextStyle(fontSize: 12, color: const Color(0xFF9B9B9B), fontStyle: FontStyle.italic),
                      ),
                    ],
                    if (_notReadyReason != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _notReadyReason!,
                        style: const TextStyle(fontSize: 13, color: Color(0xFFC62828)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F8),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF6B6B6B),
                        side: const BorderSide(color: Color(0xFFE5E5E5)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isReadyToConfirm ? _onConfirm : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A1A1A),
                        disabledBackgroundColor: const Color(0xFFE5E5E5),
                        foregroundColor: Colors.white,
                        disabledForegroundColor: const Color(0xFFB0B0B0),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      child: const Text('Confirm', style: AppTypography.button),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
