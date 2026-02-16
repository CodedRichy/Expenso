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
            // Main content (scrollable area + fills space so Smart Bar stays at bottom)
            Expanded(
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
                                            // No "— with X" when no other participants (empty or only payer in split, e.g. "dinner 2000").
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
            // Smart Bar at bottom (hidden when passive)
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
              await repo.archiveAndRestart(groupId);
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

    String payerPhone = repo.currentUserPhone;
    if (result.payerName != null && result.payerName!.trim().isNotEmpty) {
      final p = _resolveOneNameToPhone(repo, groupId, result.payerName!.trim());
      if (p != null) payerPhone = p;
    }

    final splitTypeCap = result.splitType == 'exact'
        ? 'Exact'
        : result.splitType == 'exclude'
            ? 'Exclude'
            : 'Even';

    // Build slots: each has name, amount, and resolved phone (or null → "Select Member")
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
    } else {
      // When user didn't say "with X": in a 2-person group default to the other member ("Dinner 2000" → "Dinner – with Prasi"); else payer-only.
      List<String> names = result.participantNames;
      if (names.isEmpty && members.length == 2) {
        final others = allPhones.where((p) => p != repo.currentUserPhone).toList();
        if (others.isNotEmpty) names = [repo.getMemberDisplayName(others.first)];
      }
      final perShare = names.isNotEmpty ? result.amount / names.length : result.amount;
      for (final name in names) {
        final r = _resolveOneNameToPhoneWithGuess(repo, groupId, name);
        slots.add(_ParticipantSlot(name: name, amount: perShare, phone: r.phone, isGuessed: r.isGuessed));
      }
    }

    final exactSum = result.splitType == 'exact'
        ? slots.fold<double>(0.0, (s, slot) => s + slot.amount)
        : 0.0;
    const tolerance = 0.01;
    final exactValid = result.splitType != 'exact' ||
        (exactSum - result.amount).abs() <= tolerance;

    showDialog<void>(
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
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  '/expense-input',
                  arguments: widget.group,
                );
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
  final double amount;
  String? phone;
  final bool isGuessed; // true when resolved via fuzzy/partial match — highlight in confirmation
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

  @override
  void initState() {
    super.initState();
    slots = widget.initialSlots.map((s) => _ParticipantSlot(name: s.name, amount: s.amount, phone: s.phone, isGuessed: s.isGuessed)).toList();
  }

  bool get _allResolved => slots.every((s) => s.phone != null && s.phone!.isNotEmpty);
  bool get _canConfirm => widget.exactValid && _allResolved;

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

  void _onConfirm() {
    if (!_canConfirm) return;
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
    } else if (widget.splitTypeCap == 'Exact') {
      exactAmountsByPhone = {for (final s in slots) s.phone!: s.amount};
      participantPhones = exactAmountsByPhone.keys.toList();
    } else {
      participantPhones = slots.map((s) => s.phone!).toList();
    }

    try {
      repo.addExpenseFromMagicBar(
        groupId,
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        description: widget.result.description,
        amount: widget.result.amount,
        date: 'Today',
        payerPhone: widget.payerPhone,
        splitType: widget.splitTypeCap,
        participantPhones: participantPhones,
        excludedPhones: excludedPhones,
        exactAmountsByPhone: exactAmountsByPhone,
        category: widget.result.category,
      );
      Navigator.pop(context);
    } on ArgumentError catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Invalid expense.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
                final label = slot.phone != null && slot.phone!.isNotEmpty
                    ? '${repo.getMemberDisplayName(slot.phone!)}${slot.isGuessed ? '?' : ''}  ₹${slot.amount.toStringAsFixed(0)}'
                    : 'Select Member  ₹${slot.amount.toStringAsFixed(0)}';
                final isPlaceholder = slot.phone == null || slot.phone!.isEmpty;
                final isGuessed = slot.isGuessed && !isPlaceholder;
                return GestureDetector(
                  onTap: isPlaceholder ? () => _pickMember(i) : null,
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
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: const Color(0xFF5B7C99))),
        ),
        TextButton(
          onPressed: _canConfirm ? _onConfirm : null,
          child: Text(
            'Confirm',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _canConfirm ? const Color(0xFF1A1A1A) : const Color(0xFFB0B0B0),
            ),
          ),
        ),
      ],
    );
  }
}
