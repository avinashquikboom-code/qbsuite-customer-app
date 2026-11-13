import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import '../../../core/services/permission_manager.dart';
import '../../../shared/widgets/permission_guarded_view.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/skeleton_loader.dart';
import '../models/influencer_model.dart';
import '../viewmodels/customer_influencer_viewmodel.dart';

/// Screen 7 — Customer Dashboard: My Influencer Bookings
/// Visual source of truth: Screen 7 of reference_screens.jpeg
class CustomerMyInfluencerBookingsView extends ConsumerStatefulWidget {
  const CustomerMyInfluencerBookingsView({super.key});

  @override
  ConsumerState<CustomerMyInfluencerBookingsView> createState() =>
      _CustomerMyInfluencerBookingsViewState();
}

class _CustomerMyInfluencerBookingsViewState
    extends ConsumerState<CustomerMyInfluencerBookingsView> {
  int _selectedTabIndex =
      0; // 0: Upcoming, 1: Active, 2: Completed, 3: Cancelled
  final List<String> _tabs = ['Upcoming', 'Active', 'Completed', 'Cancelled'];

  void _showBookingDetailsSheet(
    BuildContext context,
    InfluencerBookingModel booking,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BookingDetailModal(booking: booking),
    );
  }

  @override
  Widget build(BuildContext context) {
    final perms = ref.watch(permissionManagerProvider);
    if (!perms.customerCan('CUSTOMER_INFLUENCER_BOOKINGS', 'VIEW')) {
      return const PermissionGuardedView(
        moduleKey: 'CUSTOMER_INFLUENCER_BOOKINGS',
        moduleTitle: 'My Influencer Bookings',
        child: SizedBox.shrink(),
      );
    }

    final bookingsAsync = ref.watch(customerInfluencerBookingsProvider);
    final allBookings = bookingsAsync.value ?? [];
    final activeTabName = _tabs[_selectedTabIndex];

    // Customer Isolation & Tab Filter
    final filteredBookings = allBookings.where((b) {
      if (activeTabName == 'Upcoming') {
        return b.status.toLowerCase() == 'upcoming' ||
            b.status.toLowerCase() == 'confirmed' ||
            b.status.toLowerCase() == 'pending';
      }
      return b.status.toLowerCase() == activeTabName.toLowerCase();
    }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
        title: Text(
          'My Influencer Bookings',
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: false,
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () =>
            ref.read(customerInfluencerBookingsProvider.notifier).refresh(),
        child: Column(
          children: [
            // Filter Tabs Pills Row
            _buildPillTabs(),

            // Bookings List
            Expanded(
              child: bookingsAsync.isLoading && allBookings.isEmpty
                  ? const SkeletonList(count: 4)
                  : bookingsAsync.hasError && allBookings.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Remix.error_warning_line,
                              size: 44,
                              color: Color(0xFFEF4444),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Unable to load bookings',
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Please check your connection and try again.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () => ref
                                  .read(
                                    customerInfluencerBookingsProvider.notifier,
                                  )
                                  .refresh(),
                              icon: const Icon(
                                Remix.refresh_line,
                                size: 16,
                                color: Colors.white,
                              ),
                              label: Text(
                                'Retry',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : filteredBookings.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Remix.file_list_2_line,
                              size: 44,
                              color: Color(0xFFCBD5E1),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'No $activeTabName Bookings',
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Your influencer bookings in this state will appear here.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      physics: const BouncingScrollPhysics(),
                      itemCount: filteredBookings.length,
                      separatorBuilder: (ctx, idx) =>
                          const SizedBox(height: 12),
                      itemBuilder: (ctx, idx) {
                        final booking = filteredBookings[idx];
                        return _buildBookingCard(context, booking);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPillTabs() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(_tabs.length, (idx) {
          final isSelected = _selectedTabIndex == idx;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTabIndex = idx),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primaryDark
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    _tabs[idx],
                    style: GoogleFonts.outfit(
                      fontSize: 11.5,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBookingCard(
    BuildContext context,
    InfluencerBookingModel booking,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Influencer Image
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: booking.influencerImage.isNotEmpty
                ? Image.network(
                    booking.influencerImage,
                    width: 54,
                    height: 54,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, st) => Container(
                      width: 54,
                      height: 54,
                      color: const Color(0xFFE2E8F0),
                      child: const Icon(
                        Remix.user_3_line,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  )
                : Container(
                    width: 54,
                    height: 54,
                    color: const Color(0xFFE2E8F0),
                    child: const Icon(
                      Remix.user_3_line,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
          ),

          const SizedBox(width: 12),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.influencerName,
                  style: GoogleFonts.outfit(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  booking.packageName,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  booking.campaignDate,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '₹${booking.totalAmount.toStringAsFixed(0)}',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          // Status & View Details
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Status Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFEDD5)),
                ),
                child: Text(
                  booking.status,
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFEA580C),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // View Details Link
              GestureDetector(
                onTap: () => _showBookingDetailsSheet(context, booking),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View Details',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Remix.arrow_right_s_line,
                      size: 14,
                      color: AppColors.primaryDark,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BookingDetailModal extends StatelessWidget {
  final InfluencerBookingModel booking;

  const _BookingDetailModal({required this.booking});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 18,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Booking Details',
                  style: GoogleFonts.outfit(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Remix.close_line, size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Booking ID: ${booking.bookingId}',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDark,
              ),
            ),
            const Divider(height: 20),
            _buildDetailRow('Creator', booking.influencerName),
            _buildDetailRow('Package', booking.packageName),
            _buildDetailRow('Campaign Date', booking.campaignDate),
            _buildDetailRow('Brand Name', booking.brandName),
            _buildDetailRow('Contact Person', booking.contactPerson),
            _buildDetailRow('Mobile Number', booking.mobileNumber),
            _buildDetailRow('Email', booking.email),
            _buildDetailRow('Business', booking.businessName),
            _buildDetailRow('Objective', booking.campaignObjective),
            if (booking.notes != null && booking.notes!.isNotEmpty)
              _buildDetailRow('Notes', booking.notes!),
            const Divider(height: 20),
            _buildDetailRow(
              'Package Cost',
              '₹${booking.packageCost.toStringAsFixed(0)}',
            ),
            _buildDetailRow(
              'Platform Fee',
              '₹${booking.platformFee.toStringAsFixed(0)}',
            ),
            _buildDetailRow('GST (18%)', '₹${booking.gst.toStringAsFixed(0)}'),
            _buildDetailRow(
              'Total Paid',
              '₹${booking.totalAmount.toStringAsFixed(0)}',
              isBold: true,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.outfit(
                fontSize: 12.5,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: isBold ? AppColors.primaryDark : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
