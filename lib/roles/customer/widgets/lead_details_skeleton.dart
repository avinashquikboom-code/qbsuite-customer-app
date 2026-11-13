import 'package:material_ui/material_ui.dart';
import 'package:quickboom_crm_customer/shared/widgets/skeleton_loader.dart';

/// Comprehensive Skeleton Loader for the Lead Details Screen:
/// Models the exact layout of:
/// - Header Card
/// - Quick Actions Row
/// - Image Banner
/// - Stage Card
/// - Communication Card
/// - Contact Info Card
/// - Activity Timeline
class LeadDetailsSkeleton extends StatelessWidget {
  const LeadDetailsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header Card Skeleton
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SkeletonBox(width: 64, height: 64, borderRadius: 14),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          SkeletonBox(width: 180, height: 18, borderRadius: 4),
                          SizedBox(height: 8),
                          SkeletonBox(width: 120, height: 14, borderRadius: 4),
                          SizedBox(height: 8),
                          SkeletonBox(width: 90, height: 20, borderRadius: 6),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 10),
                Row(
                  children: const [
                    Expanded(
                      child: SkeletonBox(
                        width: double.infinity,
                        height: 14,
                        borderRadius: 4,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: SkeletonBox(
                        width: double.infinity,
                        height: 14,
                        borderRadius: 4,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 2. Quick Actions Skeleton
          Row(
            children: const [
              Expanded(
                child: SkeletonBox(
                  width: double.infinity,
                  height: 38,
                  borderRadius: 10,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: SkeletonBox(
                  width: double.infinity,
                  height: 38,
                  borderRadius: 10,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: SkeletonBox(
                  width: double.infinity,
                  height: 38,
                  borderRadius: 10,
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: SkeletonBox(
                  width: double.infinity,
                  height: 38,
                  borderRadius: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3. Stage Card Skeleton
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonBox(width: 100, height: 16, borderRadius: 4),
                SizedBox(height: 12),
                SkeletonBox(
                  width: double.infinity,
                  height: 44,
                  borderRadius: 12,
                ),
                SizedBox(height: 10),
                SkeletonBox(
                  width: double.infinity,
                  height: 36,
                  borderRadius: 10,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4. Communication Card Skeleton
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonBox(width: 140, height: 16, borderRadius: 4),
                SizedBox(height: 12),
                SkeletonBox(
                  width: double.infinity,
                  height: 60,
                  borderRadius: 12,
                ),
                SizedBox(height: 12),
                SkeletonBox(
                  width: double.infinity,
                  height: 38,
                  borderRadius: 10,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 5. Contact Info Skeleton
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonBox(width: 130, height: 16, borderRadius: 4),
                SizedBox(height: 12),
                SkeletonBox(
                  width: double.infinity,
                  height: 24,
                  borderRadius: 6,
                ),
                SizedBox(height: 8),
                SkeletonBox(
                  width: double.infinity,
                  height: 24,
                  borderRadius: 6,
                ),
                SizedBox(height: 8),
                SkeletonBox(
                  width: double.infinity,
                  height: 24,
                  borderRadius: 6,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
