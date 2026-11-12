import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/roles/customer/models/customer_plan_model.dart';

class SubscriptionStatusBadge extends StatelessWidget {
  final SubscriptionStatus status;
  final bool isExpired;

  const SubscriptionStatusBadge({
    super.key,
    required this.status,
    this.isExpired = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;

    if (isExpired || status == SubscriptionStatus.expired) {
      bg = AppColors.error.withValues(alpha: 0.12);
      fg = AppColors.error;
      label = 'EXPIRED';
    } else {
      switch (status) {
        case SubscriptionStatus.active:
          bg = AppColors.primaryLight;
          fg = AppColors.primaryDark;
          label = 'ACTIVE';
          break;
        case SubscriptionStatus.upcoming:
          bg = AppColors.sky.withValues(alpha: 0.12);
          fg = AppColors.sky;
          label = 'UPCOMING';
          break;
        case SubscriptionStatus.trial:
          bg = AppColors.purple.withValues(alpha: 0.12);
          fg = AppColors.purple;
          label = 'TRIAL';
          break;
        case SubscriptionStatus.pending:
          bg = AppColors.warning.withValues(alpha: 0.12);
          fg = AppColors.warning;
          label = 'PENDING';
          break;
        case SubscriptionStatus.cancelled:
          bg = AppColors.textSecondary.withValues(alpha: 0.12);
          fg = AppColors.textSecondary;
          label = 'CANCELLED';
          break;
        default:
          bg = AppColors.pillBg;
          fg = AppColors.textSecondary;
          label = status.name.toUpperCase();
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fg.withValues(alpha: 0.25), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: fg,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}
