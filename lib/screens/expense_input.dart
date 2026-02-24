import 'package:flutter/material.dart';
import '../design/typography.dart';
import '../models/models.dart';
import '../repositories/cycle_repository.dart';
import '../utils/route_args.dart';

class ParsedExpense {
  final String description;
  final double amount;

  ParsedExpense({
    required this.description,
    required this.amount,
  });
}

class ExpenseInput extends StatefulWidget {
  final Group? group;

  const ExpenseInput({
    super.key,
    this.group,
  });

  @override
  State<ExpenseInput> createState() => _ExpenseInputState();
}

class _ExpenseInputState extends State<ExpenseInput> {
  String input = '';
  bool showConfirmation = false;
  ParsedExpense? parsedData;
  final Set<String> selectedMemberIds = {};
  String? _paidById;

  @override
  void initState() {
    super.initState();
    _paidById = CycleRepository.instance.currentUserId;
  }

  ParsedExpense parseExpense(String text) {
    final amountPart = RegExp(r'[\d,]+').firstMatch(text);
    final amountStr = amountPart?.group(0)?.replaceAll(',', '') ?? '';
    final amount = amountStr.isNotEmpty ? (double.tryParse(amountStr) ?? 0.0) : 0.0;

    final withIndex = text.toLowerCase().indexOf('with');
    final description = withIndex > 0
        ? text.substring(0, withIndex).replaceAll(RegExp(r'\d+'), '').trim()
        : text.replaceAll(RegExp(r'\d+'), '').trim();

    return ParsedExpense(
      description: description,
      amount: amount,
    );
  }

  void handleSubmit() {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return;
    final parsed = parseExpense(input);
    if (parsed.amount <= 0 || parsed.amount.isNaN || parsed.amount.isInfinite) return;
    setState(() {
      parsedData = parsed;
      showConfirmation = true;
    });
  }

  Future<void> handleConfirm() async {
    final payerId = _paidById ?? CycleRepository.instance.currentUserId;
    if (payerId.isEmpty) return;
    if (parsedData != null) {
      final group = ModalRoute.of(context)?.settings.arguments as Group?;
      if (group != null) {
        try {
          final repo = CycleRepository.instance;
          final List<String> participantIds = selectedMemberIds.isNotEmpty
              ? selectedMemberIds.toList()
              : repo.getMembersForGroup(group.id).where((m) => !m.id.startsWith('p_')).map((m) => m.id).toList();
          if (participantIds.isEmpty) participantIds.add(repo.currentUserId);
          final expense = Expense(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            description: parsedData!.description,
            amount: parsedData!.amount,
            date: DateTime.now().millisecondsSinceEpoch.toString(),
            participantIds: participantIds,
            paidById: payerId,
          );
          await repo.addExpense(group.id, expense);
          if (!context.mounted) return;
          setState(() {
            input = '';
            parsedData = null;
            showConfirmation = false;
            selectedMemberIds.clear();
            _paidById = repo.currentUserId;
          });
          Navigator.pop(context, {'groupId': group.id, 'expenseId': expense.id});
          return;
        } on ArgumentError catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(e.message ?? 'Invalid expense.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Could not save expense. Try again.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }
      }
    }
    setState(() {
      input = '';
      parsedData = null;
      showConfirmation = false;
      selectedMemberIds.clear();
      _paidById = CycleRepository.instance.currentUserId;
    });
    if (context.mounted) Navigator.pop(context);
  }

  void handleEdit() {
    setState(() {
      showConfirmation = false;
      parsedData = null;
    });
  }

  bool get _canSubmit {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return false;
    final amount = parseExpense(input).amount;
    return amount > 0 && !amount.isNaN && !amount.isInfinite;
  }

  /// As user types, if any word in the input matches a member's display name, auto-add that member to Who's Involved.
  void _syncSelectedMembersFromInput(Group group) {
    final repo = CycleRepository.instance;
    final members = repo.getMembersForGroup(group.id).where((m) => !m.id.startsWith('p_'));
    if (members.isEmpty) return;
    final words = input
        .split(RegExp(r'[\s,]+'))
        .map((s) => s.trim().toLowerCase())
        .where((s) => s.isNotEmpty)
        .toSet();
    for (final member in members) {
      final displayName = repo.getMemberDisplayNameById(member.id);
      if (displayName.isEmpty || displayName == 'Unknown') continue;
      final nameLower = displayName.trim().toLowerCase();
      final matches = words.contains(nameLower) || input.toLowerCase().contains(nameLower);
      if (matches) {
        selectedMemberIds.add(member.id);
      }
    }
  }

  Widget _buildWhoPaid(BuildContext context, Group group) {
    final repo = CycleRepository.instance;
    final members = repo.getMembersForGroup(group.id).where((m) => !m.id.startsWith('p_')).toList();
    if (members.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WHO PAID?',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF9B9B9B),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: members.map((member) {
            final isSelected = _paidById == member.id;
            final displayName = repo.getMemberDisplayNameById(member.id);
            return ChoiceChip(
              label: Text(displayName),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) setState(() => _paidById = member.id);
              },
              selectedColor: const Color(0xFF1A1A1A),
              labelStyle: TextStyle(
                fontSize: 15,
                color: isSelected ? Colors.white : const Color(0xFF1A1A1A),
              ),
              backgroundColor: Colors.white,
              side: BorderSide(
                color: isSelected ? const Color(0xFF1A1A1A) : const Color(0xFFE5E5E5),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildWhoIsInvolved(BuildContext context, Group group) {
    final repo = CycleRepository.instance;
    final members = repo.getMembersForGroup(group.id).where((m) => !m.id.startsWith('p_')).toList();
    if (members.isEmpty) return const SizedBox.shrink();
    final allIds = members.map((m) => m.id).toSet();
    final allSelected = allIds.isNotEmpty && selectedMemberIds.containsAll(allIds);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "WHO'S INVOLVED",
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF9B9B9B),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () {
            setState(() {
              if (allSelected) {
                selectedMemberIds.removeAll(allIds);
              } else {
                selectedMemberIds.addAll(allIds);
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: Checkbox(
                    value: allSelected,
                    tristate: false,
                    onChanged: (_) {
                      setState(() {
                        if (allSelected) {
                          selectedMemberIds.removeAll(allIds);
                        } else {
                          selectedMemberIds.addAll(allIds);
                        }
                      });
                    },
                    activeColor: const Color(0xFF1A1A1A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Select All',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
          ),
        ),
        ...members.map((member) {
          final isSelected = selectedMemberIds.contains(member.id);
          final displayName = repo.getMemberDisplayNameById(member.id);
          return InkWell(
            onTap: () {
              setState(() {
                if (isSelected) {
                  selectedMemberIds.remove(member.id);
                } else {
                  selectedMemberIds.add(member.id);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: Checkbox(
                      value: isSelected,
                      onChanged: (_) {
                        setState(() {
                          if (isSelected) {
                            selectedMemberIds.remove(member.id);
                          } else {
                            selectedMemberIds.add(member.id);
                          }
                        });
                      },
                      activeColor: const Color(0xFF1A1A1A),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    displayName,
                    style: TextStyle(
                      fontSize: 17,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final group = RouteArgs.getGroup(context);
    if (group == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.of(context).maybePop());
      return const Scaffold(body: SizedBox.shrink());
    }

    if (showConfirmation && parsedData != null) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      onPressed: handleEdit,
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
                    const SizedBox(height: 20),
                    Text(
                      'Confirm Expense',
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
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '₹${parsedData!.amount.toStringAsFixed(0).replaceAllMapped(
                          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                          (Match m) => '${m[1]},',
                        )}',
                        style: TextStyle(
                          fontSize: 52,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1A1A1A),
                          letterSpacing: -1.2,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        parsedData!.description,
                        style: TextStyle(
                          fontSize: 17,
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                      if (_paidById != null && _paidById!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Paid by ${CycleRepository.instance.getMemberDisplayNameById(_paidById!)}',
                          style: TextStyle(
                            fontSize: 15,
                            color: const Color(0xFF6B6B6B),
                          ),
                        ),
                      ],
                      if (selectedMemberIds.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: selectedMemberIds.map((id) {
                            final displayName = CycleRepository.instance.getMemberDisplayNameById(id);
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE5E5E5),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                displayName,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: const Color(0xFF1A1A1A),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: const Color(0xFFE5E5E5),
                      width: 1,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    ElevatedButton(
                      onPressed: (_paidById != null &&
                              _paidById!.isNotEmpty &&
                              parsedData != null &&
                              parsedData!.amount > 0)
                          ? handleConfirm
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A1A1A),
                        disabledBackgroundColor: const Color(0xFFE5E5E5),
                        foregroundColor: Colors.white,
                        disabledForegroundColor: const Color(0xFFB0B0B0),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                        minimumSize: const Size(double.infinity, 0),
                      ),
                      child: Text('Confirm', style: AppTypography.button),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: handleEdit,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        'Edit',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF5B7C99),
                        ),
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

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  const SizedBox(height: 20),
                  Text(
                    group.name,
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
            Container(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: const Color(0xFFE5E5E5),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '₹${group.amount.toStringAsFixed(0).replaceAllMapped(
                      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                      (Match m) => '${m[1]},',
                    )}',
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1A1A1A),
                      letterSpacing: -0.9,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'pending · ${group.statusLine}',
                    style: TextStyle(
                      fontSize: 15,
                      color: const Color(0xFF6B6B6B),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NEW EXPENSE',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF9B9B9B),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    autofocus: true,
                    onChanged: (value) {
                      final group = ModalRoute.of(context)?.settings.arguments as Group?;
                      setState(() {
                        input = value;
                        if (group != null) _syncSelectedMembersFromInput(group);
                      });
                    },
                    onSubmitted: (_) => handleSubmit(),
                    decoration: InputDecoration(
                      hintText: 'e.g. Dinner 1200 with',
                      hintStyle: TextStyle(
                        color: const Color(0xFFB0B0B0),
                      ),
                      filled: true,
                      fillColor: Colors.white,
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
                        borderSide: const BorderSide(color: Color(0xFF1A1A1A)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    style: TextStyle(
                      fontSize: 17,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildWhoPaid(context, group),
                  const SizedBox(height: 24),
                  _buildWhoIsInvolved(context, group),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _canSubmit ? handleSubmit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A1A1A),
                      disabledBackgroundColor: const Color(0xFFE5E5E5),
                      foregroundColor: Colors.white,
                      disabledForegroundColor: const Color(0xFFB0B0B0),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                      minimumSize: const Size(double.infinity, 0),
                    ),
                    child: Text('Submit', style: AppTypography.button),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Text(
                'Format: Description Amount with Name, Name',
                style: TextStyle(
                  fontSize: 14,
                  color: const Color(0xFF9B9B9B),
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
