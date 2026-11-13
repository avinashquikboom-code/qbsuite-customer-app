import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/permission_manager.dart';
import '../models/influencer_model.dart';
import '../viewmodels/customer_influencer_viewmodel.dart';
import 'customer_influencer_checkout_view.dart';

/// Screen 3 — Customer Influencer Packages & Dates
/// Visual source of truth: Screen 3 of reference_screens.jpeg
class CustomerInfluencerPackagesView extends ConsumerStatefulWidget {
  final InfluencerModel creator;

  const CustomerInfluencerPackagesView({super.key, required this.creator});

  @override
  ConsumerState<CustomerInfluencerPackagesView> createState() =>
      _CustomerInfluencerPackagesViewState();
}

class _CustomerInfluencerPackagesViewState
    extends ConsumerState<CustomerInfluencerPackagesView> {
  int _selectedTabIndex = 1; // Default to 'Packages' tab
  late List<InfluencerPackageModel> _packages;
  InfluencerPackageModel? _selectedPackage;

  final List<String> _tabs = ['About', 'Packages', 'Portfolio', 'Reviews'];

  static final List<String> _weekdays = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
  static final List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  late final List<DateTime> _availableDates = List.generate(
    7,
    (index) => DateTime.now().add(Duration(days: index)),
  );
  late DateTime _selectedDate = _availableDates.first;

  @override
  void initState() {
    super.initState();
    _packages = List.from(widget.creator.packages);
    if (_packages.isNotEmpty) {
      _selectedPackage = _packages.first;
    }
  }

  void _proceedToCheckout(InfluencerPackageModel pkg) {
    final dateStr =
        '${_selectedDate.day} ${_months[_selectedDate.month - 1]} ${_selectedDate.year}';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerInfluencerCheckoutView(
          creator: widget.creator,
          package: pkg,
          selectedDateString: dateStr,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final backendPackagesAsync = ref.watch(
      customerInfluencerPackagesProvider(widget.creator.id),
    );
    final List<InfluencerPackageModel> currentPackages = backendPackagesAsync
        .when(
          data: (data) => data,
          loading: () => _packages,
          error: (_, _) => _packages,
        );

    if (currentPackages.isNotEmpty) {
      if (_selectedPackage == null ||
          !currentPackages.any((p) => p.id == _selectedPackage!.id)) {
        _selectedPackage = currentPackages.first;
      }
    } else {
      _selectedPackage = null;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
        title: Row(
          children: [
            Text(
              widget.creator.name,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            if (widget.creator.isVerified) ...[
              const SizedBox(width: 5),
              const Icon(Icons.verified, color: Color(0xFF3B82F6), size: 16),
            ],
          ],
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Navigation Tabs: About, Packages, Portfolio, Reviews
          _buildTabsRow(),

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section Header: Packages & Pricing
                  Text(
                    'Packages & Pricing',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Packages List
                  if (backendPackagesAsync.isLoading &&
                      currentPackages.isEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                  ] else if (backendPackagesAsync.hasError &&
                      currentPackages.isEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(
                              Remix.error_warning_line,
                              color: Color(0xFFEF4444),
                              size: 30,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Failed to load packages',
                              style: GoogleFonts.outfit(
                                fontSize: 12.5,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            TextButton(
                              onPressed: () => ref.refresh(
                                customerInfluencerPackagesProvider(
                                  widget.creator.id,
                                ),
                              ),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else if (currentPackages.isEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 24,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Remix.shopping_bag_line,
                            size: 32,
                            color: Color(0xFF94A3B8),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No packages available for this creator',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    ...List.generate(currentPackages.length, (idx) {
                      final pkg = currentPackages[idx];
                      final isSelected = _selectedPackage?.id == pkg.id;
                      return _buildPackageCard(pkg, isSelected);
                    }),
                  ],

                  const SizedBox(height: 20),

                  // Section Header: Available Dates
                  Text(
                    'Available Dates',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Month Selector
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_months[_selectedDate.month - 1]} ${_selectedDate.year}',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Remix.arrow_left_s_line, size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {},
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(
                              Remix.arrow_right_s_line,
                              size: 18,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Weekday Date Selector
                  _buildDatesStrip(),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),

          // Bottom Full-width CTA Button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Color(0xFFF1F5F9), width: 1),
              ),
            ),
            child: ref.watch(permissionManagerProvider).customerCan('CUSTOMER_INFLUENCER_BOOKINGS', 'VIEW')
                ? SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedPackage != null
                            ? AppColors.primaryDark
                            : const Color(0xFFCBD5E1),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _selectedPackage != null
                          ? () => _proceedToCheckout(_selectedPackage!)
                          : null,
                      child: Text(
                        'Book Now',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabsRow() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
      ),
      child: Row(
        children: List.generate(_tabs.length, (idx) {
          final isSelected = _selectedTabIndex == idx;
          return Expanded(
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedTabIndex = idx;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected
                          ? AppColors.primaryDark
                          : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                child: Center(
                  child: Text(
                    _tabs[idx],
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: isSelected
                          ? AppColors.primaryDark
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

  Widget _buildPackageCard(InfluencerPackageModel pkg, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPackage = pkg;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primaryDark : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: pkg.isCustom
                    ? const Color(0xFFFFFBEB)
                    : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Icon(
                  pkg.isCustom
                      ? Remix.apps_2_line
                      : (pkg.iconType == 'story'
                            ? Remix.film_line
                            : Remix.movie_line),
                  color: pkg.isCustom
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFFEF4444),
                  size: 20,
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 2,
                    children: [
                      Text(
                        pkg.name,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (pkg.badgeText.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            pkg.badgeText,
                            style: GoogleFonts.outfit(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF0284C7),
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 2),
                  Text(
                    pkg.subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    pkg.formattedPrice,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),

            // Book Now Action
            if (ref.watch(permissionManagerProvider).customerCan('CUSTOMER_INFLUENCER_BOOKINGS', 'VIEW'))
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                onPressed: () => _proceedToCheckout(pkg),
                child: Text(
                  'Book Now',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatesStrip() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: _availableDates.map((dt) {
        final isSelected =
            dt.day == _selectedDate.day &&
            dt.month == _selectedDate.month &&
            dt.year == _selectedDate.year;
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedDate = dt;
            });
          },
          child: Column(
            children: [
              Text(
                _weekdays[dt.weekday - 1],
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primaryDark
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primaryDark
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Center(
                  child: Text(
                    '${dt.day}',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
