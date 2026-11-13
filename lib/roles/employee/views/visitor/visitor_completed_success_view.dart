import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';

class VisitorCompletedSuccessView extends StatelessWidget {
  final Map<String, dynamic> visit;
  final String customerName;
  final int rating;
  final String outcome;

  const VisitorCompletedSuccessView({
    super.key,
    required this.visit,
    required this.customerName,
    required this.rating,
    required this.outcome,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final timeStr =
        '${now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour)}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'PM' : 'AM'}';
    const months = [
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
    final dateStr = '${now.day} ${months[now.month - 1]} ${now.year}';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),

                // Green Success Badge
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFBBF7D0),
                      width: 4,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Remix.check_fill,
                      color: AppColors.primaryDark,
                      size: 48,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  'Visit Completed!',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your field visit has been successfully recorded.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),

                const SizedBox(height: 32),

                // Details Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.scaffoldBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Column(
                    children: [
                      _buildRow('Customer', customerName, isBold: true),
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: AppColors.borderLight),
                      const SizedBox(height: 12),
                      _buildRow('Date & Time', '$timeStr, $dateStr'),
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: AppColors.borderLight),
                      const SizedBox(height: 12),
                      _buildRow('Status', 'COMPLETED', isSuccess: true),
                      if (rating > 0) ...[
                        const SizedBox(height: 12),
                        const Divider(height: 1, color: AppColors.borderLight),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Customer Rating',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Row(
                              children: List.generate(
                                rating,
                                (_) => const Icon(
                                  Remix.star_fill,
                                  color: Color(0xFFF59E0B),
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (outcome.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Divider(height: 1, color: AppColors.borderLight),
                        const SizedBox(height: 12),
                        _buildRow('Outcome', outcome),
                      ],
                    ],
                  ),
                ),

                const Spacer(),

                // Back to Home Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    child: Text(
                      'BACK TO HOME',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRow(
    String label,
    String value, {
    bool isBold = false,
    bool isSuccess = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: isSuccess ? AppColors.primaryDark : AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
