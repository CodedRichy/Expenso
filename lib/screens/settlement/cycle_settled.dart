import 'package:flutter/material.dart';
import '../../design/colors.dart';
import '../../design/spacing.dart';
import '../../design/typography.dart';
import '../../models/models.dart';
import '../../utils/money_format.dart';
import '../../utils/route_args.dart';
import '../../widgets/fade_in.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/gradient_scaffold.dart';

class CycleSettled extends StatelessWidget {
  final Group? group;

  const CycleSettled({super.key, this.group});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final resolvedGroup = group ?? RouteArgs.getGroup(context);
    if (resolvedGroup == null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => Navigator.of(context).maybePop(),
      );
      return const GradientScaffold(body: SizedBox.shrink());
    }
    return GradientScaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPaddingH,
                AppSpacing.screenHeaderPaddingTop,
                AppSpacing.screenPaddingH,
                AppSpacing.spaceXl,
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.chevron_left, size: 24),
                    color: theme.colorScheme.onSurface,
                  ),
                  const SizedBox(width: AppSpacing.spaceMd),
                  Expanded(
                    child: Text(
                      resolvedGroup.name,
                      style: context.headingMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: FadeIn(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenPaddingH,
                      vertical: AppSpacing.space4xl,
                    ),
                    child: GlassCard(
                      width: 360,
                      borderRadius: AppSpacing.radiusLarge,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'This cycle is settled',
                            textAlign: TextAlign.center,
                            style: context.amountLG,
                          ),
                          const SizedBox(height: AppSpacing.spaceLg),
                          Semantics(
                            label:
                                '${formatMoneyFromMajor(resolvedGroup.amount, resolvedGroup.currencyCode)} settled',
                            child: Text(
                              '${formatMoneyFromMajor(resolvedGroup.amount, resolvedGroup.currencyCode)} settled',
                              textAlign: TextAlign.center,
                              style: context.bodyPrimary.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.spaceMd),
                          Text(
                            'All balances cleared. The next cycle has begun.',
                            textAlign: TextAlign.center,
                            style: context.bodySecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPaddingH,
                AppSpacing.spaceXl,
                AppSpacing.screenPaddingH,
                AppSpacing.spaceLg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                          arguments: resolvedGroup,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.buttonPaddingV,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                        ),
                        elevation: 0,
                        minimumSize: const Size(double.infinity, 0),
                      ),
                      child: const Text('Continue', style: AppTypography.button),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.spaceLg),
                  Semantics(
                    label: 'View settlement history',
                    button: true,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          '/cycle-history',
                          arguments: resolvedGroup,
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: isDark
                            ? theme.colorScheme.surfaceContainerHighest
                            : context.colorSurface,
                        foregroundColor: theme.colorScheme.onSurface,
                        side: BorderSide(color: theme.dividerColor),
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.buttonPaddingV,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                        ),
                        minimumSize: const Size(double.infinity, 0),
                      ),
                      child:
                          const Text('View History', style: AppTypography.button),
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
}
