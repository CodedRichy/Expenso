import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../models/cycle.dart';
import '../repositories/cycle_repository.dart';
import '../services/groq_expense_parser_service.dart';
import '../utils/settlement_engine.dart';
import 'empty_states.dart';

class GroupDetail extends StatelessWidget {
  final Group? group;

  const GroupDetail({
    super.key,
    this.group,
  });

  @override
  Widget build(BuildContext context) {
    final repo = CycleRepository.instance;
    final routeGroup = ModalRoute.of(context)?.settings.arguments as Group?;
    final resolvedGroup = routeGroup ?? group;
    if (resolvedGroup == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.maybePop(context));
      return const Scaffold(body: SizedBox.shrink());
    }
    final groupId = resolvedGroup.id;

    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final defaultGroup = repo.getGroup(groupId) ?? resolvedGroup;
        // getActiveCycle may create a cycle if none exists; single lookup here.
        final activeCycle = repo.getActiveCycle(groupId);
        final expenses = repo.getExpenses(activeCycle.id);
        final isPassive = activeCycle.status == CycleStatus.settling;
        final isSettled = activeCycle.status == CycleStatus.closed || defaultGroup.status == 'settled';
        final hasExpenses = expenses.isNotEmpty;

        return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 40, 8, 12),
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
                expenses: expenses,
                isSettled: isSettled,
                isPassive: isPassive,
              ),
            ),
            if (!isSettled && (repo.getGroupPendingAmount(groupId) > 0 || isPassive)) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: ElevatedButton(
                  onPressed: () async {
                    if (isPassive) {
                      if (repo.isCurrentUserCreator(groupId)) {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Start new cycle?'),
                            content: const Text(
                              'This will archive current expenses and start a fresh cycle.',
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
                      final isLeader = repo.isCurrentUserCreator(groupId);
                      if (isLeader) {
                        _showSettleConfirmDialog(context, repo, groupId);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Request sent to group leader.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1A1A),
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
                        ? (repo.isCurrentUserCreator(groupId) ? 'Start New Cycle' : 'Waiting for creator to restart')
                        : 'Settle now',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: TextButton(
                  onPressed: () {
                    final upiId = repo.currentUserUpiId?.trim();
                    if (upiId == null || upiId.isEmpty) {
                      Navigator.pushNamed(context, '/profile');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Set your UPI ID to enable easy payments.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }
                    Navigator.pushNamed(
                      context,
                      '/settlement-confirmation',
                      arguments: defaultGroup,
                    );
                  },
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                  child: const Text(
                    'Pay via UPI',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF5B7C99),
                    ),
                  ),
                ),
              ),
            ],
            if (!isSettled && hasExpenses) ...[
              Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: const Color(0xFFE5E5E5), width: 1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BALANCES',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF9B9B9B),
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...() {
                      final members = repo.getMembersForGroup(groupId);
                      final debts = SettlementEngine.computeDebts(expenses, members);
                      if (debts.isEmpty) {
                        return [
                          Text(
                            'No debts to settle',
                            style: TextStyle(fontSize: 15, color: const Color(0xFF6B6B6B)),
                          ),
                        ];
                      }
                      return debts.map((d) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '${repo.getMemberDisplayName(d.fromPhone)} owes ${repo.getMemberDisplayName(d.toPhone)} ₹${d.amount.toStringAsFixed(0).replaceAllMapped(
                            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                            (Match m) => '${m[1]},',
                          )}',
                          style: TextStyle(fontSize: 15, color: const Color(0xFF1A1A1A)),
                        ),
                      )).toList();
                    }(),
                  ],
                ),
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
                                        Text(
                                            () {
                                            final d = expense.description;
                                            final others = expense.participantPhones
                                                .where((p) => p != expense.paidByPhone)
                                                .toList();
                                            if (others.isEmpty) return d;
                                            final names = others
                                                .map((p) => repo.getMemberDisplayName(p))
                                                .toList();
                                            final dLower = d.toLowerCase();
                                            final notInDescription = names
                                                .where((name) => !dLower.contains(name.toLowerCase()))
                                                .toList();
                                            if (notInDescription.isEmpty) return d;
                                            return '$d — with ${notInDescription.join(', ')}';
                                          }(),
                                          style: TextStyle(
                                            fontSize: 17,
                                            color: const Color(0xFF1A1A1A),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          expense.date,
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
  final List<Expense> expenses;
  final bool isSettled;
  final bool isPassive;

  const _DecisionClarityCard({
    required this.repo,
    required this.groupId,
    required this.expenses,
    required this.isSettled,
    required this.isPassive,
  });

  static const double _minHeight = 132.0;
  static const Color _blackGradientStart = Color(0xFF0D0D0D);
  static const Color _blackGradientEnd = Color(0xFF1A1A1A);

  @override
  Widget build(BuildContext context) {
    final isEmpty = expenses.isEmpty;
    final cycleTotal = expenses.fold<double>(0.0, (s, e) => s + e.amount);
    final members = repo.getMembersForGroup(groupId);
    final memberCount = members.length;
    final netBalances = SettlementEngine.computeNetBalances(expenses, members);
    final myPhone = repo.currentUserPhone;
    double yourShare = 0.0;
    for (final e in expenses) {
      if (e.splitAmountsByPhone != null && e.splitAmountsByPhone!.containsKey(myPhone)) {
        yourShare += e.splitAmountsByPhone![myPhone]!;
      } else if (e.participantPhones.contains(myPhone)) {
        yourShare += e.amount / e.participantPhones.length;
      } else if (e.participantPhones.isEmpty && memberCount > 0) {
        yourShare += e.amount / memberCount;
      }
    }
    double myNet = netBalances[myPhone] ?? 0.0;
    if (myNet.isNaN || myNet.isInfinite) myNet = 0.0;
    final isCredit = myNet >= 0;
    final isNetClear = (netBalances[myPhone] ?? 0.0).isNaN || (netBalances[myPhone] ?? 0.0).isInfinite;

    return Container(
      constraints: const BoxConstraints(minHeight: _minHeight),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A1A1A).withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_blackGradientStart, _blackGradientEnd],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: isEmpty
                ? KeyedSubtree(
                    key: const ValueKey('empty'),
                    child: _buildEmptyState(context),
                  )
                : KeyedSubtree(
                    key: const ValueKey('content'),
                    child: _buildContent(
                      context,
                      cycleTotal: cycleTotal,
                      yourShare: yourShare,
                      myNet: myNet,
                      isCredit: isCredit,
                      isNetClear: isNetClear,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Zero-Waste Cycle',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.95),
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Add expenses with the Magic Bar below or tap the keyboard for manual entry.',
          style: TextStyle(
            fontSize: 14,
            height: 1.35,
            color: Colors.white.withValues(alpha: 0.75),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(
    BuildContext context, {
    required double cycleTotal,
    required double yourShare,
    required double myNet,
    required bool isCredit,
    bool isNetClear = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cycle Total: ₹${_fmtRupee(cycleTotal)}',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.98),
            letterSpacing: -0.5,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your share',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.7),
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '₹${_fmtRupee(yourShare)}',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
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
                    'Your Status',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.7),
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isNetClear ? 'Balance Clear' : '${myNet >= 0 ? '+' : ''}₹${_fmtRupee(myNet.abs())}',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: isNetClear ? Colors.white70 : (isCredit ? Colors.greenAccent : Colors.redAccent),
                    ),
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

  /// Resolves a single name to one phone, or null if ambiguous/unmatched.
  String? _resolveOneNameToPhone(CycleRepository repo, String groupId, String name) {
    final r = _resolveOneNameToPhoneWithGuess(repo, groupId, name);
    return r.phone;
  }

  /// Like [_resolveOneNameToPhone] but also returns whether the match was fuzzy (user should verify).
  ({String? phone, bool isGuessed}) _resolveOneNameToPhoneWithGuess(
    CycleRepository repo,
    String groupId,
    String name,
  ) {
    final n = name.trim().toLowerCase();
    if (n.isEmpty) return (phone: null, isGuessed: false);
    final members = repo.getMembersForGroup(groupId);
    final currentName = repo.currentUserName;
    final currentPhone = repo.currentUserPhone;
    if (n == 'you' || (currentName.isNotEmpty && currentName.toLowerCase() == n)) {
      return (phone: currentPhone.isNotEmpty ? currentPhone : null, isGuessed: false);
    }
    String? exactMatch;
    List<String> partialMatches = [];
    for (final m in members) {
      final display = repo.getMemberDisplayName(m.phone).toLowerCase();
      if (display == n) {
        exactMatch = m.phone;
        break;
      }
      if (display.contains(n) || n.contains(display) ||
          display.startsWith(n) || n.startsWith(display)) {
        partialMatches.add(m.phone);
      }
    }
    if (exactMatch != null) return (phone: exactMatch, isGuessed: false);
    if (partialMatches.length == 1) return (phone: partialMatches.single, isGuessed: true);
    return (phone: null, isGuessed: false);
  }

  Future<void> _submit() async {
    final input = _controller.text.trim();
    if (input.isEmpty || _loading || !_sendAllowed || _inCooldown) return;
    final repo = CycleRepository.instance;
    final groupId = widget.group.id;
    final members = repo.getMembersForGroup(groupId);
    final memberNames = members.map((m) => repo.getMemberDisplayName(m.phone)).toList();

    setState(() => _loading = true);
    try {
      final result = await GroqExpenseParserService.parse(
        userInput: input,
        groupMemberNames: memberNames,
      );
      if (!mounted) return;
      setState(() => _loading = false);
      _controller.clear();
      setState(() => _sendAllowed = false);
      HapticFeedback.lightImpact();
      _showConfirmationDialog(repo, result);
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

  Future<void> _showConfirmationDialog(CycleRepository repo, ParsedExpenseResult result) async {
    final groupId = widget.group.id;
    final members = repo.getMembersForGroup(groupId);
    final allPhones = members.map((m) => m.phone).toList();

    String payerPhone = repo.currentUserPhone;
    if (result.payerName != null && result.payerName!.trim().isNotEmpty) {
      final p = _resolveOneNameToPhone(repo, groupId, result.payerName!.trim());
      if (p != null) payerPhone = p;
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

    if (result.splitType == 'exclude' && result.excludedNames.isNotEmpty) {
      for (final name in result.excludedNames) {
        final r = _resolveOneNameToPhoneWithGuess(repo, groupId, name);
        slots.add(_ParticipantSlot(name: name, amount: 0, phone: r.phone, isGuessed: r.isGuessed));
      }
    } else if (result.splitType == 'exact' && result.exactAmountsByName.isNotEmpty) {
      for (final entry in result.exactAmountsByName.entries) {
        final r = _resolveOneNameToPhoneWithGuess(repo, groupId, entry.key);
        slots.add(_ParticipantSlot(name: entry.key, amount: entry.value, phone: r.phone, isGuessed: r.isGuessed));
      }
    } else if (result.splitType == 'percentage' && result.percentageByName.isNotEmpty) {
      for (final entry in result.percentageByName.entries) {
        final name = entry.key;
        final pct = entry.value;
        final amount = result.amount * (pct / 100);
        String? phone;
        String displayName = name;
        if (name.trim().toLowerCase() == 'me' || name.trim().toLowerCase() == 'i') {
          phone = repo.currentUserPhone;
          displayName = repo.getMemberDisplayName(phone);
        } else {
          final r = _resolveOneNameToPhoneWithGuess(repo, groupId, name);
          phone = r.phone;
          displayName = name;
        }
        slots.add(_ParticipantSlot(name: displayName, amount: amount, phone: phone, isGuessed: false));
      }
    } else if (result.splitType == 'shares' && result.sharesByName.isNotEmpty) {
      final totalShares = result.sharesByName.values.fold<double>(0.0, (a, b) => a + b);
      if (totalShares > 0) {
        for (final entry in result.sharesByName.entries) {
          final name = entry.key;
          final personShares = entry.value;
          final amount = result.amount * (personShares / totalShares);
          String? phone;
          String displayName = name;
          if (name.trim().toLowerCase() == 'me' || name.trim().toLowerCase() == 'i') {
            phone = repo.currentUserPhone;
            displayName = repo.getMemberDisplayName(phone);
          } else {
            final r = _resolveOneNameToPhoneWithGuess(repo, groupId, name);
            phone = r.phone;
            displayName = name;
          }
          slots.add(_ParticipantSlot(name: displayName, amount: amount, phone: phone, isGuessed: false));
        }
      }
    } else {
      List<String> names = result.participantNames;
      if (names.isEmpty) {
        for (final m in members) {
          final displayName = repo.getMemberDisplayName(m.phone);
          final perShare = members.isNotEmpty ? result.amount / members.length : result.amount;
          slots.add(_ParticipantSlot(name: displayName, amount: perShare, phone: m.phone, isGuessed: false));
        }
      } else {
        final perShare = result.amount / names.length;
        for (final name in names) {
          final r = _resolveOneNameToPhoneWithGuess(repo, groupId, name);
          slots.add(_ParticipantSlot(name: name, amount: perShare, phone: r.phone, isGuessed: r.isGuessed));
        }
      }
    }

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
        payerPhone: payerPhone,
        splitTypeCap: splitTypeCap,
        initialSlots: slots,
        isExclude: isExclude,
        allPhones: allPhones,
        exactValid: exactValid,
      ),
    );
    if (!context.mounted) return;
    if (undoResult != null && undoResult['groupId'] != null && undoResult['expenseId'] != null) {
      final gid = undoResult['groupId'] as String;
      final eid = undoResult['expenseId'] as String;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Expense added'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => repo.deleteExpense(gid, eid),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: const Color(0xFFE5E5E5), width: 1),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1A1A1A).withValues(alpha: 0.06),
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Expense added'),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 3),
                      action: SnackBarAction(
                        label: 'Undo',
                        onPressed: () {
                          repo.deleteExpense(groupId, expenseId);
                        },
                      ),
                    ),
                  );
                }
              },
              icon: Icon(
                Icons.keyboard_alt_outlined,
                size: 22,
                color: const Color(0xFF6B6B6B),
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
                      : 'e.g. Dinner 500 with Pradhyun',
                  hintStyle: TextStyle(
                    color: _inCooldown ? const Color(0xFF6B6B6B) : const Color(0xFFB0B0B0),
                    fontSize: 16,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  isDense: true,
                ),
                style: TextStyle(fontSize: 16, color: const Color(0xFF1A1A1A)),
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
                      color: const Color(0xFF1A1A1A),
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
                      ? const Color(0xFF1A1A1A)
                      : const Color(0xFFB0B0B0),
                  size: 24,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFF0F0F0),
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
  String? phone;
  final bool isGuessed;
  _ParticipantSlot({required this.name, required this.amount, this.phone, this.isGuessed = false});
}

class _ExpenseConfirmDialog extends StatefulWidget {
  final CycleRepository repo;
  final String groupId;
  final ParsedExpenseResult result;
  final String payerPhone;
  final String splitTypeCap;
  final List<_ParticipantSlot> initialSlots;
  final bool isExclude;
  final List<String> allPhones;
  final bool exactValid;

  const _ExpenseConfirmDialog({
    required this.repo,
    required this.groupId,
    required this.result,
    required this.payerPhone,
    required this.splitTypeCap,
    required this.initialSlots,
    required this.isExclude,
    required this.allPhones,
    required this.exactValid,
  });

  @override
  State<_ExpenseConfirmDialog> createState() => _ExpenseConfirmDialogState();
}

class _ExpenseConfirmDialogState extends State<_ExpenseConfirmDialog> {
  late List<_ParticipantSlot> slots;
  List<TextEditingController>? _amountControllers;

  static String _formatAmountForEdit(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  @override
  void initState() {
    super.initState();
    slots = widget.initialSlots.map((s) => _ParticipantSlot(name: s.name, amount: s.amount, phone: s.phone, isGuessed: s.isGuessed)).toList();
    if (widget.splitTypeCap == 'Exact') {
      _amountControllers = List.generate(slots.length, (i) => TextEditingController(text: _formatAmountForEdit(slots[i].amount)));
    }
  }

  @override
  void dispose() {
    for (final c in _amountControllers ?? <TextEditingController>[]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _allResolved => slots.every((s) => s.phone != null && s.phone!.isNotEmpty);

  double get _totalSplit => slots.fold<double>(0.0, (sum, slot) => sum + slot.amount);

  static const double _splitTolerance = 0.01;

  bool get _isReadyToConfirm {
    final amount = widget.result.amount;
    final description = widget.result.description.trim();
    final splitMatches = (_totalSplit - amount).abs() < _splitTolerance;
    return amount > 0 && description.isNotEmpty && splitMatches && _allResolved;
  }

  String? get _notReadyReason {
    if (widget.result.amount <= 0) return 'Amount must be greater than 0.';
    if (widget.result.description.trim().isEmpty) return 'Description is required.';
    if ((_totalSplit - widget.result.amount).abs() >= _splitTolerance) return 'Split doesn\'t match total.';
    if (!_allResolved) return 'Select a member for each slot.';
    return null;
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
            ...repo.getMembersForGroup(widget.groupId).map((m) {
              final displayName = repo.getMemberDisplayName(m.phone);
              return ListTile(
                title: Text(displayName),
                onTap: () {
                  setState(() => slots[slotIndex].phone = m.phone);
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
    List<String> participantPhones;
    List<String>? excludedPhones;
    Map<String, double>? exactAmountsByPhone;

    if (widget.isExclude) {
      excludedPhones = slots.map((s) => s.phone!).toList();
      final excludedSet = excludedPhones.toSet();
      participantPhones = widget.allPhones.where((p) => !excludedSet.contains(p)).toList();
      if (participantPhones.isEmpty) participantPhones = [widget.payerPhone];
    } else if (widget.splitTypeCap == 'Exact' || widget.splitTypeCap == 'Percentage' || widget.splitTypeCap == 'Shares') {
      exactAmountsByPhone = {for (final s in slots) s.phone!: s.amount};
      participantPhones = exactAmountsByPhone.keys.toList();
    } else {
      participantPhones = slots.map((s) => s.phone!).toList();
    }

    final persistSplitType = (widget.splitTypeCap == 'Percentage' || widget.splitTypeCap == 'Shares')
        ? 'Exact'
        : widget.splitTypeCap;
    final expenseId = DateTime.now().millisecondsSinceEpoch.toString();
    try {
      await repo.addExpenseFromMagicBar(
        groupId,
        id: expenseId,
        description: widget.result.description,
        amount: widget.result.amount,
        date: 'Today',
        payerPhone: widget.payerPhone,
        splitType: persistSplitType,
        participantPhones: participantPhones,
        excludedPhones: excludedPhones,
        exactAmountsByPhone: exactAmountsByPhone,
        category: widget.result.category,
      );
      if (!context.mounted) return;
      Navigator.pop(context, {'groupId': groupId, 'expenseId': expenseId});
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

  @override
  Widget build(BuildContext context) {
    final repo = widget.repo;
    final exactSum = widget.result.splitType == 'exact'
        ? slots.fold<double>(0.0, (s, slot) => s + slot.amount)
        : 0.0;

    return AlertDialog(
      title: Text(
        'Confirm expense',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A1A)),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '₹${widget.result.amount.toStringAsFixed(0).replaceAllMapped(
                RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                (Match m) => '${m[1]},',
              )}',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: const Color(0xFF1A1A1A)),
            ),
            const SizedBox(height: 8),
            Text(widget.result.description, style: TextStyle(fontSize: 17, color: const Color(0xFF1A1A1A))),
            if (widget.result.category.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(widget.result.category, style: TextStyle(fontSize: 14, color: const Color(0xFF6B6B6B))),
            ],
            const SizedBox(height: 4),
            Text(
              'Paid by ${repo.getMemberDisplayName(widget.payerPhone)}',
              style: TextStyle(fontSize: 14, color: const Color(0xFF6B6B6B)),
            ),
            Text('Split: ${widget.splitTypeCap}', style: TextStyle(fontSize: 14, color: const Color(0xFF6B6B6B))),
            if (widget.splitTypeCap == 'Exact' || widget.splitTypeCap == 'Percentage' || widget.splitTypeCap == 'Shares') ...[
              const SizedBox(height: 4),
              Text(
                'Total: ₹${widget.result.amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} | Assigned: ₹${_totalSplit.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                style: TextStyle(fontSize: 13, color: const Color(0xFF6B6B6B)),
              ),
            ],
            if (!widget.exactValid) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Exact split total (₹${exactSum.toStringAsFixed(0)}) does not match expense amount (₹${widget.result.amount.toStringAsFixed(0)}).',
                  style: TextStyle(fontSize: 13, color: const Color(0xFFC62828)),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: List.generate(slots.length, (i) {
                final slot = slots[i];
                final isPlaceholder = slot.phone == null || slot.phone!.isEmpty;
                final isGuessed = slot.isGuessed && !isPlaceholder;
                final isExactEditable = widget.splitTypeCap == 'Exact' && _amountControllers != null && i < _amountControllers!.length;
                final label = slot.phone != null && slot.phone!.isNotEmpty
                    ? '${repo.getMemberDisplayName(slot.phone!)}${slot.isGuessed ? '?' : ''}  ₹${slot.amount.toStringAsFixed(0)}'
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
                      borderRadius: BorderRadius.circular(6),
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
                              slot.phone != null && slot.phone!.isNotEmpty
                                  ? '${repo.getMemberDisplayName(slot.phone!)}${slot.isGuessed ? '?' : ''}'
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
                                border: const OutlineInputBorder(),
                                errorBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFC62828))),
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
            if (slots.any((s) => s.isGuessed && s.phone != null)) ...[
              const SizedBox(height: 6),
              Text(
                'Highlighted names are best guesses — verify before confirming.',
                style: TextStyle(fontSize: 12, color: const Color(0xFF9B9B9B), fontStyle: FontStyle.italic),
              ),
            ],
            if (_notReadyReason != null) ...[
              const SizedBox(height: 10),
              Text(
                _notReadyReason!,
                style: const TextStyle(fontSize: 13, color: Color(0xFFC62828)),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: const Color(0xFF5B7C99))),
        ),
        TextButton(
          onPressed: _onConfirm,
          child: Text(
            'Confirm',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _isReadyToConfirm ? const Color(0xFF1A1A1A) : const Color(0xFFB0B0B0),
            ),
          ),
        ),
      ],
    );
  }
}
