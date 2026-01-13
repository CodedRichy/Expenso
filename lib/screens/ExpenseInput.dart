import 'package:flutter/material.dart';
import '../models/models.dart';

class ParsedExpense {
  final String description;
  final double amount;
  final List<String> participants;

  ParsedExpense({
    required this.description,
    required this.amount,
    required this.participants,
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

  ParsedExpense parseExpense(String text) {
    // Simple parser for demonstration
    // Example: "Dinner 1200 with Arjun, Amal"
    final amountMatch = RegExp(r'\d+').firstMatch(text);
    final amount = amountMatch != null ? double.parse(amountMatch.group(0)!) : 0.0;

    final withIndex = text.toLowerCase().indexOf('with');
    final description = withIndex > 0
        ? text.substring(0, withIndex).replaceAll(RegExp(r'\d+'), '').trim()
        : text.replaceAll(RegExp(r'\d+'), '').trim();

    final participants = withIndex > 0
        ? text.substring(withIndex + 4).split(',').map((p) => p.trim()).where((p) => p.isNotEmpty).toList()
        : <String>[];

    return ParsedExpense(
      description: description,
      amount: amount,
      participants: participants,
    );
  }

  void handleSubmit() {
    if (input.trim().isNotEmpty) {
      final parsed = parseExpense(input);
      setState(() {
        parsedData = parsed;
        showConfirmation = true;
      });
    }
  }

  void handleConfirm() {
    // Handle expense submission
    setState(() {
      input = '';
      parsedData = null;
      showConfirmation = false;
    });
    Navigator.pop(context);
  }

  void handleEdit() {
    setState(() {
      showConfirmation = false;
      parsedData = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final defaultGroup = widget.group ??
        Group(
          id: '1',
          name: 'Weekend Trip',
          status: 'open',
          amount: 3240,
          statusLine: 'Cycle closes Sunday',
        );

    if (showConfirmation && parsedData != null) {
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
              // Confirmation Content
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
                      if (parsedData!.participants.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: parsedData!.participants.map((participant) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE5E5E5),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                participant,
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
              // Actions
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
                      onPressed: handleConfirm,
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
            // Header
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
                    '₹${defaultGroup.amount.toStringAsFixed(0).replaceAllMapped(
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
                    'pending · ${defaultGroup.statusLine}',
                    style: TextStyle(
                      fontSize: 15,
                      color: const Color(0xFF6B6B6B),
                    ),
                  ),
                ],
              ),
            ),
            // Input Section
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
                      setState(() {
                        input = value;
                      });
                    },
                    onSubmitted: (_) => handleSubmit(),
                    decoration: InputDecoration(
                      hintText: 'Dinner 1200 with Arjun, Amal',
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
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: input.trim().isNotEmpty ? handleSubmit : null,
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
            // Help Text
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
