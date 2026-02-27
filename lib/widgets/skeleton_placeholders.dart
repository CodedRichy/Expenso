import 'package:flutter/material.dart';
import '../design/colors.dart';
import '../design/spacing.dart';

class SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 4,
  });

  @override
  Widget build(BuildContext context) {
    final skeletonColor = context.colorBorder.withValues(alpha: 0.5);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: skeletonColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

class SkeletonCircle extends StatelessWidget {
  final double size;

  const SkeletonCircle({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    final skeletonColor = context.colorBorder.withValues(alpha: 0.5);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: skeletonColor,
        shape: BoxShape.circle,
      ),
    );
  }
}

class SkeletonShimmer extends StatefulWidget {
  final Widget child;

  const SkeletonShimmer({super.key, required this.child});

  @override
  State<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final highlight = isDark
        ? context.colorSurface.withValues(alpha: 0.25)
        : context.colorSurface.withValues(alpha: 0.6);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                highlight.withValues(alpha: 0.0),
                highlight,
                highlight.withValues(alpha: 0.0),
              ],
              stops: [
                _animation.value - 0.3,
                _animation.value,
                _animation.value + 0.3,
              ].map((s) => s.clamp(0.0, 1.0)).toList(),
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: widget.child,
        );
      },
    );
  }
}

/// Skeleton for a single group row — matches GroupsList row layout:
/// top border, padding 24×22, title + amount + status + chevron.
class SkeletonGroupCard extends StatelessWidget {
  const SkeletonGroupCard({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: context.colorBorder, width: 1),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 160, height: 19, borderRadius: 4),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      SkeletonBox(width: 72, height: 17, borderRadius: 4),
                      const SizedBox(width: 8),
                      SkeletonBox(width: 52, height: 15, borderRadius: 4),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SkeletonBox(width: 120, height: 15, borderRadius: 4),
                ],
              ),
            ),
            const SizedBox(width: 16),
            SkeletonBox(width: 20, height: 20, borderRadius: 4),
          ],
        ),
      ),
    );
  }
}

class SkeletonExpenseRow extends StatelessWidget {
  const SkeletonExpenseRow({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPaddingH,
          vertical: AppSpacing.spaceLg,
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: context.colorBorder, width: 1),
          ),
        ),
        child: Row(
          children: [
            const SkeletonCircle(size: 40),
            const SizedBox(width: AppSpacing.spaceLg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 140, height: 14, borderRadius: 4),
                  const SizedBox(height: 6),
                  SkeletonBox(width: 100, height: 11, borderRadius: 4),
                ],
              ),
            ),
            SkeletonBox(width: 50, height: 16, borderRadius: 4),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for UpiPaymentCard — Pay [name], amount, UPI line, button.
class SkeletonPaymentCard extends StatelessWidget {
  const SkeletonPaymentCard({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.spaceLg),
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: context.colorSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.colorBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 140, height: 19, borderRadius: 4),
                      const SizedBox(height: 2),
                      SkeletonBox(width: 90, height: 24, borderRadius: 4),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.spaceSm),
            SkeletonBox(width: 200, height: 20, borderRadius: 6),
            const SizedBox(height: AppSpacing.spaceLg),
            SkeletonBox(width: double.infinity, height: 44, borderRadius: 8),
          ],
        ),
      ),
    );
  }
}

class SkeletonList extends StatelessWidget {
  final int itemCount;
  final Widget Function(int index) itemBuilder;

  const SkeletonList({
    super.key,
    this.itemCount = 5,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(itemCount, itemBuilder),
    );
  }
}
