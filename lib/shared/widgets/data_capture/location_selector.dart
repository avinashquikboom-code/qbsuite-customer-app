import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';

const List<String> kQuickCitySuggestions = [
  'Vadodara',
  'Mumbai',
  'Pune',
  'Navi Mumbai',
  'Ahmedabad',
  'Surat',
  'Bengaluru',
  'Delhi NCR',
  'Hyderabad',
  'Chennai',
  'Indore',
  'Jaipur',
];

class LocationSelector extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onLocationChanged;

  const LocationSelector({
    super.key,
    required this.controller,
    required this.onLocationChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Text Input Field
        TextFormField(
          controller: controller,
          onChanged: onLocationChanged,
          decoration: InputDecoration(
            hintText: 'Enter city, area, or locality (e.g. Vadodara)',
            hintStyle: GoogleFonts.outfit(
              fontSize: 14,
              color: AppColors.textPlaceholder,
            ),
            prefixIcon: const Icon(
              Icons.location_on_rounded,
              color: AppColors.primary,
              size: 20,
            ),
            suffixIcon: IconButton(
              icon: const Icon(
                Icons.my_location_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              tooltip: 'Use Current Location',
              onPressed: () {
                controller.text = 'Vadodara';
                onLocationChanged('Vadodara');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Detected Current City: Vadodara, Gujarat',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                    ),
                    backgroundColor: AppColors.primary,
                    duration: const Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Quick City Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: kQuickCitySuggestions.map((city) {
              final isSelected =
                  controller.text.trim().toLowerCase() == city.toLowerCase();
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(city),
                  selected: isSelected,
                  selectedColor: AppColors.primaryLight,
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: isSelected ? AppColors.primary : AppColors.border,
                  ),
                  labelStyle: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected
                        ? AppColors.primaryDark
                        : AppColors.textSecondary,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      controller.text = city;
                      onLocationChanged(city);
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
