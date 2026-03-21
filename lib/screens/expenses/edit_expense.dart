import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../design/colors.dart';
import '../../design/spacing.dart';
import '../../design/typography.dart';
import '../../models/models.dart';
import '../../repositories/cycle_repository.dart';
import '../../services/connectivity_service.dart';
import '../../utils/money_format.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/gradient_scaffold.dart';
import '../../widgets/success_checkmark.dart';
import '../../widgets/tap_scale.dart';
import '../../services/locale_service.dart';

class EditExpense extends StatefulWidget {
  const EditExpense({super.key});

  @override
  State<EditExpense> createState() => _EditExpenseState();
}

class _EditExpenseState extends State<EditExpense> {
  late TextEditingController descriptionController;
  late TextEditingController amountController;
  String? _groupId;
  String? _expenseId;
  Expense? _expense;
  int _selectedTimestamp = DateTime.now().millisecondsSinceEpoch;
  String _selectedPayerId = '';
  bool _canEdit = true;
  bool _hasInitialized = false;
  bool _expenseNotFound = false;
  bool _showingSaved = false;

  String get _selectedDateDisplay {
    final expenseDate = DateTime.fromMillisecondsSinceEpoch(_selectedTimestamp);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expenseDay = DateTime(
      expenseDate.year,
      expenseDate.month,
      expenseDate.day,
    );
    final diff = today.difference(expenseDay).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final month = months[expenseDate.month - 1];
    if (expenseDate.year == now.year) return '$month ${expenseDate.day}';
    return '$month ${expenseDate.day}, ${expenseDate.year}';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.fromMillisecondsSinceEpoch(_selectedTimestamp),
      firstDate: DateTime(now.year - 1),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _selectedTimestamp = picked.millisecondsSinceEpoch;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    descriptionController = TextEditingController();
    amountController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasInitialized) return;
    _hasInitialized = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! Map<String, dynamic>) {
      setState(() => _expenseNotFound = true);
      return;
    }

    final expenseId = args['expenseId'] as String?;
    final groupId = args['groupId'] as String?;
    if (groupId == null ||
        expenseId == null ||
        expenseId.isEmpty ||
        groupId.isEmpty) {
      setState(() => _expenseNotFound = true);
      return;
    }

    final repo = CycleRepository.instance;
    final expense = repo.getExpense(groupId, expenseId);
    if (expense == null) {
      setState(() => _expenseNotFound = true);
      return;
    }

    _groupId = groupId;
    _expenseId = expenseId;
    _expense = expense;
    final parsedTimestamp = int.tryParse(expense.date);
    _selectedTimestamp =
        parsedTimestamp ?? DateTime.now().millisecondsSinceEpoch;
    _selectedPayerId = expense.paidById.isNotEmpty
        ? expense.paidById
        : repo.currentUserId;
    _canEdit = repo.canMutateExpense(groupId, expenseId, repo.currentUserId);
    descriptionController.text = expense.description;
    amountController.text = expense.amount.toStringAsFixed(0);
    setState(() {});
  }

  @override
  void dispose() {
    descriptionController.dispose();
    amountController.dispose();
    super.dispose();
  }

  Future<void> handleSave() async {
    final groupId = _groupId;
    final expenseId = _expenseId;
    if (groupId == null || expenseId == null) return;
    final desc = descriptionController.text.trim();
    final amountStr = amountController.text.trim();
    if (desc.isEmpty || amountStr.isEmpty) return;

    final repo = CycleRepository.instance;
    final existing = repo.getExpense(groupId, expenseId);
    if (existing == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Expense not found. It may have been deleted.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
      return;
    }

    final amount = double.tryParse(amountStr) ?? 0.0;
    if (amount <= 0 || amount.isNaN || amount.isInfinite) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Amount must be a valid positive number.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (ConnectivityService.instance.isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot save changes while offline'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    Map<String, double>? updatedSplits = existing.splitAmountsById;
    if (existing.splitAmountsById != null &&
        existing.splitAmountsById!.isNotEmpty &&
        amount != existing.amount) {
      final ratio = amount / existing.amount;
      updatedSplits = existing.splitAmountsById!.map(
        (k, v) => MapEntry(k, v * ratio),
      );
    }

    try {
      final updatedExpense = Expense(
        id: expenseId,
        description: desc,
        amount: amount,
        date: _selectedTimestamp.toString(),
        participantIds: existing.participantIds,
        paidById: _selectedPayerId,
        splitAmountsById: updatedSplits,
        category: existing.category,
        splitType: existing.splitType,
      );
      repo.updateExpense(groupId, updatedExpense);
      HapticFeedback.mediumImpact();
      // Flash success overlay then pop
      if (!mounted) return;
      setState(() => _showingSaved = true);
      await Future.delayed(const Duration(milliseconds: 650));
      if (!mounted) return;
      Navigator.pop(context);
    } on ArgumentError catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Invalid expense.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on StateError catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
      );
    }
  }

  void handleDelete() {
    final groupId = _groupId;
    final expenseId = _expenseId;
    if (groupId == null || expenseId == null) return;
    if (ConnectivityService.instance.isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete expense while offline'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    try {
      CycleRepository.instance.deleteExpense(groupId, expenseId);
      HapticFeedback.mediumImpact();
      Navigator.pop(context);
    } on StateError catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_expenseNotFound) {
      return _buildErrorScreen(context);
    }
    final canEdit = _canEdit;
    return Stack(
      children: [
        GradientScaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context, canEdit ? 'Edit Expense' : 'Expense'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDescriptionField(readOnly: !canEdit),
                    const SizedBox(height: 14),
                    _buildAmountField(readOnly: !canEdit),
                    if (_expense != null) ...[
                      const SizedBox(height: 14),
                      _buildDateField(canEdit),
                      const SizedBox(height: 14),
                      _buildPayerField(canEdit),
                      const SizedBox(height: 14),
                      _buildSplitAndPeopleSection(),
                    ],
                    if (canEdit) ...[
                      const SizedBox(height: 20),
                      TapScale(
                        onTap: handleDelete,
                        child: GlassCard(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          borderRadius: AppSpacing.radiusSmall,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: context.colorError,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Delete Expense',
                                style: context.labelLarge.copyWith(
                                  color: context.colorError,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            _buildSaveButton(),
          ],
        ),
      ),
        ),
        // ── Success overlay ──────────────────────────────────────────────
        if (_showingSaved)
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: _showingSaved ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                color: context.colorBackground.withValues(alpha: 0.82),
                child: Center(
                  child: SuccessCheckmark(
                    size: 88,
                    color: context.colorSuccess,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildErrorScreen(BuildContext context) {
    return GradientScaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: TapScale(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.08),
                    ),
                  ),
                  child: const Icon(Icons.chevron_left, size: 20),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 96,
                  ),
                  child: SizedBox(
                    width: 280,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: context.colorTextSecondary,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Expense not found',
                          textAlign: TextAlign.center,
                          style: context.headingMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'This expense may have been removed or the link is invalid. Go back and try again.',
                          textAlign: TextAlign.center,
                          style: context.bodyPrimary.copyWith(
                            color: context.colorTextSecondary,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 32),
                        TapScale(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: double.infinity,
                            height: 52,
                            decoration: BoxDecoration(
                              color: context.colorPrimary,
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusMedium,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'Go back',
                                style: context.labelLarge.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
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
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          TapScale(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.6),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.black.withValues(alpha: 0.08),
                ),
              ),
              child: const Icon(Icons.chevron_left, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: context.headingMedium.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionField({required bool readOnly}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('DESCRIPTION', style: context.sectionLabel),
        const SizedBox(height: 10),
        GlassCard(
          padding: EdgeInsets.zero,
          borderRadius: AppSpacing.radiusSmall,
          child: TextField(
            controller: descriptionController,
            readOnly: readOnly,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'What was this expense?',
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
            ),
            style: context.labelLarge,
          ),
        ),
      ],
    );
  }

  Widget _buildAmountField({required bool readOnly}) {
    final currencyCode = _groupId != null
        ? (CycleRepository.instance.getGroup(_groupId!)?.currencyCode ?? 'INR')
        : 'INR';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('AMOUNT', style: context.sectionLabel),
        const SizedBox(height: 10),
        GlassCard(
          padding: EdgeInsets.zero,
          borderRadius: AppSpacing.radiusSmall,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Text(
                  CurrencyRegistry.symbol(currencyCode),
                  style: context.labelLarge.copyWith(
                    color: context.colorTextSecondary,
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 24,
                color: Colors.black.withValues(alpha: 0.08),
              ),
              Expanded(
                child: TextField(
                  controller: amountController,
                  readOnly: readOnly,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    hintText: '0',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                  ),
                  style: context.labelLarge,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDateField(bool canEdit) {
    final isCustomDate = !['Today', 'Yesterday'].contains(_selectedDateDisplay);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('DATE', style: context.sectionLabel),
        const SizedBox(height: 10),
        if (canEdit)
          Row(
            children: [
              _buildDateChip('Today', canEdit),
              const SizedBox(width: 8),
              _buildDateChip('Yesterday', canEdit),
              const SizedBox(width: 8),
              TapScale(
                onTap: _pickDate,
                child: GlassCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  borderRadius: AppSpacing.radiusSmall,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: isCustomDate
                            ? context.colorPrimary
                            : context.colorTextSecondary,
                      ),
                      if (isCustomDate) ...[
                        const SizedBox(width: 6),
                        Text(
                          _selectedDateDisplay,
                          style: context.labelMedium.copyWith(
                            color: context.colorPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          )
        else
          GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            borderRadius: AppSpacing.radiusSmall,
            child: Text(
              _selectedDateDisplay,
              style: context.labelLarge,
            ),
          ),
      ],
    );
  }

  Widget _buildDateChip(String label, bool canEdit) {
    final isSelected = _selectedDateDisplay == label;
    return TapScale(
      onTap: canEdit
          ? () {
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              setState(() {
                if (label == 'Today') {
                  _selectedTimestamp = today.millisecondsSinceEpoch;
                } else if (label == 'Yesterday') {
                  _selectedTimestamp = today
                      .subtract(const Duration(days: 1))
                      .millisecondsSinceEpoch;
                }
              });
            }
          : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? context.colorPrimary
              : Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
          border: Border.all(
            color: isSelected
                ? context.colorPrimary
                : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          label,
          style: context.labelMedium.copyWith(
            color: isSelected ? Colors.white : context.colorTextPrimary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildPayerField(bool canEdit) {
    if (_groupId == null) return const SizedBox.shrink();
    final repo = CycleRepository.instance;
    final members = repo
        .getMembersForGroup(_groupId!)
        .where((m) => !m.id.startsWith('p_'))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('PAID BY', style: context.sectionLabel),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: members.map((member) {
            final isSelected = _selectedPayerId == member.id;
            final displayName = repo.getMemberDisplayNameById(member.id);
            return TapScale(
              onTap: canEdit
                  ? () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedPayerId = member.id);
                    }
                  : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? context.colorPrimary
                      : Colors.white.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                  border: Border.all(
                    color: isSelected
                        ? context.colorPrimary
                        : Colors.black.withValues(alpha: 0.08),
                  ),
                ),
                child: Text(
                  displayName,
                  style: context.labelMedium.copyWith(
                    color: isSelected ? Colors.white : context.colorTextPrimary,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSplitAndPeopleSection() {
    final expense = _expense!;
    final repo = CycleRepository.instance;
    final currencyCode = _groupId != null
        ? (repo.getGroup(_groupId!)?.currencyCode ?? 'INR')
        : 'INR';
    final locale = LocaleService.instance.localeCode;
    final isExact =
        expense.splitAmountsById != null &&
        expense.splitAmountsById!.isNotEmpty;
    final splitLabel = expense.splitType.isNotEmpty
        ? expense.splitType
        : (isExact ? 'Exact' : 'Even');
    final participants = isExact
        ? expense.splitAmountsById!.entries.toList()
        : expense.participantIds
              .map(
                (id) => MapEntry(
                  id,
                  expense.amount /
                      (expense.participantIds.isEmpty
                          ? 1
                          : expense.participantIds.length),
                ),
              )
              .toList();

    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: AppSpacing.radiusSmall,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('SPLIT', style: context.sectionLabel),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: context.colorPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  splitLabel,
                  style: context.caption.copyWith(
                    color: context.colorPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('PEOPLE INVOLVED', style: context.sectionLabel),
          const SizedBox(height: 8),
          ...participants.map((e) {
            final name = repo.getMemberDisplayNameById(e.key);
            final amt = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(name, style: context.labelMedium),
                  Text(
                    formatMoneyFromMajor(amt, currencyCode, locale),
                    style: context.labelMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    if (!_canEdit) return const SizedBox.shrink();
    final isEnabled = descriptionController.text.trim().isNotEmpty &&
        amountController.text.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: TapScale(
        onTap: isEnabled ? handleSave : null,
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            color: isEnabled
                ? context.colorPrimary
                : context.colorPrimary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            boxShadow: isEnabled
                ? [
                    BoxShadow(
                      color: context.colorPrimary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              'Save Changes',
              style: context.labelLarge.copyWith(
                color: isEnabled
                    ? Colors.white
                    : context.colorPrimary.withValues(alpha: 0.4),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
