import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../design/colors.dart';
import '../../design/spacing.dart';
import '../../design/typography.dart';
import '../../models/models.dart';
import '../../repositories/cycle_repository.dart';
import '../../utils/route_args.dart';
import '../../widgets/gradient_scaffold.dart';
import '../../widgets/tap_scale.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/animated_number.dart';

class ParsedExpense {
  final String description;
  final double amount;

  ParsedExpense({required this.description, required this.amount});
}

class ExpenseInput extends StatefulWidget {
  final Group? group;

  const ExpenseInput({super.key, this.group});

  @override
  State<ExpenseInput> createState() => _ExpenseInputState();
}

class _ExpenseInputState extends State<ExpenseInput> {
  String input = ''; // Store the numeric string from keypad
  String _description = '';
  String _selectedCategory = 'Food';
  ParsedExpense? parsedData;
  final Set<String> selectedMemberIds = {};
  String? _paidById;

  final List<Map<String, dynamic>> _categories = [
    {'name': 'Food', 'icon': Icons.restaurant},
    {'name': 'Transport', 'icon': Icons.directions_car},
    {'name': 'Shopping', 'icon': Icons.shopping_bag},
    {'name': 'Bills', 'icon': Icons.receipt_long},
    {'name': 'Entertainment', 'icon': Icons.confirmation_number},
    {'name': 'Health', 'icon': Icons.medical_services},
    {'name': 'Other', 'icon': Icons.more_horiz},
  ];

  @override
  void initState() {
    super.initState();
    _paidById = CycleRepository.instance.currentUserId;
  }

  void handleSubmit() {
    final amount = double.tryParse(input) ?? 0.0;
    if (amount <= 0) return;

    setState(() {
      parsedData = ParsedExpense(
        description: _description.isEmpty ? _selectedCategory : _description,
        amount: amount,
      );
      showConfirmation = true;
    });
  }

  bool showConfirmation = false;

  Future<void> handleConfirm() async {
    final payerId = _paidById ?? CycleRepository.instance.currentUserId;
    if (payerId.isEmpty) return;
    HapticFeedback.lightImpact();
    
    if (parsedData != null) {
      final group = RouteArgs.getGroup(context);
      if (group != null) {
        try {
          final repo = CycleRepository.instance;
          final List<String> participantIds = selectedMemberIds.isNotEmpty
              ? selectedMemberIds.toList()
              : repo
                    .getMembersForGroup(group.id)
                    .where((m) => !m.id.startsWith('p_'))
                    .map((m) => m.id)
                    .toList();
          
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
          if (!mounted) return;
          Navigator.pop(context);
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not save expense.')),
          );
        }
      }
    }
  }

  void handleEdit() {
    setState(() {
      showConfirmation = false;
      parsedData = null;
    });
  }

  bool get _canSubmit {
    return (double.tryParse(input) ?? 0.0) > 0;
  }

  Widget _buildWhoPaid(BuildContext context, Group group) {
    final repo = CycleRepository.instance;
    final members = repo
        .getMembersForGroup(group.id)
        .where((m) => !m.id.startsWith('p_'))
        .toList();
    if (members.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WHO PAID?',
          style: context.labelSmall.copyWith(color: context.colorTextTertiary),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: members.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final member = members[index];
              final isSelected = _paidById == member.id;
              return TapScale(
                onTap: () => setState(() => _paidById = member.id),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: isSelected ? context.colorPrimary : Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                    border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                  ),
                  child: Center(
                    child: Text(
                      repo.getMemberDisplayNameById(member.id),
                      style: context.labelLarge.copyWith(
                        color: isSelected ? Colors.white : context.colorTextPrimary,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWhoIsInvolved(BuildContext context, Group group) {
    final repo = CycleRepository.instance;
    final members = repo
        .getMembersForGroup(group.id)
        .where((m) => !m.id.startsWith('p_'))
        .toList();
    if (members.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "WHO'S INVOLVED",
          style: context.labelSmall.copyWith(color: context.colorTextTertiary),
        ),
        const SizedBox(height: 12),
        GlassCard(
          padding: EdgeInsets.zero,
          borderRadius: AppSpacing.radiusMedium,
          child: Column(
            children: members.map((member) {
              final isSelected = selectedMemberIds.contains(member.id);
              final index = members.indexOf(member);
              return TapScale(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      selectedMemberIds.remove(member.id);
                    } else {
                      selectedMemberIds.add(member.id);
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: index != members.length - 1
                          ? BorderSide(color: Colors.black.withValues(alpha: 0.04))
                          : BorderSide.none,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: isSelected ? context.colorPrimary : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSelected ? context.colorPrimary : context.colorTextTertiary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, size: 14, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        repo.getMemberDisplayNameById(member.id),
                        style: context.bodyMedium,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final group = widget.group ?? RouteArgs.getGroup(context);
    if (group == null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => Navigator.of(context).maybePop(),
      );
      return const Scaffold(body: SizedBox.shrink());
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.1),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          ),
        );
      },
      child: showConfirmation && parsedData != null
          ? KeyedSubtree(
              key: const ValueKey('confirm'),
              child: _buildConfirmScaffold(context, group),
            )
          : KeyedSubtree(
              key: const ValueKey('input'),
              child: _buildInputScaffold(context, group),
            ),
    );
  }

  Widget _buildCategoryRow() {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isSelected = _selectedCategory == cat['name'];
          return TapScale(
            onTap: () => setState(() => _selectedCategory = cat['name']),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected ? context.colorPrimary : Colors.white.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                border: Border.all(
                  color: isSelected ? context.colorPrimary : Colors.black.withValues(alpha: 0.05),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    cat['icon'],
                    size: 18,
                    color: isSelected ? Colors.white : context.colorTextSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    cat['name'],
                    style: context.labelLarge.copyWith(
                      color: isSelected ? Colors.white : context.colorTextPrimary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputScaffold(BuildContext context, Group group) {
    return GradientScaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  TapScale(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                      ),
                      child: const Icon(Icons.close, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Add Expense',
                    style: context.headingMedium.copyWith(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    // Amount Display
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          group.currencyCode == 'INR' ? '₹' : '',
                          style: context.displayLarge.copyWith(color: context.colorTextPrimary.withValues(alpha: 0.5)),
                        ),
                        const SizedBox(width: 4),
                        AnimatedNumber(
                          value: double.tryParse(input.isEmpty ? '0' : input) ?? 0.0,
                          style: context.displayLarge.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    
                    // Category Selection
                    _buildCategoryRow(),
                    const SizedBox(height: 24),
                    
                    // Description Input (Glassmorphic)
                    GlassCard(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      borderRadius: AppSpacing.radiusMedium,
                      child: TextField(
                        onChanged: (val) => _description = val,
                        decoration: InputDecoration(
                          hintText: 'Notes',
                          hintStyle: context.bodyMedium.copyWith(color: context.colorTextTertiary),
                          border: InputBorder.none,
                        ),
                        style: context.bodyLarge,
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Keypad
                    _buildKeypad(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            
            // Action Button
            Padding(
              padding: const EdgeInsets.all(24),
              child: TapScale(
                enableHaptic: true,
                onTap: _canSubmit ? handleSubmit : null,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: _canSubmit ? context.colorPrimary : context.colorTextTertiary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                  ),
                  child: Center(
                    child: Text(
                      'Next',
                      style: context.labelLarge.copyWith(
                        color: _canSubmit ? Colors.white : context.colorTextTertiary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    return Column(
      children: [
        Row(
          children: [
            _buildKey('1'),
            _buildKey('2'),
            _buildKey('3'),
          ],
        ),
        Row(
          children: [
            _buildKey('4'),
            _buildKey('5'),
            _buildKey('6'),
          ],
        ),
        Row(
          children: [
            _buildKey('7'),
            _buildKey('8'),
            _buildKey('9'),
          ],
        ),
        Row(
          children: [
            _buildKey('.'),
            _buildKey('0'),
            _buildKey('⌫', isAction: true),
          ],
        ),
      ],
    );
  }

  Widget _buildKey(String label, {bool isAction = false}) {
    return Expanded(
      child: TapScale(
        enableHaptic: true,
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() {
            if (isAction) {
              if (input.isNotEmpty) input = input.substring(0, input.length - 1);
            } else {
              if (label == '.' && input.contains('.')) return;
              if (input.length < 9) input += label;
            }
          });
        },
        child: Container(
          height: 60,
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
            border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
          ),
          child: Center(
            child: Text(
              label,
              style: context.headingLarge.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmScaffold(BuildContext context, Group group) {
    return GradientScaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  TapScale(
                    onTap: handleEdit,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
                      ),
                      child: const Icon(Icons.arrow_back, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Confirm Details',
                    style: context.headingMedium.copyWith(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  GlassCard(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AMOUNT',
                          style: context.labelSmall.copyWith(color: context.colorTextTertiary),
                        ),
                        const SizedBox(height: 8),
                        AnimatedNumber(
                          value: parsedData!.amount,
                          prefix: group.currencyCode == 'INR' ? '₹' : '',
                          style: context.displayLarge.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'DESCRIPTION',
                          style: context.labelSmall.copyWith(color: context.colorTextTertiary),
                        ),
                        const SizedBox(height: 8),
                        Text(parsedData!.description, style: context.bodyLarge),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildWhoPaid(context, group),
                  const SizedBox(height: 24),
                  _buildWhoIsInvolved(context, group),
                ],
              ),
            ),
            
            // Action Button
            Padding(
              padding: const EdgeInsets.all(24),
              child: TapScale(
                enableHaptic: true,
                onTap: handleConfirm,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: context.colorPrimary,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                  ),
                  child: Center(
                    child: Text(
                      'Add Expense',
                      style: context.labelLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
