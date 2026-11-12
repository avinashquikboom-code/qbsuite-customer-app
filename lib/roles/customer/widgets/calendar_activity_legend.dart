import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quickboom_company_admin/roles/company_admin/models/company_admin_models.dart';

class CalendarActivityLegend extends StatelessWidget {
  final List<CustomerCalendarActivity> activities;
  final List<TaskCategory>? explicitCategories;

  const CalendarActivityLegend({
    super.key,
    this.activities = const [],
    this.explicitCategories,
  });

  @override
  Widget build(BuildContext context) {
    final categories =
        explicitCategories ??
        (activities.isNotEmpty
            ? activities
                  .map((a) => resolveTaskCategory(a))
                  .where((c) => c != TaskCategory.unknown)
                  .toSet()
                  .toList()
            : [
                TaskCategory.reelShoot,
                TaskCategory.reelEdit,
                TaskCategory.reelPost,
                TaskCategory.storyDesign,
                TaskCategory.storyPost,
              ]);

    if (categories.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: categories.map((cat) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: cat.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                cat.label,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF475569),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
