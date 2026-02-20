import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../repositories/cycle_repository.dart';

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
  String _selectedDate = 'Today';
  String _selectedPayerPhone = '';
  bool _canEdit = true;
  bool _hasInitialized = false;
  bool _expenseNotFound = false;

  static const List<String> _dateOptions = ['Today', 'Yesterday'];

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
    if (groupId == null || expenseId == null || expenseId.isEmpty || groupId.isEmpty) {
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
    _selectedDate = expense.date;
    _selectedPayerPhone = expense.paidByPhone.isNotEmpty ? expense.paidByPhone : repo.currentUserPhone;
    _canEdit = repo.canEditCycle(groupId, repo.currentUserId);
    descriptionController.text = expense.description;
    amountController.text = expense.amount.toStringAsFixed(0);
    setState(() {});
  }

  void _pickPayer() {
    if (_groupId == null) return;
    final repo = CycleRepository.instance;
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
            ...repo.getMembersForGroup(_groupId!).map((m) {
              final displayName = repo.getMemberDisplayName(m.phone);
              return ListTile(
                title: Text(displayName),
                onTap: () {
                  setState(() => _selectedPayerPhone = m.phone);
                  Navigator.pop(ctx);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    descriptionController.dispose();
    amountController.dispose();
    super.dispose();
  }

  void handleSave() {
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
    try {
      final updatedExpense = Expense(
        id: expenseId,
        description: desc,
        amount: amount,
        date: _selectedDate,
        participantPhones: existing.participantPhones,
        paidByPhone: _selectedPayerPhone,
        splitAmountsByPhone: existing.splitAmountsByPhone,
        category: existing.category,
        splitType: existing.splitType,
      );
      repo.updateExpense(groupId, updatedExpense);
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

  void handleDelete() {
    final groupId = _groupId;
    final expenseId = _expenseId;
    if (groupId != null && expenseId != null) {
      CycleRepository.instance.deleteExpense(groupId, expenseId);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_expenseNotFound) {
      return _buildErrorScreen(context);
    }
    final canEdit = _canEdit;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context, canEdit ? 'Edit Expense' : 'Expense'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDescriptionField(readOnly: !canEdit),
                    const SizedBox(height: 24),
                    _buildAmountField(readOnly: !canEdit),
                    if (_expense != null) ...[
                      const SizedBox(height: 24),
                      _buildDateField(canEdit),
                      const SizedBox(height: 24),
                      _buildPayerField(canEdit),
                      const SizedBox(height: 24),
                      _buildSplitAndPeopleSection(),
                    ],
                    if (canEdit) ...[
                      const SizedBox(height: 32),
                      OutlinedButton.icon(
                        onPressed: handleDelete,
                        icon: const Icon(Icons.delete_outline, size: 20),
                        label: const Text('Delete Expense'),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF6B6B6B),
                          side: const BorderSide(color: Color(0xFFE5E5E5)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          minimumSize: const Size(double.infinity, 0),
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
    );
  }

  Widget _buildErrorScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
              child: IconButton(
                onPressed: () => Navigator.pop(context),
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
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 96),
                  child: SizedBox(
                    width: 280,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: const Color(0xFF9B9B9B),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Expense not found',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'This expense may have been removed or the link is invalid. Go back and try again.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: const Color(0xFF6B6B6B),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1A1A1A),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                            ),
                            child: const Text('Go back'),
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
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
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
            title,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1A1A1A),
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionField({required bool readOnly}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DESCRIPTION',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF9B9B9B),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: descriptionController,
          readOnly: readOnly,
          decoration: InputDecoration(
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
      ],
    );
  }

  Widget _buildAmountField({required bool readOnly}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AMOUNT',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF9B9B9B),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE5E5E5)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '₹',
                style: TextStyle(
                  fontSize: 17,
                  color: const Color(0xFF6B6B6B),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: amountController,
                readOnly: readOnly,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(
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
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDateField(bool canEdit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DATE',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF9B9B9B),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 12),
        if (canEdit)
          DropdownButtonFormField<String>(
            value: _selectedDate.isEmpty ? 'Today' : _selectedDate,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFD0D0D0)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
            items: [
              ..._dateOptions.map((d) => DropdownMenuItem(value: d, child: Text(d))),
              if (!_dateOptions.contains(_selectedDate) && _selectedDate.isNotEmpty)
                DropdownMenuItem(value: _selectedDate, child: Text(_selectedDate)),
            ],
            onChanged: (v) => setState(() => _selectedDate = v ?? 'Today'),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE5E5E5)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _selectedDate,
              style: TextStyle(fontSize: 17, color: const Color(0xFF1A1A1A)),
            ),
          ),
      ],
    );
  }

  Widget _buildPayerField(bool canEdit) {
    final repo = CycleRepository.instance;
    final displayName = repo.getMemberDisplayName(_selectedPayerPhone);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PAID BY',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF9B9B9B),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 12),
        if (canEdit)
          InkWell(
            onTap: _pickPayer,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFD0D0D0)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Text(
                    displayName,
                    style: TextStyle(fontSize: 17, color: const Color(0xFF1A1A1A)),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_drop_down, color: const Color(0xFF6B6B6B)),
                ],
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE5E5E5)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              displayName,
              style: TextStyle(fontSize: 17, color: const Color(0xFF1A1A1A)),
            ),
          ),
      ],
    );
  }

  Widget _buildSplitAndPeopleSection() {
    final expense = _expense!;
    final repo = CycleRepository.instance;
    final isExact = expense.splitAmountsByPhone != null && expense.splitAmountsByPhone!.isNotEmpty;
    final splitLabel = expense.splitType.isNotEmpty ? expense.splitType : (isExact ? 'Exact' : 'Even');
    final participants = isExact
        ? expense.splitAmountsByPhone!.entries.toList()
        : expense.participantPhones.map((p) => MapEntry(p, expense.amount / (expense.participantPhones.isEmpty ? 1 : expense.participantPhones.length))).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SPLIT',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF9B9B9B),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          splitLabel,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: const Color(0xFF1A1A1A)),
        ),
        const SizedBox(height: 12),
        Text(
          'PEOPLE INVOLVED',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF9B9B9B),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        ...participants.map((e) {
          final name = repo.getMemberDisplayName(e.key);
          final amt = e.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  name,
                  style: TextStyle(fontSize: 15, color: const Color(0xFF1A1A1A)),
                ),
                Text(
                  '₹${amt.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: const Color(0xFF1A1A1A)),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSaveButton() {
    if (!_canEdit) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: const Color(0xFFE5E5E5),
            width: 1,
          ),
        ),
      ),
      child: ElevatedButton(
        onPressed: descriptionController.text.trim().isNotEmpty && amountController.text.isNotEmpty
            ? handleSave
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1A1A1A),
          disabledBackgroundColor: const Color(0xFFE5E5E5),
          foregroundColor: Colors.white,
          disabledForegroundColor: const Color(0xFFB0B0B0),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 0,
        ),
        child: Text(
          'Save Changes',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
