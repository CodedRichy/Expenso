import 'package:flutter/material.dart';
import '../design/colors.dart';
import '../design/spacing.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Primitive skeleton atoms
// ─────────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────
// Shimmer animation wrapper
// ─────────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────
// SkeletonGroupCard
//
// Mirrors a single group row in GroupsList:
//   top border (1px), padding h:24 v:22
//   left col: title (160×19) + [amount (72×17) + badge (52×15)] + sub (120×15)
//   right: chevron placeholder (20×20)
//
// Do NOT change these measurements without updating the real row too.
// ─────────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────
// SkeletonExpenseRow
//
// Mirrors a single expense row in GroupDetail:
//   Real row: padding h:24 v:14, top border on index>0 (→ use top border on
//   all skeleton rows to be conservative), NO leading icon, two text lines.
//
//   Layout:
//     left col: description (140×17) + SizedBox(2) + date (100×14)
//     right: amount (64×17)
//
// The previous version had a 40px circle (wrong — no icon in real rows),
// v-padding of 12 (wrong — real uses 14), and a bottom border (wrong — real
// uses top border). All three are fixed here.
// ─────────────────────────────────────────────────────────────────────────────

class SkeletonExpenseRow extends StatelessWidget {
  /// Show the top border separator. Pass false for the very first row since
  /// the real list omits the top border on index == 0.
  final bool showTopBorder;

  const SkeletonExpenseRow({super.key, this.showTopBorder = true});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Container(
        // v:14 matches real expense row (horizontal: 24, vertical: 14)
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPaddingH,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          border: Border(
            top: showTopBorder
                ? BorderSide(color: context.colorBorder, width: 1)
                : BorderSide.none,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: description + date — no leading icon (real row has none)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // fontSize:17 in real row → height 17+padding = ~17px block
                  SkeletonBox(width: 140, height: 17, borderRadius: 4),
                  const SizedBox(height: 2),
                  // fontSize:14 date line
                  SkeletonBox(width: 100, height: 14, borderRadius: 4),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Right: amount, fontSize:17 w600
            SkeletonBox(width: 64, height: 17, borderRadius: 4),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SkeletonExpenseList
//
// Viewport-filling expense list skeleton. Uses LayoutBuilder to compute how
// many rows fit in the available height, then renders that many + 1 (overshoot
// by 1 so the last row is never missing). This prevents the "last row pop-in"
// when real data arrives and fills space that was blank in the skeleton.
//
// Usage (inside an Expanded or SizedBox with a fixed height):
//   SkeletonExpenseList()
// ─────────────────────────────────────────────────────────────────────────────

class SkeletonExpenseList extends StatelessWidget {
  const SkeletonExpenseList({super.key});

  // Single row height: v-padding 14*2 + content max(17,14+2+14)=17 → 14+14+17 = 45px
  // Use 45 as the row height estimate for the count calculation.
  static const double _rowHeight = 45.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height;
        // Overshoot by 1 so there is never visible blank space below the last row.
        final count = (availableHeight / _rowHeight).ceil() + 1;
        return ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: count,
          itemBuilder: (context, index) =>
              SkeletonExpenseRow(showTopBorder: index > 0),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SkeletonPaymentCard
//
// Mirrors UpiPaymentCard: card border radius 12, border all, padding cardPadding,
// margin bottom spaceLg.
//   title row: 140×19 + 90×24 (name + amount)
//   UPI ID badge: 200×20
//   button: full-width 44px
// ─────────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────
// SkeletonList — generic, fixed-count skeleton list
// ─────────────────────────────────────────────────────────────────────────────

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
