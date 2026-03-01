import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../design/colors.dart';
import 'invite_members.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../models/models.dart';
import '../repositories/cycle_repository.dart';
import '../services/connectivity_service.dart';
import '../widgets/gradient_scaffold.dart';

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
    HapticFeedback.lightImpact();
    if (ConnectivityService.instance.isOffline) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot create group while offline'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final repo = CycleRepository.instance;
    final newGroup = Group(
      id: 'g_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim(),
      status: 'open',
      amount: 0,
      statusLine: 'Cycle open',
      creatorId: repo.currentUserId,
      currencyCode: repo.currentUserCurrencyCode,
    );
    try {
      await repo.addGroup(
        newGroup,
        settlementRhythm: rhythm,
        settlementDay: settlementDay,
      );
      if (!mounted) return;
      final groupToPass = newGroup;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => InviteMembers(group: groupToPass, groupName: groupToPass.name),
          ),
        );
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not create group. Check your connection and try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.screenPaddingH,
                AppSpacing.screenHeaderPaddingTop,
                AppSpacing.screenPaddingH,
                AppSpacing.space3xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    label: 'Back',
                    button: true,
                    child: TapScale(
                      child: IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.chevron_left, size: 24),
                      color: context.colorTextPrimary,
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                      constraints: const BoxConstraints(),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(32, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Create Group', style: context.screenTitle),
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
                        Text('GROUP NAME', style: context.sectionLabel),
                        const SizedBox(height: 12),
                        TextField(
                          autofocus: true,
                          onChanged: (value) {
                            setState(() {
                              name = value;
                            });
                          },
                          decoration: const InputDecoration(
                            hintText: 'e.g. Roommates, Trip',
                          ),
                          style: context.input,
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SETTLEMENT RHYTHM',
                          style: context.sectionLabel.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: context.colorSurface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: context.colorBorder),
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
                            style: context.sectionLabel.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            decoration: BoxDecoration(
                              color: context.colorSurface,
                              border: Border.all(color: context.colorBorderInput),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: settlementDay,
                                isExpanded: true,
                                style: context.input.copyWith(
                                  color: Theme.of(context).colorScheme.onSurface,
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
                        color: context.colorSurface,
                        border: Border.all(color: context.colorBorder),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(getPreviewText(), style: context.bodySecondary),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: context.colorBorder, width: 1)),
              ),
              child: Semantics(
                label: 'Create group',
                button: true,
                child: TapScale(
                  child: ElevatedButton(
                    onPressed: name.trim().isNotEmpty ? handleCreate : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                      minimumSize: const Size(double.infinity, 0),
                    ),
                    child: const Text('Create Group', style: AppTypography.button),
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
    return TapScale(
      scaleDown: 0.99,
      child: InkWell(
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
                  : BorderSide(color: context.colorBorder, width: 1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: context.bodyPrimary.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? context.colorPrimary : context.colorBorderInput,
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
                            color: context.colorPrimary,
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
