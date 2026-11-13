import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/roles/customer/models/customer_plan_model.dart';

class BillingCycleToggle extends StatelessWidget {
  final SubscriptionBillingCycle selectedCycle;
  final ValueChanged<SubscriptionBillingCycle> onCycleChanged;
  final double? maxSavingsPercentage;

  const BillingCycleToggle({
    super.key,
    required this.selectedCycle,
    required this.onCycleChanged,
    this.maxSavingsPercentage,
  });

  @override
  Widget build(BuildContext context) {
    final isMonthly = selectedCycle == SubscriptionBillingCycle.monthly;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.pillBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          // Monthly Tab
          Expanded(
            child: GestureDetector(
              onTap: () => onCycleChanged(SubscriptionBillingCycle.monthly),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 8,
                ),
                decoration: BoxDecoration(
                  color: isMonthly ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isMonthly
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Remix.calendar_line,
                        size: 15,
                        color: isMonthly
                            ? AppColors.primaryDark
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Monthly',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: isMonthly
                                ? FontWeight.bold
                                : FontWeight.w600,
                            color: isMonthly
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Yearly Tab
          Expanded(
            child: GestureDetector(
              onTap: () => onCycleChanged(SubscriptionBillingCycle.yearly),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 8,
                ),
                decoration: BoxDecoration(
                  color: !isMonthly ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: !isMonthly
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Remix.calendar_check_line,
                        size: 15,
                        color: !isMonthly
                            ? AppColors.primaryDark
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Yearly',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: !isMonthly
                                ? FontWeight.bold
                                : FontWeight.w600,
                            color: !isMonthly
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (maxSavingsPercentage != null &&
                          maxSavingsPercentage! > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                AppColors.primary,
                                AppColors.primaryDark,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'SAVE ${maxSavingsPercentage!.toStringAsFixed(0)}%',
                            style: GoogleFonts.outfit(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ],
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
