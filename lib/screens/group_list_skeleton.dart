import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../design/colors.dart';
import '../widgets/skeleton_placeholders.dart';

/// Full-screen groups list skeleton (shimmer package). Prefer _BoundedGroupsLoading
/// in GroupsList which uses the same SkeletonGroupCard and matches the app layout.
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

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 88),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 5,
        itemBuilder: (context, index) => const SkeletonGroupCard(),
      ),
    );
  }
}
