import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../design/colors.dart';
import 'invite_members.dart';
import '../../design/spacing.dart';
import '../../design/typography.dart';
import '../../models/models.dart';
import '../../repositories/cycle_repository.dart';
import '../../services/connectivity_service.dart';
import '../../widgets/gradient_scaffold.dart';
import '../../widgets/tap_scale.dart';
import '../../widgets/glass_card.dart';

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
    const days = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ];
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
            builder: (_) =>
                InviteMembers(group: groupToPass, groupName: groupToPass.name),
          ),
        );
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not create group. Check your connection and try again.',
          ),
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
                      child: const Icon(Icons.chevron_left, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Create Group',
                    style: context.headingMedium.copyWith(fontWeight: FontWeight.w600),
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
                          style: context.labelSmall.copyWith(
                            color: context.colorTextTertiary,
                            letterSpacing: 0.5,
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
                          decoration: const InputDecoration(
                            hintText: 'e.g. Roommates, Trip',
                          ),
                          style: context.labelLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SETTLEMENT RHYTHM',
                          style: context.labelSmall.copyWith(
                            color: context.colorTextTertiary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        GlassCard(
                          padding: EdgeInsets.zero,
                          borderRadius: AppSpacing.radiusMedium,
                          child: Column(
                            children: [
                              _buildRhythmOption(
                                'weekly',
                                'Weekly',
                                true,
                                false,
                              ),
                              _buildRhythmOption(
                                'monthly',
                                'Monthly',
                                false,
                                false,
                              ),
                              _buildRhythmOption(
                                'trip',
                                'Trip-based',
                                false,
                                true,
                              ),
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
                            rhythm == 'weekly'
                                ? 'SETTLEMENT DAY'
                                : 'SETTLEMENT DATE',
                            style: context.labelSmall.copyWith(
                              color: context.colorTextTertiary,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          GlassCard(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            borderRadius: AppSpacing.radiusMedium,
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: settlementDay,
                                isExpanded: true,
                                dropdownColor: Theme.of(context).colorScheme.surface,
                                style: context.labelLarge.copyWith(
                                  color: context.colorTextPrimary,
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
                    GlassCard(
                      padding: const EdgeInsets.all(16),
                      borderRadius: AppSpacing.radiusSmall,
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: context.colorTextSecondary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              getPreviewText(),
                              style: context.labelMedium.copyWith(color: context.colorTextSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: TapScale(
                onTap: name.trim().isNotEmpty ? handleCreate : null,
                child: Container(
                  height: 54,
                  decoration: BoxDecoration(
                    color: name.trim().isNotEmpty
                        ? context.colorPrimary
                        : context.colorPrimary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                    boxShadow: name.trim().isNotEmpty
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
                      'Create Group',
                      style: context.labelLarge.copyWith(
                        color: name.trim().isNotEmpty
                            ? Colors.white
                            : context.colorPrimary.withValues(alpha: 0.4),
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

  Widget _buildRhythmOption(
    String value,
    String label,
    bool isFirst,
    bool isLast,
  ) {
    final isSelected = rhythm == value;
    return TapScale(
      scaleDown: 0.99,
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
                : BorderSide(color: Colors.black.withValues(alpha: 0.06), width: 1),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: context.labelLarge.copyWith(color: context.colorTextPrimary),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? context.colorPrimary
                      : context.colorBorderInput,
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
    const days = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ];
    return List.generate(
      days.length,
      (index) => DropdownMenuItem(value: index, child: Text(days[index])),
    );
  }

  List<DropdownMenuItem<int>> _buildMonthlyOptions() {
    return List.generate(28, (index) {
      final day = index + 1;
      return DropdownMenuItem(
        value: index,
        child: Text('$day${_getOrdinalSuffix(day)}'),
      );
    });
  }
}
