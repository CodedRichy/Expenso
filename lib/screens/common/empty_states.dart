import 'dart:io';
import 'package:flutter/material.dart';
import '../../design/colors.dart';
import '../../design/spacing.dart';
import '../../design/typography.dart';
import '../../widgets/fade_in.dart';
import '../../widgets/tap_scale.dart';

class _PulseIcon extends StatefulWidget {
  final Widget child;
  const _PulseIcon({required this.child});

  @override
  State<_PulseIcon> createState() => _PulseIconState();
}

class _PulseIconState extends State<_PulseIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: widget.child,
    );
  }
}

class EmptyStates extends StatelessWidget {
  final String
  type; // 'no-groups', 'no-expenses', 'new-cycle', 'no-expenses-new-cycle', 'zero-waste-cycle'
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 96,
                    ),
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
                              onPressed:
                                  onActionPressed ??
                                  () => Navigator.pushNamed(
                                    context,
                                    '/create-group',
                                  ),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 0),
                              ),
                              child: const Text(
                                'Create Group',
                                style: AppTypography.button,
                              ),
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
      return Scaffold(body: content);
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
                    style: context.bodyPrimary.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
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
                    style: context.bodyPrimary.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
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
      final accentColor = context.colorAccent;

      return Center(
        child: FadeIn(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PulseIcon(
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accentColor.withOpacity(0.05),
                    border: Border.all(
                      color: accentColor.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.receipt_long_outlined,
                      size: 64,
                      color: accentColor.withOpacity(0.8),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'No expenses yet',
                style: context.subheader.copyWith(
                  letterSpacing: -0.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 54),
                child: Text(
                  'The cycle is empty. Use the Magic Bar below to log your first shared expense.',
                  textAlign: TextAlign.center,
                  style: context.bodySecondary.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (type == 'zero-waste-cycle') {
      final titleColor = forDarkCard
          ? Colors.white.withOpacity(0.95)
          : Theme.of(context).colorScheme.onSurface;
      final bodyColor = forDarkCard
          ? Colors.white.withOpacity(0.75)
          : Theme.of(context).colorScheme.onSurfaceVariant;
      return FadeIn(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'No expenses yet ...',
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
