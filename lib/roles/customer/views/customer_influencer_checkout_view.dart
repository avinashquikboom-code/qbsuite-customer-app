import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import '../../../core/theme/app_colors.dart';
import '../../../../core/services/secure_storage_service.dart';
import '../models/influencer_model.dart';
import 'customer_influencer_payment_view.dart';

/// Screen 4 — Customer Influencer Checkout / Campaign Details
/// Visual source of truth: Screen 4 of reference_screens.jpeg
class CustomerInfluencerCheckoutView extends ConsumerStatefulWidget {
  final InfluencerModel creator;
  final InfluencerPackageModel package;
  final String selectedDateString;

  const CustomerInfluencerCheckoutView({
    super.key,
    required this.creator,
    required this.package,
    required this.selectedDateString,
  });

  @override
  ConsumerState<CustomerInfluencerCheckoutView> createState() =>
      _CustomerInfluencerCheckoutViewState();
}

class _CustomerInfluencerCheckoutViewState
    extends ConsumerState<CustomerInfluencerCheckoutView> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _brandNameController;
  late TextEditingController _contactPersonController;
  late TextEditingController _mobileNumberController;
  late TextEditingController _emailController;
  late TextEditingController _businessNameController;
  late TextEditingController _instagramIdController;
  late TextEditingController _notesController;

  String _campaignObjective = 'Brand Awareness';
  late String _currentDateString;
  late InfluencerPackageModel _currentPackage;

  final List<String> _objectives = [
    'Brand Awareness',
    'Lead Generation',
    'Product Launch',
    'Sales Promotion',
    'App Installs',
  ];

  @override
  void initState() {
    super.initState();
    _currentPackage = widget.package;
    _currentDateString = widget.selectedDateString;

    _brandNameController = TextEditingController();
    _contactPersonController = TextEditingController();
    _mobileNumberController = TextEditingController();
    _emailController = TextEditingController();
    _businessNameController = TextEditingController();
    _instagramIdController = TextEditingController();
    _notesController = TextEditingController();

    _loadUserSession();
  }

  Future<void> _loadUserSession() async {
    final email = await SecureStorageService.getUserEmail();
    final name =
        await SecureStorageService.getUserName() ??
        await SecureStorageService.getFirstName();
    final business = await SecureStorageService.getCustomerName();
    if (mounted) {
      setState(() {
        if (email != null &&
            email.isNotEmpty &&
            _emailController.text.isEmpty) {
          _emailController.text = email;
        }
        if (name != null &&
            name.isNotEmpty &&
            _contactPersonController.text.isEmpty) {
          _contactPersonController.text = name;
        }
        if (business != null && business.isNotEmpty) {
          if (_brandNameController.text.isEmpty) {
            _brandNameController.text = business;
          }
          if (_businessNameController.text.isEmpty) {
            _businessNameController.text = business;
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _brandNameController.dispose();
    _contactPersonController.dispose();
    _mobileNumberController.dispose();
    _emailController.dispose();
    _businessNameController.dispose();
    _instagramIdController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onProceed() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CustomerInfluencerPaymentView(
            creator: widget.creator,
            package: _currentPackage,
            campaignDate: _currentDateString,
            brandName: _brandNameController.text.trim(),
            contactPerson: _contactPersonController.text.trim(),
            mobileNumber: _mobileNumberController.text.trim(),
            email: _emailController.text.trim(),
            businessName: _businessNameController.text.trim(),
            instagramId: _instagramIdController.text.trim(),
            campaignObjective: _campaignObjective,
            notes: _notesController.text.trim(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
        title: Text(
          'Book Now',
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: false,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section Title: Campaign Details
                    Text(
                      'Campaign Details',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Brand Name
                    _buildField(
                      label: 'Brand Name *',
                      controller: _brandNameController,
                      validator: (v) => v == null || v.isEmpty
                          ? 'Brand name is required'
                          : null,
                    ),

                    // Contact Person
                    _buildField(
                      label: 'Contact Person *',
                      controller: _contactPersonController,
                      validator: (v) => v == null || v.isEmpty
                          ? 'Contact person is required'
                          : null,
                    ),

                    // Mobile Number
                    _buildField(
                      label: 'Mobile Number *',
                      controller: _mobileNumberController,
                      keyboardType: TextInputType.phone,
                      validator: (v) => v == null || v.isEmpty
                          ? 'Mobile number is required'
                          : null,
                    ),

                    // Email Address
                    _buildField(
                      label: 'Email Address *',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => v == null || !v.contains('@')
                          ? 'Valid email required'
                          : null,
                    ),

                    // Business Name
                    _buildField(
                      label: 'Business Name *',
                      controller: _businessNameController,
                      validator: (v) => v == null || v.isEmpty
                          ? 'Business name is required'
                          : null,
                    ),

                    // Instagram ID
                    _buildField(
                      label: 'Instagram ID',
                      controller: _instagramIdController,
                    ),

                    // Campaign Objective Dropdown
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Campaign Objective *',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _campaignObjective,
                              isExpanded: true,
                              icon: const Icon(
                                Remix.arrow_down_s_line,
                                size: 18,
                              ),
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                color: AppColors.textPrimary,
                              ),
                              items: _objectives.map((obj) {
                                return DropdownMenuItem(
                                  value: obj,
                                  child: Text(obj),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _campaignObjective = val);
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 22),

                    // Section Title: Booking Details
                    Text(
                      'Booking Details',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Booking Details Summary Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Influencer Info Row
                          Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child:
                                    widget.creator.effectiveImageUrl.isNotEmpty
                                    ? Image.network(
                                        widget.creator.effectiveImageUrl,
                                        width: 44,
                                        height: 44,
                                        fit: BoxFit.cover,
                                        errorBuilder: (ctx, err, st) =>
                                            const Icon(Remix.user_3_line),
                                      )
                                    : const Icon(Remix.user_3_line),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.creator.name,
                                      style: GoogleFonts.outfit(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      '${widget.creator.categoryName} • ${widget.creator.followersCount} Followers',
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Text(
                                  'Change',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          // Selected Package Row
                          Text(
                            'Selected Package *',
                            style: GoogleFonts.outfit(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Text(
                              '${_currentPackage.name} (${_currentPackage.formattedPrice})',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Campaign Date Row
                          Text(
                            'Campaign Date *',
                            style: GoogleFonts.outfit(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Remix.time_line,
                                  size: 16,
                                  color: Color(0xFF64748B),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _currentDateString,
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Remix.calendar_line,
                                  size: 16,
                                  color: Color(0xFF64748B),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),

                          // Notes / Instructions
                          Text(
                            'Notes / Instructions',
                            style: GoogleFonts.outfit(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextFormField(
                            controller: _notesController,
                            maxLines: 2,
                            decoration: InputDecoration(
                              hintText: 'Any specific requirements...',
                              hintStyle: GoogleFonts.outfit(
                                fontSize: 12,
                                color: const Color(0xFF94A3B8),
                              ),
                              contentPadding: const EdgeInsets.all(10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Bottom CTA
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFFF1F5F9), width: 1),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _onProceed,
                  child: Text(
                    'Proceed to Payment',
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
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            validator: validator,
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
                borderSide: BorderSide(
                  color: AppColors.primaryDark,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
