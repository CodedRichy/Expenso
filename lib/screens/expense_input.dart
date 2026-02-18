import 'package:flutter/material.dart';
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
  final Set<String> selectedMemberPhones = {};
  String? _paidByPhone;

  @override
  void initState() {
    super.initState();
    _paidByPhone = CycleRepository.instance.currentUserPhone;
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
    if (parsed.amount <= 0) return;
    setState(() {
      parsedData = parsed;
      showConfirmation = true;
    });
  }

  Future<void> handleConfirm() async {
    final payerPhone = _paidByPhone ?? CycleRepository.instance.currentUserPhone;
    if (payerPhone.isEmpty) return;
    if (parsedData != null) {
      final group = ModalRoute.of(context)?.settings.arguments as Group?;
      if (group != null) {
        try {
          final expense = Expense(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            description: parsedData!.description,
            amount: parsedData!.amount,
            date: 'Today',
            participantPhones: selectedMemberPhones.toList(),
            paidByPhone: payerPhone,
          );
          await CycleRepository.instance.addExpense(group.id, expense);
          if (!context.mounted) return;
          setState(() {
            input = '';
            parsedData = null;
            showConfirmation = false;
            selectedMemberPhones.clear();
            _paidByPhone = CycleRepository.instance.currentUserPhone;
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
      selectedMemberPhones.clear();
      _paidByPhone = CycleRepository.instance.currentUserPhone;
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
    return parseExpense(input).amount > 0;
  }

  /// As user types, if any word in the input matches a member's display name, auto-add that member to Who's Involved.
  void _syncSelectedMembersFromInput(Group group) {
    final repo = CycleRepository.instance;
    final members = repo.getMembersForGroup(group.id);
    if (members.isEmpty) return;
    final words = input
        .split(RegExp(r'[\s,]+'))
        .map((s) => s.trim().toLowerCase())
        .where((s) => s.isNotEmpty)
        .toSet();
    for (final member in members) {
      final displayName = repo.getMemberDisplayName(member.phone);
      if (displayName.isEmpty) continue;
      final nameLower = displayName.trim().toLowerCase();
      final matches = words.contains(nameLower) || input.toLowerCase().contains(nameLower);
      if (matches) {
        selectedMemberPhones.add(member.phone);
      }
    }
  }

  Widget _buildWhoPaid(BuildContext context, Group group) {
    final repo = CycleRepository.instance;
    final members = repo.getMembersForGroup(group.id);
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
            final isSelected = _paidByPhone == member.phone;
            final displayName = repo.getMemberDisplayName(member.phone);
            return ChoiceChip(
              label: Text(displayName),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) setState(() => _paidByPhone = member.phone);
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
    final members = repo.getMembersForGroup(group.id);
    if (members.isEmpty) return const SizedBox.shrink();
    final allPhones = members.map((m) => m.phone).toSet();
    final allSelected = allPhones.isNotEmpty && selectedMemberPhones.containsAll(allPhones);
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
                selectedMemberPhones.removeAll(allPhones);
              } else {
                selectedMemberPhones.addAll(allPhones);
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
                          selectedMemberPhones.removeAll(allPhones);
                        } else {
                          selectedMemberPhones.addAll(allPhones);
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
          final isSelected = selectedMemberPhones.contains(member.phone);
          final displayName = repo.getMemberDisplayName(member.phone);
          return InkWell(
            onTap: () {
              setState(() {
                if (isSelected) {
                  selectedMemberPhones.remove(member.phone);
                } else {
                  selectedMemberPhones.add(member.phone);
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
                            selectedMemberPhones.remove(member.phone);
                          } else {
                            selectedMemberPhones.add(member.phone);
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
        backgroundColor: const Color(0xFFF7F7F8),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
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
                      if (_paidByPhone != null && _paidByPhone!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Paid by ${CycleRepository.instance.getMemberDisplayName(_paidByPhone!)}',
                          style: TextStyle(
                            fontSize: 15,
                            color: const Color(0xFF6B6B6B),
                          ),
                        ),
                      ],
                      if (selectedMemberPhones.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: selectedMemberPhones.map((phone) {
                            final displayName = CycleRepository.instance.getMemberDisplayName(phone);
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
                      onPressed: (_paidByPhone != null &&
                              _paidByPhone!.isNotEmpty &&
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
                      child: Text(
                        'Confirm',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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
      backgroundColor: const Color(0xFFF7F7F8),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
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
                    child: Text(
                      'Submit',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
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
