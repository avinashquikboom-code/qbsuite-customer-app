import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/roles/employee/models/employee_ssm_work_model.dart';

class WorkStatusBadge extends StatelessWidget {
  final SSMWorkStatus status;

  const WorkStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color statusBgColor;
    Color statusTextColor;
    Color dotColor;

    switch (status) {
      case SSMWorkStatus.inProgress:
        statusBgColor = AppColors.primaryLight;
        statusTextColor = AppColors.primaryDark;
        dotColor = AppColors.primaryDark;
        break;
      case SSMWorkStatus.completed:
        statusBgColor = const Color(0xFFEFF8FF);
        statusTextColor = const Color(0xFF175CD3);
        dotColor = const Color(0xFF175CD3);
        break;
      case SSMWorkStatus.cancelled:
        statusBgColor = const Color(0xFFFEF3F2);
        statusTextColor = AppColors.error;
        dotColor = AppColors.error;
        break;
      case SSMWorkStatus.scheduled:
        statusBgColor = const Color(0xFFFEF0C7);
        statusTextColor = const Color(0xFFB54708);
        dotColor = const Color(0xFFB54708);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusBgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
          ),
          const SizedBox(width: 5),
          Text(
            status.displayName.toUpperCase(),
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: statusTextColor,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
