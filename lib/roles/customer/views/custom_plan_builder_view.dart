import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/roles/customer/models/custom_plan_model.dart';
import 'package:quickboom_crm_customer/roles/customer/viewmodels/custom_plan_viewmodel.dart';

class CustomPlanBuilderView extends ConsumerStatefulWidget {
  final VoidCallback? onPlanCreated;

  const CustomPlanBuilderView({super.key, this.onPlanCreated});

  @override
  ConsumerState<CustomPlanBuilderView> createState() =>
      _CustomPlanBuilderViewState();
}

class _CustomPlanBuilderViewState extends ConsumerState<CustomPlanBuilderView> {
  String _selectedCategory = 'ALL';

  final List<Map<String, String>> _categories = [
    {'key': 'ALL', 'label': 'All Options'},
    {'key': 'CONTENT', 'label': 'Reels & Content'},
    {'key': 'CREATIVES', 'label': 'Creatives & Posts'},
    {'key': 'ADS', 'label': 'Ads Management'},
    {'key': 'CRM', 'label': 'CRM & Seats'},
    {'key': 'STORAGE', 'label': 'Storage'},
    {'key': 'SUPPORT', 'label': 'Management'},
  ];

  @override
  Widget build(BuildContext context) {
    final optionsAsync = ref.watch(customPlanOptionsProvider);
    final builderState = ref.watch(customPlanBuilderViewModelProvider);
    final builderNotifier = ref.read(
      customPlanBuilderViewModelProvider.notifier,
    );

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Custom Plan Builder',
              style: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              'Tailor features & duration for your business',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
      body: optionsAsync.when(
        data: (options) {
          final filteredOptions = options.where((opt) {
            if (_selectedCategory == 'ALL') return true;
            return opt.category.toUpperCase() == _selectedCategory;
          }).toList();

          return Stack(
            children: [
              SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: 140,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Top Banner
                    _buildInfoBanner(),

                    const SizedBox(height: 18),

                    // 2. Duration Selector
                    _buildDurationSection(builderState, builderNotifier),

                    const SizedBox(height: 20),

                    // 3. Category Filter Pills
                    _buildCategoryFilter(),

                    const SizedBox(height: 16),

                    // 4. Feature Options List
                    Text(
                      'CONFIGURABLE FEATURES & SERVICES',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary.withValues(alpha: 0.8),
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 10),

                    if (filteredOptions.isEmpty)
                      _buildEmptyCategory()
                    else
                      ...filteredOptions.map((opt) {
                        return _buildOptionCard(
                          opt,
                          builderState,
                          builderNotifier,
                        );
                      }),

                    const SizedBox(height: 20),

                    // 5. Server Price Breakdown Card
                    _buildPriceBreakdownCard(builderState),
                  ],
                ),
              ),

              // 6. Sticky Bottom Checkout Bar
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildBottomBar(builderState, builderNotifier),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Remix.error_warning_line,
                  color: AppColors.error,
                  size: 40,
                ),
                const SizedBox(height: 12),
                Text(
                  'Failed to load plan options',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => ref.refresh(customPlanOptionsProvider),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Remix.sparkling_2_fill,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Server-Verified Pricing',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'All pricing, duration discounts, and GST are calculated live by the backend server based on your selected quantities.',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationSection(
    CustomPlanBuilderState state,
    CustomPlanBuilderNotifier notifier,
  ) {
    final durations = [
      {'months': 1, 'label': '1 Month', 'discount': ''},
      {'months': 3, 'label': '3 Months', 'discount': '5% OFF'},
      {'months': 6, 'label': '6 Months', 'discount': '10% OFF'},
      {'months': 12, 'label': '12 Months', 'discount': '15% OFF'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SELECT PLAN DURATION',
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: AppColors.textSecondary.withValues(alpha: 0.8),
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: durations.map((d) {
            final months = d['months'] as int;
            final isSelected = state.selectedDuration == months;
            final discount = d['discount'] as String;

            return Expanded(
              child: GestureDetector(
                onTap: () => notifier.setDuration(months),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.border.withValues(alpha: 0.8),
                      width: isSelected ? 1.5 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : [],
                  ),
                  child: Column(
                    children: [
                      Text(
                        d['label'] as String,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Colors.white
                              : AppColors.textPrimary,
                        ),
                      ),
                      if (discount.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.25)
                                : AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            discount,
                            style: GoogleFonts.outfit(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCategoryFilter() {
    return SizedBox(
      height: 36,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isSelected = _selectedCategory == cat['key'];

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(
                cat['label']!,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
              ),
              selected: isSelected,
              onSelected: (val) {
                setState(() {
                  _selectedCategory = cat['key']!;
                });
              },
              selectedColor: AppColors.primary,
              backgroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: isSelected ? AppColors.primary : AppColors.border,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOptionCard(
    CustomPlanOption opt,
    CustomPlanBuilderState state,
    CustomPlanBuilderNotifier notifier,
  ) {
    final isSelected = state.isSelected(opt.id);
    final quantity = state.getQuantity(opt.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected
              ? AppColors.primary
              : AppColors.border.withValues(alpha: 0.8),
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
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => notifier.toggleOption(opt),
                  child: Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.border,
                        width: 1.5,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(
                            Remix.check_line,
                            size: 16,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              opt.name,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            '₹${opt.monthlyPrice.toInt()}/mo',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      if (opt.description != null &&
                          opt.description!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          opt.description!,
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            if (isSelected) ...[
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Quantity (${opt.unitName}s):',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Row(
                    children: [
                      _buildQuantityButton(
                        icon: Remix.subtract_line,
                        onTap: () {
                          if (quantity > opt.minQuantity) {
                            notifier.setQuantity(opt, quantity - 1);
                          } else {
                            notifier.toggleOption(opt);
                          }
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: Text(
                          '$quantity',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      _buildQuantityButton(
                        icon: Remix.add_line,
                        onTap: () {
                          if (quantity < opt.maxQuantity) {
                            notifier.setQuantity(opt, quantity + 1);
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.scaffoldBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, size: 14, color: AppColors.textPrimary),
      ),
    );
  }

  Widget _buildEmptyCategory() {
    return Container(
      padding: const EdgeInsets.all(30),
      alignment: Alignment.center,
      child: Text(
        'No options available under this category',
        style: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildPriceBreakdownCard(CustomPlanBuilderState state) {
    return state.previewAsync.when(
      data: (preview) {
        if (preview == null || preview.items.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              'Select features to view live server price preview',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'PLAN SUMMARY BREAKDOWN',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      letterSpacing: 1.1,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${preview.duration} ${preview.durationUnit}S',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...preview.items.map((it) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${it.quantity}x ${it.name}',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        '₹${it.totalPrice.toInt()}',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const Divider(height: 18, color: AppColors.border),
              _buildPriceRow('Subtotal', '₹${preview.subtotal.toInt()}'),
              if (preview.discount > 0)
                _buildPriceRow(
                  'Duration Discount (${preview.discountPercentage.toInt()}% Off)',
                  '-₹${preview.discount.toInt()}',
                  isDiscount: true,
                ),
              _buildPriceRow('GST (18%)', '₹${preview.tax.toInt()}'),
              const Divider(height: 18, color: AppColors.border),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Final Payable Amount',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '₹${preview.totalAmount.toInt()}',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: const CircularProgressIndicator(
          color: AppColors.primary,
          strokeWidth: 2,
        ),
      ),
      error: (err, _) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
        ),
        child: Text(
          'Failed to calculate price: ${err.toString()}',
          style: GoogleFonts.outfit(fontSize: 12, color: AppColors.error),
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, {bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDiscount ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isDiscount ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(
    CustomPlanBuilderState state,
    CustomPlanBuilderNotifier notifier,
  ) {
    final preview = state.previewAsync.asData?.value;
    final total = preview?.totalAmount ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TOTAL AMOUNT',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  '₹${total.toInt()}',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: state.isSubmitting || total <= 0
                    ? null
                    : () async {
                        final success = await notifier
                            .processCheckoutAndPayment();
                        if (success && mounted) {
                          _showSuccessDialog();
                        } else if (state.errorMessage != null && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(state.errorMessage!),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: state.isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Remix.shield_check_line,
                            size: 18,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Activate Custom Plan',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Remix.checkbox_circle_fill,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Plan Activated!',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your custom plan is now active.',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.scaffoldBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• Expiry calculated from activation date.',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '• Monthly milestone schedules generated.',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '• Expiry reminders enabled (10d, 5d, 1d, 0d).',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx); // Close dialog
                Navigator.pop(context); // Return to plans view
                widget.onPlanCreated?.call();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('View Plan Status'),
            ),
          ],
        );
      },
    );
  }
}
