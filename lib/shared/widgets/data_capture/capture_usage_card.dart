import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/shared/models/data_capture_model.dart';

class CaptureUsageCard extends StatelessWidget {
  final DataCaptureUsage usage;

  const CaptureUsageCard({super.key, required this.usage});

  @override
  Widget build(BuildContext context) {
    final used = usage.totalLeadsCaptured;
    final limit = usage.quotaLimit > 0 ? usage.quotaLimit : 1000;
    final remaining = usage.quotaRemaining;
    final progress = (used / limit).clamp(0.0, 1.0);
    final isExhausted = remaining <= 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isExhausted ? AppColors.error : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
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
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isExhausted
                            ? AppColors.error.withValues(alpha: 0.1)
                            : AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isExhausted
                            ? Icons.warning_amber_rounded
                            : Icons.pie_chart_rounded,
                        color: isExhausted
                            ? AppColors.error
                            : AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SUBSCRIPTION USAGE',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.8,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Data Capture Quota',
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isExhausted
                      ? AppColors.error.withValues(alpha: 0.1)
                      : AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isExhausted ? 'Quota Limit Reached' : '$remaining Leads Left',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isExhausted
                        ? AppColors.error
                        : AppColors.primaryDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Linear Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(
                isExhausted
                    ? AppColors.error
                    : (progress > 0.85 ? AppColors.warning : AppColors.primary),
              ),
            ),
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Used: $used / $limit',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                '${(progress * 100).toInt()}% consumed',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),

          if (isExhausted) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.error,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Data Capture limit reached. Please contact your administrator or upgrade your plan.',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
