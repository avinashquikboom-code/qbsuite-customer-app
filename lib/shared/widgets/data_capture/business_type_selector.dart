import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';

class BusinessCategoryItem {
  final String label;
  final IconData icon;

  const BusinessCategoryItem(this.label, this.icon);
}

const List<BusinessCategoryItem> kDefaultBusinessCategories = [
  BusinessCategoryItem('Gym', Icons.fitness_center_rounded),
  BusinessCategoryItem('Restaurant', Icons.restaurant_rounded),
  BusinessCategoryItem('Hotel', Icons.hotel_rounded),
  BusinessCategoryItem('Salon', Icons.content_cut_rounded),
  BusinessCategoryItem('Hospital', Icons.local_hospital_rounded),
  BusinessCategoryItem('Clinic', Icons.medical_services_rounded),
  BusinessCategoryItem('Real Estate', Icons.home_work_rounded),
  BusinessCategoryItem('School', Icons.school_rounded),
  BusinessCategoryItem('College', Icons.account_balance_rounded),
  BusinessCategoryItem('Retail Store', Icons.storefront_rounded),
  BusinessCategoryItem('Travel Agency', Icons.flight_takeoff_rounded),
  BusinessCategoryItem('Automobile Dealer', Icons.directions_car_rounded),
  BusinessCategoryItem('Custom Business', Icons.tune_rounded),
];

class BusinessTypeSelector extends StatefulWidget {
  final String selectedCategory;
  final ValueChanged<String> onSelected;

  const BusinessTypeSelector({
    super.key,
    required this.selectedCategory,
    required this.onSelected,
  });

  static Future<String?> showSearchableBottomSheet(
    BuildContext context, {
    required String currentSelection,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          _SearchableCategorySheet(currentSelection: currentSelection),
    );
  }

  @override
  State<BusinessTypeSelector> createState() => _BusinessTypeSelectorState();
}

class _BusinessTypeSelectorState extends State<BusinessTypeSelector> {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final result = await BusinessTypeSelector.showSearchableBottomSheet(
          context,
          currentSelection: widget.selectedCategory,
        );
        if (result != null) {
          widget.onSelected(result);
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.business_center_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Business Category',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.selectedCategory.isNotEmpty
                        ? widget.selectedCategory
                        : 'Select business type...',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.search_rounded,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchableCategorySheet extends StatefulWidget {
  final String currentSelection;

  const _SearchableCategorySheet({required this.currentSelection});

  @override
  State<_SearchableCategorySheet> createState() =>
      _SearchableCategorySheetState();
}

class _SearchableCategorySheetState extends State<_SearchableCategorySheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<BusinessCategoryItem> _filtered = kDefaultBusinessCategories;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearch);
  }

  void _onSearch() {
    final query = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filtered = kDefaultBusinessCategories;
      } else {
        _filtered = kDefaultBusinessCategories
            .where((item) => item.label.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Select Business Type',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose the category of commercial prospects you want to extract.',
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchCtrl,
              autofocus: false,
              decoration: InputDecoration(
                hintText: 'Search business category...',
                hintStyle: GoogleFonts.outfit(
                  fontSize: 14,
                  color: AppColors.textPlaceholder,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.textSecondary,
                ),
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _filtered.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, color: AppColors.border),
                itemBuilder: (ctx, idx) {
                  final item = _filtered[idx];
                  final isSelected = item.label == widget.currentSelection;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primaryLight
                            : AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        item.icon,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      item.label,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w600,
                        color: isSelected
                            ? AppColors.primaryDark
                            : AppColors.textPrimary,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.primary,
                          )
                        : const Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.border,
                          ),
                    onTap: () => Navigator.pop(context, item.label),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
