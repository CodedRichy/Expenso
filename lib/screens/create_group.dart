import 'package:flutter/material.dart';
import '../models/models.dart';
import '../repositories/cycle_repository.dart';

class CreateGroup extends StatefulWidget {
  const CreateGroup({super.key});

  @override
  State<CreateGroup> createState() => _CreateGroupState();
}

class _CreateGroupState extends State<CreateGroup> {
  String name = '';
  String rhythm = 'weekly'; // 'weekly', 'monthly', 'trip'
  int settlementDay = 0; // 0 = Sunday for weekly, 1-28 for monthly

  String getPreviewText() {
    const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    if (rhythm == 'weekly') {
      return 'This group settles every ${days[settlementDay]}.';
    }
    if (rhythm == 'monthly') {
      final day = settlementDay + 1;
      return 'This group settles on the $day${_getOrdinalSuffix(day)} of each month.';
    }
    return 'This group settles when the trip ends.';
  }

  String _getOrdinalSuffix(int day) {
    if (day > 3 && day < 21) return 'th';
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  Future<void> handleCreate() async {
    if (name.trim().isEmpty) return;
    final repo = CycleRepository.instance;
    final newGroup = Group(
      id: 'g_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim(),
      status: 'open',
      amount: 0,
      statusLine: 'Cycle open',
      creatorId: repo.currentUserId,
    );
    try {
      await repo.addGroup(
        newGroup,
        settlementRhythm: rhythm,
        settlementDay: settlementDay,
      );
      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        '/invite-members',
        arguments: newGroup,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not create group: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    'Create Group',
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'GROUP NAME',
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
                              name = value;
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'e.g. Roommates, Trip',
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
                      ],
                    ),
                    const SizedBox(height: 32),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SETTLEMENT RHYTHM',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF9B9B9B),
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE5E5E5)),
                          ),
                          child: Column(
                            children: [
                              _buildRhythmOption('weekly', 'Weekly', true, false),
                              _buildRhythmOption('monthly', 'Monthly', false, false),
                              _buildRhythmOption('trip', 'Trip-based', false, true),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    if (rhythm != 'trip') ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rhythm == 'weekly' ? 'SETTLEMENT DAY' : 'SETTLEMENT DATE',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF9B9B9B),
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: const Color(0xFFD0D0D0)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: settlementDay,
                                isExpanded: true,
                                style: TextStyle(
                                  fontSize: 17,
                                  color: const Color(0xFF1A1A1A),
                                ),
                                items: rhythm == 'weekly'
                                    ? _buildWeeklyOptions()
                                    : _buildMonthlyOptions(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      settlementDay = value;
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                    ],
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFE5E5E5)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        getPreviewText(),
                        style: TextStyle(
                          fontSize: 15,
                          color: const Color(0xFF6B6B6B),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            Container(
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
                onPressed: name.trim().isNotEmpty ? handleCreate : null,
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
                  'Create Group',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRhythmOption(String value, String label, bool isFirst, bool isLast) {
    final isSelected = rhythm == value;
    return InkWell(
      onTap: () {
        setState(() {
          rhythm = value;
          if (value == 'weekly') {
            settlementDay = 0;
          } else if (value == 'monthly') {
            settlementDay = 0;
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            top: isFirst
                ? BorderSide.none
                : const BorderSide(color: Color(0xFFE5E5E5), width: 1),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 17,
                color: const Color(0xFF1A1A1A),
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFF1A1A1A) : const Color(0xFFD0D0D0),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF1A1A1A),
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  List<DropdownMenuItem<int>> _buildWeeklyOptions() {
    const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    return List.generate(
      days.length,
      (index) => DropdownMenuItem(
        value: index,
        child: Text(days[index]),
      ),
    );
  }

  List<DropdownMenuItem<int>> _buildMonthlyOptions() {
    return List.generate(
      28,
      (index) {
        final day = index + 1;
        return DropdownMenuItem(
          value: index,
          child: Text('$day${_getOrdinalSuffix(day)}'),
        );
      },
    );
  }
}
