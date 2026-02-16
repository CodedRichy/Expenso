import 'dart:async';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../models/cycle.dart';
import '../repositories/cycle_repository.dart';
import '../services/groq_expense_parser_service.dart';
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
        // Single lookup at start of builder; getActiveCycle may create a cycle if none exists.
        final activeCycle = repo.getActiveCycle(groupId);
        final expenses = repo.getExpenses(activeCycle.id);
        final pendingAmount = expenses.fold<double>(0.0, (sum, e) => sum + e.amount);
        final isPassive = activeCycle.status == CycleStatus.settling;
        final isClosing = activeCycle.status == CycleStatus.settling || defaultGroup.status == 'closing';
        final isSettled = activeCycle.status == CycleStatus.closed || defaultGroup.status == 'settled';
        final hasExpenses = expenses.isNotEmpty;

        return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.chevron_left, size: 24),
                        color: const Color(0xFF1A1A1A),
                        padding: EdgeInsets.zero,
                        alignment: Alignment.centerLeft,
                        constraints: const BoxConstraints(),
                        style: IconButton.styleFrom(
                          minimumSize: const Size(32, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                        alignment: Alignment.centerRight,
                        constraints: const BoxConstraints(),
                        style: IconButton.styleFrom(
                          minimumSize: const Size(32, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    defaultGroup.name,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A1A1A),
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
            // Amount Summary
            Container(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: const Color(0xFFE5E5E5),
                    width: 1,
                  ),
                ),
              ),
              child: !isSettled
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '₹${pendingAmount.toStringAsFixed(0).replaceAllMapped(
                            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                            (Match m) => '${m[1]},',
                          )}',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            color: isPassive ? const Color(0xFF9B9B9B) : const Color(0xFF1A1A1A),
                            letterSpacing: -0.5,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isPassive ? 'Cycle Settled - Pending Restart' : 'pending',
                          style: TextStyle(
                            fontSize: 15,
                            color: isPassive ? const Color(0xFF9B9B9B) : const Color(0xFF6B6B6B),
                          ),
                        ),
                        if (!isPassive) ...[
                          const SizedBox(height: 4),
                          Text(
                            defaultGroup.statusLine,
                            style: TextStyle(
                              fontSize: 15,
                              color: isClosing ? const Color(0xFF1A1A1A) : const Color(0xFF6B6B6B),
                              fontWeight: isClosing ? FontWeight.w500 : FontWeight.w400,
                            ),
                          ),
                        ],
                        if (repo.getGroupPendingAmount(groupId) > 0 || isPassive) ...[
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: () {
                              if (isPassive) {
                                if (repo.isCurrentUserCreator(groupId)) {
                                  repo.archiveAndRestart(groupId);
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
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                '/settlement-confirmation',
                                arguments: defaultGroup,
                              );
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              'Pay via UPI',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF5B7C99),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ],
                    )
                  : Text(
                      'All balances cleared',
                      style: TextStyle(
                        fontSize: 17,
                        color: const Color(0xFF6B6B6B),
                      ),
                    ),
            ),
            // Recent Expenses
            if (hasExpenses)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
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
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: expenses.length,
                        itemBuilder: (context, index) {
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
                                      children: [
                                        Text(
                                          () {
                                            final d = expense.description;
                                            final currentName = repo.currentUserName;
                                            if (expense.participantPhones.isEmpty) {
                                              final fallback = currentName.isNotEmpty ? currentName : 'Just you';
                                              final dLower = d.toLowerCase();
                                              if (dLower.contains(fallback.toLowerCase()) || dLower.contains('just you')) return d;
                                              return '$d — $fallback';
                                            }
                                            final names = expense.participantPhones
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
                      ),
                    ),
                  ],
                ),
              )
            else
              EmptyStates(type: 'no-expenses-new-cycle'),
            // Magic Bar + Add expense (hidden when passive - cycle is read-only)
            if (!isSettled && !isPassive)
              _MagicBarSection(group: defaultGroup),
              if (!isSettled && !isPassive)
              Container(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/expense-input',
                      arguments: defaultGroup,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFE5E5E5)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Add expense manually',
                      style: TextStyle(
                        fontSize: 17,
                        color: const Color(0xFFB0B0B0),
                      ),
                    ),
                  ),
                ),
              ),
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
            onPressed: () {
              repo.settleAndRestartCycle(groupId);
              Navigator.pop(ctx);
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

class _MagicBarSection extends StatefulWidget {
  final Group group;

  const _MagicBarSection({required this.group});

  @override
  State<_MagicBarSection> createState() => _MagicBarSectionState();
}

class _MagicBarSectionState extends State<_MagicBarSection> {
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

  List<String> _resolveParticipantNamesToPhones(
    CycleRepository repo,
    String groupId,
    List<String> names,
  ) {
    if (names.isEmpty) return [];
    final members = repo.getMembersForGroup(groupId);
    final currentName = repo.currentUserName;
    final currentPhone = repo.currentUserPhone;
    final phones = <String>[];
    for (final name in names) {
      final n = name.trim().toLowerCase();
      if (n == 'you' || (currentName.isNotEmpty && currentName.toLowerCase() == n)) {
        if (currentPhone.isNotEmpty && !phones.contains(currentPhone)) phones.add(currentPhone);
        continue;
      }
      for (final m in members) {
        final display = repo.getMemberDisplayName(m.phone).toLowerCase();
        if (display == n || display.contains(n)) {
          if (!phones.contains(m.phone)) phones.add(m.phone);
          break;
        }
      }
    }
    return phones;
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Couldn\'t parse that. Try a clearer format like "Dinner 500".',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showConfirmationDialog(CycleRepository repo, ParsedExpenseResult result) {
    final groupId = widget.group.id;
    final members = repo.getMembersForGroup(groupId);
    final allPhones = members.map((m) => m.phone).toList();

    // Payer: default current user; allow AI to set payer (e.g. "Pradhyun paid 500 for me")
    String payerPhone = repo.currentUserPhone;
    if (result.payerName != null && result.payerName!.trim().isNotEmpty) {
      final resolved = _resolveParticipantNamesToPhones(repo, groupId, [result.payerName!.trim()]);
      if (resolved.isNotEmpty) payerPhone = resolved.first;
    }

    List<String> participantPhones;
    List<String>? excludedPhones;
    Map<String, double>? exactAmountsByPhone;
    final splitTypeCap = result.splitType == 'exact'
        ? 'Exact'
        : result.splitType == 'exclude'
            ? 'Exclude'
            : 'Even';

    if (result.splitType == 'exclude' && result.excludedNames.isNotEmpty) {
      excludedPhones = _resolveParticipantNamesToPhones(repo, groupId, result.excludedNames);
      final excludedSet = excludedPhones.toSet();
      participantPhones = allPhones.where((p) => !excludedSet.contains(p)).toList();
      if (participantPhones.isEmpty) participantPhones = [payerPhone];
    } else if (result.splitType == 'exact' && result.exactAmountsByName.isNotEmpty) {
      exactAmountsByPhone = {};
      for (final entry in result.exactAmountsByName.entries) {
        final phones = _resolveParticipantNamesToPhones(repo, groupId, [entry.key]);
        if (phones.isNotEmpty) exactAmountsByPhone[phones.first] = entry.value;
      }
      participantPhones = exactAmountsByPhone.keys.toList();
      if (participantPhones.isEmpty) participantPhones = [payerPhone];
    } else {
      participantPhones = _resolveParticipantNamesToPhones(repo, groupId, result.participantNames);
      if (participantPhones.isEmpty) participantPhones = [payerPhone];
    }

    // Per-person amounts for UI
    final perPersonAmounts = <String, double>{};
    if (result.splitType == 'exact' && exactAmountsByPhone != null) {
      perPersonAmounts.addAll(exactAmountsByPhone);
    } else {
      final n = participantPhones.length;
      final perShare = n > 0 ? result.amount / n : 0.0;
      for (final p in participantPhones) {
        perPersonAmounts[p] = perShare;
      }
    }

    // Exact case: validate sum equals totalAmount
    final exactSum = exactAmountsByPhone?.values.fold<double>(0.0, (a, b) => a + b) ?? 0.0;
    const tolerance = 0.01;
    final exactValid = result.splitType != 'exact' ||
        (exactAmountsByPhone != null &&
            (exactSum - result.amount).abs() <= tolerance);

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Confirm expense',
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
                '₹${result.amount.toStringAsFixed(0).replaceAllMapped(
                  RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                  (Match m) => '${m[1]},',
                )}',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                result.description,
                style: TextStyle(fontSize: 17, color: const Color(0xFF1A1A1A)),
              ),
              if (result.category.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  result.category,
                  style: TextStyle(fontSize: 14, color: const Color(0xFF6B6B6B)),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                'Paid by ${repo.getMemberDisplayName(payerPhone)}',
                style: TextStyle(fontSize: 14, color: const Color(0xFF6B6B6B)),
              ),
              Text(
                'Split: $splitTypeCap',
                style: TextStyle(fontSize: 14, color: const Color(0xFF6B6B6B)),
              ),
              if (!exactValid) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Exact split total (₹${exactSum.toStringAsFixed(0)}) does not match expense amount (₹${result.amount.toStringAsFixed(0)}). Adjust amounts to confirm.',
                    style: TextStyle(fontSize: 13, color: const Color(0xFFC62828)),
                  ),
                ),
              ],
              if (participantPhones.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: participantPhones.map((p) {
                    final name = repo.getMemberDisplayName(p);
                    final amt = perPersonAmounts[p] ?? 0.0;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E5E5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$name  ₹${amt.toStringAsFixed(0)}',
                        style: TextStyle(fontSize: 14, color: const Color(0xFF1A1A1A)),
                      ),
                    );
                  }).toList(),
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
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: const Color(0xFF5B7C99)),
            ),
          ),
          TextButton(
            onPressed: exactValid
                ? () {
                    try {
                      repo.addExpenseFromMagicBar(
                        groupId,
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        description: result.description,
                        amount: result.amount,
                        date: 'Today',
                        payerPhone: payerPhone,
                        splitType: splitTypeCap,
                        participantPhones: participantPhones,
                        excludedPhones: excludedPhones,
                        exactAmountsByPhone: exactAmountsByPhone,
                        category: result.category,
                      );
                      Navigator.pop(ctx);
                    } on ArgumentError catch (e) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          content: Text(e.message ?? 'Invalid expense.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                : null,
            child: Text(
              'Confirm',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: exactValid ? const Color(0xFF1A1A1A) : const Color(0xFFB0B0B0),
              ),
            ),
          ),
        ],
      ),
    );
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
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: !_loading && !_inCooldown,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: _inCooldown
                      ? 'AI is cooling down... try manual entry'
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
