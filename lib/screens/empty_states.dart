import 'package:flutter/material.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../widgets/fade_in.dart';
import '../widgets/tap_scale.dart';

class EmptyStates extends StatelessWidget {
  final String type; // 'no-groups', 'no-expenses', 'new-cycle', 'no-expenses-new-cycle', 'zero-waste-cycle'
  final VoidCallback? onActionPressed;
  final bool wrapInScaffold;
  final bool forDarkCard;

  const EmptyStates({
    super.key,
    this.type = 'no-groups',
    this.onActionPressed,
    this.wrapInScaffold = true,
    this.forDarkCard = false,
  });

  @override
  Widget build(BuildContext context) {
    if (type == 'no-groups') {
      final Widget content = SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (wrapInScaffold) ...[
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.screenPaddingH,
                  AppSpacing.spaceXl,
                  AppSpacing.screenPaddingH,
                  AppSpacing.space4xl,
                ),
                child: Text('Groups', style: context.heroTitle),
              ),
            ],
            Expanded(
              child: Center(
                child: FadeIn(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 96),
                    child: SizedBox(
                      width: 280,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'No groups yet',
                          textAlign: TextAlign.center,
                          style: context.listItemTitle,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Create a group to start tracking shared expenses with automatic settlement cycles.',
                          textAlign: TextAlign.center,
                          style: context.bodySecondary,
                        ),
                        const SizedBox(height: 32),
                        TapScale(
                          child: ElevatedButton(
                            onPressed: onActionPressed ?? () => Navigator.pushNamed(context, '/create-group'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 0),
                            ),
                            child: const Text('Create Group', style: AppTypography.button),
                          ),
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
      );
      if (!wrapInScaffold) return content;
      return Scaffold(
        body: content,
      );
    }

    if (type == 'no-expenses') {
      return Center(
          child: FadeIn(
            child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
            child: SizedBox(
              width: 280,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'No expenses yet',
                    textAlign: TextAlign.center,
                    style: context.bodyPrimary.copyWith(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add expenses as they occur. The group will settle at the end of the cycle.',
                    textAlign: TextAlign.center,
                    style: context.bodySecondary,
                  ),
                ],
              ),
            ),
            ),
          ),
        );
    }

    if (type == 'new-cycle') {
      return Center(
          child: FadeIn(
            child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
            child: SizedBox(
              width: 280,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'New cycle started',
                    textAlign: TextAlign.center,
                    style: context.bodyPrimary.copyWith(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Previous cycle is settled. Add new expenses for this cycle.',
                    textAlign: TextAlign.center,
                    style: context.bodySecondary,
                  ),
                ],
              ),
            ),
            ),
          ),
        );
    }

    if (type == 'no-expenses-new-cycle') {
      return Center(
          child: FadeIn(
            child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
            child: SizedBox(
              width: 280,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'No expenses yet',
                    textAlign: TextAlign.center,
                    style: context.bodyPrimary.copyWith(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the button below to start the cycle!',
                    textAlign: TextAlign.center,
                    style: context.bodySecondary,
                  ),
                ],
              ),
            ),
            ),
          ),
        );
    }

    if (type == 'zero-waste-cycle') {
      final titleColor = forDarkCard 
          ? Colors.white.withValues(alpha: 0.95) 
          : Theme.of(context).colorScheme.onSurface;
      final bodyColor = forDarkCard 
          ? Colors.white.withValues(alpha: 0.75) 
          : Theme.of(context).colorScheme.onSurfaceVariant;
      return FadeIn(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Zero-Waste Cycle',
              style: context.subheader.copyWith(color: titleColor),
            ),
            const SizedBox(height: 8),
            Text(
              'Add expenses with the Magic Bar below or tap the keyboard for manual entry.',
              style: context.caption.copyWith(color: bodyColor, height: 1.35),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
