import 'package:flutter/material.dart';
import '../design/colors.dart';
import '../design/spacing.dart';
import '../widgets/skeleton_placeholders.dart';

/// Full-screen groups list skeleton with a correct header mirror.
///
/// This variant uses the `shimmer` package for the shimmer effect (kept for
/// backwards compatibility where it is referenced). The primary loading state
/// in GroupsList uses [_BoundedGroupsLoading] which uses the app's own
/// [SkeletonShimmer] — prefer that path.
///
/// Structure must mirror GroupsList exactly:
///   SafeArea(bottom:false) → Column → [header row] → ListView(cards)
///   Header: padding fromLTRB(24,16,16,32), title 120×34, avatar circle 40
///   Cards: SkeletonGroupCard × N, bottom padding 88 (FAB clearance)
class GroupListSkeleton extends StatelessWidget {
  const GroupListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark
        ? AppColorsDark.border.withValues(alpha: 0.6)
        : AppColors.border.withValues(alpha: 0.6);
    final highlightColor = isDark
        ? AppColorsDark.surfaceVariant.withValues(alpha: 0.8)
        : AppColors.surfaceVariant.withValues(alpha: 0.8);

    // Use SkeletonShimmer here (app-native, avoids shimmer package dependency)
    // so this widget produces identical output to _BoundedGroupsLoading.
    _ = baseColor;       // suppress unused warning if shimmer package removed
    _ = highlightColor;

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header (must match real GroupsList header 1:1) ───────────────
          // Real: padding fromLTRB(screenPaddingH=24, spaceXl=16, spaceXl=16, space4xl=32)
          //       title "Groups" heroTitle~34px, avatar MemberAvatar(size:40)
          SkeletonShimmer(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPaddingH, // 24
                AppSpacing.spaceXl,        // 16
                AppSpacing.spaceXl,        // 16
                AppSpacing.space4xl,       // 32
              ),
              child: const Row(
                children: [
                  Expanded(
                    child: SkeletonBox(width: 120, height: 34, borderRadius: 6),
                  ),
                  SkeletonCircle(size: 40),
                ],
              ),
            ),
          ),
          // ── Card list (FAB clearance bottom:88) ──────────────────────────
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: AppSpacing.bottomNavClearance),
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 4,
              itemBuilder: (context, index) => const SkeletonGroupCard(),
            ),
          ),
        ],
      ),
    );
  }
}
