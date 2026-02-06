// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

class AppSkeleton extends StatelessWidget {
  const AppSkeleton({
    super.key,
    required this.height,
    this.width,
    this.radius = 10,
  });

  final double height;
  final double? width;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme.onSurface.withValues(alpha: 0.06);

    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class AppSkeletonListTile extends StatelessWidget {
  const AppSkeletonListTile({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          AppSkeleton(height: 18, width: 18, radius: 6),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSkeleton(height: 14, width: 170),
                SizedBox(height: 8),
                AppSkeleton(height: 12, width: 240),
              ],
            ),
          ),
          SizedBox(width: 12),
          AppSkeleton(height: 14, width: 88),
        ],
      ),
    );
  }
}
