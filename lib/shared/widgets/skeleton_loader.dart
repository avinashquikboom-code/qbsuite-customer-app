import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';

/// A shimmer/skeleton placeholder that replaces full-screen loaders.
/// Use this while async data loads — screens should render immediately
/// and show skeleton placeholders only in the data regions.
class SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final BoxShape shape;

  const SkeletonBox({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = 8,
    this.shape = BoxShape.rectangle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: AppColors.border,
            shape: shape,
            borderRadius: shape == BoxShape.circle
                ? null
                : BorderRadius.circular(borderRadius),
          ),
        )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(duration: 1200.ms, color: Colors.white.withValues(alpha: 0.6));
  }
}

/// Shimmer wrapper to animate any custom layout
class AppShimmer extends StatelessWidget {
  final Widget child;
  const AppShimmer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return child
        .animate(onPlay: (c) => c.repeat())
        .shimmer(duration: 1200.ms, color: Colors.white.withValues(alpha: 0.6));
  }
}

/// Circular skeleton for avatars and round icons
class SkeletonCircle extends StatelessWidget {
  final double size;
  const SkeletonCircle({super.key, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return SkeletonBox(
      width: size,
      height: size,
      shape: BoxShape.circle,
    );
  }
}

/// Pre-built skeleton for a list tile row (icon + two text lines)
class SkeletonListTile extends StatelessWidget {
  const SkeletonListTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          const SkeletonBox(width: 44, height: 44, borderRadius: 12),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonBox(height: 14),
                const SizedBox(height: 6),
                SkeletonBox(
                  width: MediaQuery.of(context).size.width * 0.5,
                  height: 11,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pre-built skeleton for a stat card
class SkeletonStatCard extends StatelessWidget {
  const SkeletonStatCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 36, height: 36, borderRadius: 10),
          SizedBox(height: 12),
          SkeletonBox(height: 20, width: 70),
          SizedBox(height: 6),
          SkeletonBox(height: 11),
        ],
      ),
    );
  }
}

/// Pre-built skeleton for a content card (like lead/visit/request card)
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(child: SkeletonBox(height: 16)),
              const SizedBox(width: 12),
              SkeletonBox(width: 60, height: 24, borderRadius: 12),
            ],
          ),
          const SizedBox(height: 10),
          const SkeletonBox(height: 12),
          const SizedBox(height: 6),
          SkeletonBox(
            width: MediaQuery.of(context).size.width * 0.55,
            height: 12,
          ),
        ],
      ),
    );
  }
}

/// Full list skeleton — renders [count] SkeletonCards immediately
class SkeletonList extends StatelessWidget {
  final int count;
  final EdgeInsetsGeometry padding;
  const SkeletonList({
    super.key,
    this.count = 4,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: padding,
      itemCount: count,
      itemBuilder: (context, _) => const SkeletonCard(),
    );
  }
}

/// Skeleton for attendance punch card
class SkeletonAttendanceCard extends StatelessWidget {
  const SkeletonAttendanceCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  SkeletonBox(width: 140, height: 16),
                  SizedBox(height: 6),
                  SkeletonBox(width: 100, height: 12),
                ],
              ),
              const SkeletonBox(width: 80, height: 26, borderRadius: 12),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: const [
              Expanded(
                child: SkeletonBox(height: 52, borderRadius: 14),
              ),
              SizedBox(width: 12),
              Expanded(
                child: SkeletonBox(height: 52, borderRadius: 14),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const SkeletonBox(height: 48, borderRadius: 14),
        ],
      ),
    );
  }
}

/// Skeleton for calendar weekly strip
class SkeletonCalendarStrip extends StatelessWidget {
  const SkeletonCalendarStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(
          7,
          (index) => const Column(
            children: [
              SkeletonBox(width: 28, height: 12),
              SizedBox(height: 8),
              SkeletonBox(width: 36, height: 36, borderRadius: 10),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton for notification tile
class SkeletonNotificationTile extends StatelessWidget {
  const SkeletonNotificationTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonCircle(size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Expanded(child: SkeletonBox(height: 14)),
                    SizedBox(width: 16),
                    SkeletonBox(width: 50, height: 10),
                  ],
                ),
                const SizedBox(height: 8),
                const SkeletonBox(height: 12),
                const SizedBox(height: 4),
                SkeletonBox(
                  width: MediaQuery.of(context).size.width * 0.4,
                  height: 10,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton for profile header
class SkeletonProfileCard extends StatelessWidget {
  const SkeletonProfileCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const SkeletonCircle(size: 64),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonBox(width: 160, height: 18),
                SizedBox(height: 8),
                SkeletonBox(width: 100, height: 13),
                SizedBox(height: 8),
                SkeletonBox(width: 130, height: 11),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton for bottom sheet forms or modals
class SkeletonForm extends StatelessWidget {
  final int fieldCount;
  const SkeletonForm({super.key, this.fieldCount = 4});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SkeletonBox(width: 160, height: 20),
          const SizedBox(height: 20),
          ...List.generate(
            fieldCount,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  SkeletonBox(width: 80, height: 12),
                  SizedBox(height: 8),
                  SkeletonBox(height: 48, borderRadius: 12),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const SkeletonBox(height: 48, borderRadius: 12),
        ],
      ),
    );
  }
}
