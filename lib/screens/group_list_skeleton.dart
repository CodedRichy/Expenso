import 'package:flutter/material.dart';
import '../design/spacing.dart';
import '../widgets/skeleton_placeholders.dart';

/// Full-screen groups list skeleton. Structurally mirrors GroupsList:
///
///   SafeArea(bottom:false)
///   └── Column
///       ├── Header row  ← SkeletonShimmer [ title 120×34  |  avatar circle 40 ]
///       └── Expanded
///           └── ListView (physics: NeverScrollable, bottom: 88)
///               ├── SkeletonGroupCard
///               └── ... × 4
///
/// Must be kept in sync with the real GroupsList header layout. Any change to
/// the real header padding or avatar size must be reflected here.
class GroupListSkeleton extends StatelessWidget {
  const GroupListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header (matches real GroupsList header 1:1) ──────────────────
          // Real: padding fromLTRB(24, 16, 16, 32),
          //       "Groups" heroTitle fontSize:34, MemberAvatar(size:40)
          SkeletonShimmer(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.screenPaddingH, // 24
                AppSpacing.spaceXl,        // 16
                AppSpacing.spaceXl,        // 16
                AppSpacing.space4xl,       // 32
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SkeletonBox(width: 120, height: 34, borderRadius: 6),
                  ),
                  SkeletonCircle(size: 40),
                ],
              ),
            ),
          ),
          // ── Card list ────────────────────────────────────────────────────
          Expanded(
            child: _SkeletonCardList(),
          ),
        ],
      ),
    );
  }
}

class _SkeletonCardList extends StatelessWidget {
  const _SkeletonCardList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: AppSpacing.bottomNavClearance),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      itemBuilder: (context, index) => const SkeletonGroupCard(),
    );
  }
}
