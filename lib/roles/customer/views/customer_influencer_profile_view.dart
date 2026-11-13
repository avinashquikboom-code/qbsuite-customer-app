import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/permission_manager.dart';
import '../models/influencer_model.dart';
import 'customer_influencer_packages_view.dart';

/// Screen 2 — Customer Influencer Profile Page
/// Visual source of truth: Screen 2 of reference_screens.jpeg
class CustomerInfluencerProfileView extends ConsumerWidget {
  final InfluencerModel creator;
  final String? heroTag;

  const CustomerInfluencerProfileView({
    super.key,
    required this.creator,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Scrollable Profile Details
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cover Image with overlapping avatar & back button
                    _buildCoverAndAvatar(context),

                    const SizedBox(height: 12),

                    // Influencer Identity & Badges
                    _buildIdentitySection(),

                    const SizedBox(height: 16),

                    // 3 Metric Stat Boxes
                    _buildMetricBoxes(),

                    const SizedBox(height: 16),

                    // Bio Text
                    if (creator.bio != null &&
                        creator.bio!.trim().isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          creator.bio!.trim(),
                          style: GoogleFonts.outfit(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Previous Brand Collaborations
                    _buildBrandCollaborations(),

                    // Recent Content Gallery
                    _buildRecentContent(),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),

            // Bottom Sticky Action Bar: Chat + Book Now
            _buildBottomActionBar(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverAndAvatar(BuildContext context) {
    final String coverUrl =
        (creator.profileImage != null &&
            creator.profileImage!.trim().isNotEmpty)
        ? creator.profileImage!.trim()
        : (creator.effectiveImageUrl.isNotEmpty
              ? creator.effectiveImageUrl
              : '');
    final String avatarUrl = creator.effectiveImageUrl;
    final String? effectiveHeroTag =
        heroTag ?? (creator.id > 0 ? 'influencer_${creator.id}' : null);

    final Widget coverImage = Container(
      height: 180,
      width: double.infinity,
      foregroundDecoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withValues(alpha: 0.35), Colors.transparent],
        ),
      ),
      child: coverUrl.isNotEmpty
          ? Image.network(
              coverUrl,
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, st) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF334155)],
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Remix.image_line,
                    color: Color(0xFF94A3B8),
                    size: 40,
                  ),
                ),
              ),
            )
          : Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1E293B), Color(0xFF334155)],
                ),
              ),
              child: const Center(
                child: Icon(
                  Remix.image_line,
                  color: Color(0xFF94A3B8),
                  size: 40,
                ),
              ),
            ),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Cover Image
        effectiveHeroTag != null
            ? Hero(tag: effectiveHeroTag, child: coverImage)
            : coverImage,

        // Back button
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 14,
          child: GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: const Center(
                child: IconTheme(
                  data: IconThemeData(color: AppColors.textPrimary, size: 20),
                  child: BackButtonIcon(),
                ),
              ),
            ),
          ),
        ),

        // Overlapping Profile Avatar
        Positioned(
          bottom: -40,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 40,
                backgroundColor: const Color(0xFFE2E8F0),
                backgroundImage: avatarUrl.isNotEmpty
                    ? NetworkImage(avatarUrl)
                    : null,
                child: avatarUrl.isEmpty
                    ? Text(
                        creator.name.isNotEmpty
                            ? creator.name[0].toUpperCase()
                            : 'C',
                        style: GoogleFonts.outfit(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark,
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIdentitySection() {
    return Padding(
      padding: const EdgeInsets.only(top: 36, left: 20, right: 20),
      child: Column(
        children: [
          // Name + Verified Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                creator.name,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              if (creator.isVerified) ...[
                const SizedBox(width: 5),
                const Icon(Icons.verified, color: Color(0xFF3B82F6), size: 18),
              ],
            ],
          ),

          const SizedBox(height: 6),

          // Top Creator Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFD1FAE5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Remix.star_fill,
                  color: AppColors.primaryDark,
                  size: 12,
                ),
                const SizedBox(width: 4),
                Text(
                  'Top Creator',
                  style: GoogleFonts.outfit(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Category Pill & Location
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2.5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  creator.categoryName,
                  style: GoogleFonts.outfit(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2563EB),
                  ),
                ),
              ),
              if (creator.location.isNotEmpty) ...[
                const SizedBox(width: 10),
                Row(
                  children: [
                    const Icon(
                      Remix.map_pin_2_line,
                      size: 12,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      creator.location,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricBoxes() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _buildStatBox(creator.followersCount, 'Followers'),
          const SizedBox(width: 10),
          _buildStatBox('${creator.engagementRate}%', 'Engagement Rate'),
          const SizedBox(width: 10),
          _buildStatBox(
            creator.languages.isNotEmpty ? creator.languages.first : 'English',
            'Languages',
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 10,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandCollaborations() {
    return const SizedBox.shrink();
  }

  Widget _buildRecentContent() {
    if (creator.portfolioUrls.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Content',
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: creator.portfolioUrls.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final img = creator.portfolioUrls[index];
                return Container(
                  width: 110,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: const Color(0xFFE2E8F0),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      img,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, st) => const Center(
                        child: Icon(Remix.image_line, color: Color(0xFF94A3B8)),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
      ),
      child: Row(
        children: [
          // Chat Button
          Expanded(
            flex: 1,
            child: SizedBox(
              height: 44,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(
                    color: AppColors.primaryDark,
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Starting direct chat with ${creator.name}...',
                      ),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppColors.primaryDark,
                    ),
                  );
                },
                icon: const Icon(
                  Remix.chat_1_line,
                  color: AppColors.primaryDark,
                  size: 18,
                ),
                label: Text(
                  'Chat',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Book Now Button
          if (ref.watch(permissionManagerProvider).customerCan('CUSTOMER_INFLUENCER_BOOKINGS', 'VIEW'))
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            CustomerInfluencerPackagesView(creator: creator),
                      ),
                    );
                  },
                  child: Text(
                    'Book Now',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
