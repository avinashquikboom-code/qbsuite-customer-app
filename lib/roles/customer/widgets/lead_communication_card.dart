import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/roles/customer/models/lead_model.dart';
import 'package:quickboom_crm_customer/roles/customer/viewmodels/leads_viewmodel.dart';

/// Clean BPO Communications card displaying:
/// - Real backend counts: Emails, WhatsApp, Last communication timestamp
/// - Quick compose buttons: Email, WhatsApp, Send Both
/// Strictly adheres to backend source of truth (no local increments).
class LeadCommunicationCard extends ConsumerWidget {
  final LeadModel lead;
  final VoidCallback? onEmail;
  final VoidCallback? onWhatsApp;
  final VoidCallback? onSendBoth;

  const LeadCommunicationCard({
    super.key,
    required this.lead,
    this.onEmail,
    this.onWhatsApp,
    this.onSendBoth,
  });

  String _formatTimeAgo(DateTime? date) {
    if (date == null) return 'None yet';
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commsAsync = ref.watch(leadCommunicationsProvider(lead.id));
    final hasPhone = lead.phone != null && lead.phone!.trim().isNotEmpty;
    final hasEmail = lead.email != null && lead.email!.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Remix.chat_voice_line,
                  size: 15,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'BPO Communications',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Statistics Row: Emails | WhatsApp | Last
          commsAsync.maybeWhen(
            data: (res) {
              DateTime? latestDate;
              if (res.communications.isNotEmpty) {
                latestDate = res.communications.first.createdAt;
              }

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    // Emails
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Emails',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${res.summary.totalEmails}',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF4F46E5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 28,
                      color: const Color(0xFFE2E8F0),
                    ),

                    // WhatsApp
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'WhatsApp',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${res.summary.totalWhatsApp}',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF25D366),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 28,
                      color: const Color(0xFFE2E8F0),
                    ),

                    // Last
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Last',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatTimeAgo(latestDate),
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
            orElse: () => Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              alignment: Alignment.center,
              child: const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Actions Row: [ ✉ Email ] [ WhatsApp ] [ ⚡ Send Both ]
          Row(
            children: [
              // Email Button
              Expanded(
                child: _buildButton(
                  icon: Remix.mail_line,
                  label: 'Email',
                  color: const Color(0xFF4F46E5),
                  bgColor: const Color(0xFFEEF2FF),
                  borderColor: const Color(0xFFE0E7FF),
                  onTap: hasEmail ? onEmail : null,
                  enabled: hasEmail,
                ),
              ),
              const SizedBox(width: 8),

              // WhatsApp Button
              Expanded(
                child: _buildButton(
                  icon: Remix.whatsapp_line,
                  label: 'WhatsApp',
                  color: const Color(0xFF25D366),
                  bgColor: const Color(0xFFE8F5E9),
                  borderColor: const Color(0xFFC8E6C9),
                  onTap: hasPhone ? onWhatsApp : null,
                  enabled: hasPhone,
                ),
              ),
              const SizedBox(width: 8),

              // Send Both Button
              Expanded(
                child: _buildButton(
                  icon: Remix.flashlight_fill,
                  label: 'Send Both',
                  color: const Color(0xFFD97706),
                  bgColor: const Color(0xFFFEF3C7),
                  borderColor: const Color(0xFFFDE68A),
                  onTap: (hasPhone || hasEmail) ? onSendBoth : null,
                  enabled: hasPhone || hasEmail,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color bgColor,
    required Color borderColor,
    required VoidCallback? onTap,
    required bool enabled,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 38,
          decoration: BoxDecoration(
            color: enabled ? bgColor : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: enabled ? borderColor : const Color(0xFFE2E8F0),
            ),
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Tooltip(
            message: label,
            child: Icon(
              icon,
              size: 18,
              color: enabled ? color : const Color(0xFF94A3B8),
            ),
          ),
        ),
      ),
    );
  }
}
