import 'package:flutter/material.dart';
import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../utils/money_format.dart';
import '../utils/route_args.dart';
import '../widgets/fade_in.dart';

class CycleSettled extends StatelessWidget {
  const CycleSettled({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final group = RouteArgs.getGroup(context);
    if (group == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => Navigator.of(context).maybePop());
      return const Scaffold(body: SizedBox.shrink());
    }
    return Scaffold(
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
                  IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.chevron_left, size: 24),
                    color: theme.colorScheme.onSurface,
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
                    style: context.screenTitle,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: FadeIn(
                  child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 96),
                  child: SizedBox(
                    width: 320,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'This cycle is settled',
                          textAlign: TextAlign.center,
                          style: context.amountLG,
                        ),
                        const SizedBox(height: 12),
                        Semantics(
                          label: '${formatMoneyFromMajor(group.amount, group.currencyCode)} settled',
                          child: Text(
                            '${formatMoneyFromMajor(group.amount, group.currencyCode)} settled',
                            textAlign: TextAlign.center,
                            style: context.bodyPrimary.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'All balances cleared. The next cycle has begun.',
                          textAlign: TextAlign.center,
                          style: context.bodySecondary,
                        ),
                        const SizedBox(height: 48),
                        Column(
                          children: [
                            Semantics(
                              label: 'Continue to group',
                              button: true,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.pushNamedAndRemoveUntil(
                                    context,
                                    '/group-detail',
                                    (route) => route.isFirst,
                                    arguments: group,
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 0,
                                  minimumSize: const Size(double.infinity, 0),
                                ),
                                child: Text(
                                  'Continue',
                                  style: AppTypography.button,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Semantics(
                              label: 'View settlement history',
                              button: true,
                              child: OutlinedButton(
                                onPressed: () {
                                  Navigator.pushNamed(context, '/cycle-history', arguments: group);
                                },
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: isDark ? theme.colorScheme.surfaceContainerHighest : context.colorSurface,
                                  foregroundColor: theme.colorScheme.onSurface,
                                  side: BorderSide(color: theme.dividerColor),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  minimumSize: const Size(double.infinity, 0),
                                ),
                                child: Text(
                                  'View History',
                                  style: AppTypography.button,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
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