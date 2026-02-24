import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class GroupListSkeleton extends StatelessWidget {
  const GroupListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E5E5);
    final highlightColor = isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF0F0F0);
    final borderColor = isDark ? const Color(0xFF3A3A3A) : const Color(0xFFE5E5E5);
    final placeholderColor = isDark ? const Color(0xFF3A3A3A) : Colors.white;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 88),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 5,
        itemBuilder: (context, index) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: borderColor,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 19,
                        width: 160,
                        decoration: BoxDecoration(
                          color: placeholderColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            height: 17,
                            width: 72,
                            decoration: BoxDecoration(
                              color: placeholderColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            height: 15,
                            width: 52,
                            decoration: BoxDecoration(
                              color: placeholderColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 15,
                        width: 120,
                        decoration: BoxDecoration(
                          color: placeholderColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  height: 20,
                  width: 20,
                  decoration: BoxDecoration(
                    color: placeholderColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
