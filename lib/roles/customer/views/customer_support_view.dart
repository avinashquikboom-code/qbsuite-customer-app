import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/utils/app_toast.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

class CustomerSupportView extends StatelessWidget {
  static const String _supportPhone = '919284216276';
  static const String _supportPhoneDisplay = '+91 92842 16276';
  static const String _supportEmail = 'support@quikboom.in';

  final void Function(int tabIndex)? onNavigateToTab;

  const CustomerSupportView({super.key, this.onNavigateToTab});

  Future<void> _launchContact(
    BuildContext context,
    Uri uri,
    String unavailableMessage,
  ) async {
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        AppToast.error(context, unavailableMessage);
      }
    } catch (_) {
      if (context.mounted) {
        AppToast.error(context, unavailableMessage);
      }
    }
  }

  void _showRaiseTicketDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Submit Support Ticket',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: InputDecoration(
                labelText: 'Subject',
                labelStyle: GoogleFonts.outfit(fontSize: 13),
                hintText: 'e.g., Billing query or user limit upgrade',
                hintStyle: GoogleFonts.outfit(fontSize: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Description',
                labelStyle: GoogleFonts.outfit(fontSize: 13),
                hintText: 'Provide detailed information about your issue...',
                hintStyle: GoogleFonts.outfit(fontSize: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              AppToast.success(
                context,
                'Ticket #TK-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)} created. Our team will contact you shortly.',
                title: 'Ticket Submitted',
              );
            },
            child: Text(
              'Submit Ticket',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? const BackButton(color: AppColors.textPrimary)
            : null,
        automaticallyImplyLeading: false,
        title: Text(
          'Help & Support',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Contact Cards Grid
            Text(
              'DIRECT CHANNELS',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary.withValues(alpha: 0.8),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildChannelCard(
                    icon: Remix.whatsapp_line,
                    title: 'WhatsApp',
                    subtitle: _supportPhoneDisplay,
                    color: const Color(0xFF25D366),
                    onTap: () => _launchContact(
                      context,
                      Uri.parse('https://wa.me/$_supportPhone'),
                      'WhatsApp is unavailable on this device.',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildChannelCard(
                    icon: Remix.phone_line,
                    title: 'Call Desk',
                    subtitle: _supportPhoneDisplay,
                    color: AppColors.primaryDark,
                    onTap: () => _launchContact(
                      context,
                      Uri.parse('tel:+$_supportPhone'),
                      'Phone dialer is unavailable on this device.',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildChannelCard(
              icon: Remix.mail_send_line,
              title: 'Email Support',
              subtitle: '$_supportEmail • Response within 2 hours',
              color: AppColors.sky,
              onTap: () => _launchContact(
                context,
                Uri(scheme: 'mailto', path: _supportEmail),
                'Email application is unavailable on this device.',
              ),
            ),

            const SizedBox(height: 24),

            // Raise Ticket Banner
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Have a Custom Query?',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Submit a priority ticket for invoice questions, limits, or billing.',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton(
                          onPressed: () => _showRaiseTicketDialog(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primaryDark,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            'Submit a Ticket',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(
                    Remix.customer_service_2_fill,
                    size: 54,
                    color: Colors.white24,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // FAQs Section
            Text(
              'FREQUENTLY ASKED QUESTIONS',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary.withValues(alpha: 0.8),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),

            _buildFaqTile(
              'How does monthly vs yearly billing work?',
              'Monthly subscriptions renew every calendar month from your activation date. Yearly subscriptions grant 12 calendar months with substantial discounts.',
            ),
            _buildFaqTile(
              'Can I upgrade my plan at any time?',
              'Yes! You can change or upgrade your plan directly from the Plans tab. Your new limits and features take effect immediately upon confirmation.',
            ),
            _buildFaqTile(
              'Where can I find and download tax invoices?',
              'All purchase receipts and GST tax invoices are available in the Orders tab. You can preview, download, and print them at any time.',
            ),
            _buildFaqTile(
              'What happens if my subscription expires?',
              'When a subscription expires, your workspace enters an expired state. You can easily click "Renew Plan" from the Plans screen to restore full access without losing data.',
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: AppColors.textSecondary,
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
    );
  }

  Widget _buildFaqTile(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: ExpansionTile(
        shape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        title: Text(
          question,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        children: [
          Text(
            answer,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
