import 'package:flutter/material.dart';
import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../models/models.dart';
import '../utils/money_format.dart';
import '../services/locale_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/tap_scale.dart';

class CycleSettledSheet extends StatelessWidget {
  final Group group;

  const CycleSettledSheet({
    super.key,
    required this.group,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      decoration: BoxDecoration(
        color: context.colorSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 12,
        bottom: 24 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: context.colorBorder.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
          const SizedBox(height: 32),
          
          // Success Icon with Glow
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: context.colorPrimary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: context.colorPrimary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: context.colorPrimary,
                    size: 40,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          Text(
            'Cycle Settled',
            textAlign: TextAlign.center,
            style: context.subheader.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          
          Text(
            '${formatMoneyFromMajor(group.amount, group.currencyCode, LocaleService.instance.localeCode)} settled',
            textAlign: TextAlign.center,
            style: context.amountSM.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'All balances have been cleared for "${group.name}". The next cycle has begun.',
              textAlign: TextAlign.center,
              style: context.bodySecondary.copyWith(height: 1.5),
            ),
          ),
          const SizedBox(height: 32),
          
          TapScale(
            onTap: () {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/group-detail',
                (route) => route.isFirst,
                arguments: group,
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: context.colorPrimary,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: context.colorPrimary.withValues(alpha: 0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  'Continue to Group',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          TapScale(
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(
                context,
                '/cycle-history',
                arguments: group,
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(color: context.colorBorder),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  'View History',
                  style: context.labelLarge.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> show(BuildContext context, {required Group group}) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => CycleSettledSheet(group: group),
    );
  }
}
