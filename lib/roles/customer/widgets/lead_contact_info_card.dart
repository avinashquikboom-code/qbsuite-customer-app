import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/roles/customer/models/lead_model.dart';

/// Contact Information Card:
/// Shows only available fields (hides missing fields; never shows 'N/A').
/// Tapping Phone calls, WhatsApp opens WhatsApp, Email opens mail client, Website opens browser, Address opens Google Maps.
class LeadContactInfoCard extends StatelessWidget {
  final LeadModel lead;
  final VoidCallback? onPhoneTap;
  final VoidCallback? onWhatsAppTap;
  final VoidCallback? onEmailTap;
  final void Function(String url)? onWebsiteTap;

  const LeadContactInfoCard({
    super.key,
    required this.lead,
    this.onPhoneTap,
    this.onWhatsAppTap,
    this.onEmailTap,
    this.onWebsiteTap,
  });

  Future<void> _openGoogleMaps(String address) async {
    final clean = address.trim();
    final query = Uri.encodeComponent(clean);
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final contactPerson = lead.validContactPerson;
    final hasPerson =
        contactPerson != null &&
        contactPerson.isNotEmpty &&
        contactPerson != lead.displayName;
    final hasPhone = lead.phone != null && lead.phone!.trim().isNotEmpty;
    final hasEmail = lead.email != null && lead.email!.trim().isNotEmpty;
    final hasWebsite = lead.website != null && lead.website!.trim().isNotEmpty;
    final hasAddress = lead.address != null && lead.address!.trim().isNotEmpty;
    final hasCity = lead.city != null && lead.city!.trim().isNotEmpty;
    final hasPincode = lead.pincode != null && lead.pincode!.trim().isNotEmpty;

    final hasCategory =
        lead.category != null && lead.category!.trim().isNotEmpty;

    // Check if at least one field is present
    final hasAnyContact =
        hasPerson ||
        hasCategory ||
        hasPhone ||
        hasEmail ||
        hasWebsite ||
        hasAddress ||
        hasCity ||
        hasPincode;

    if (!hasAnyContact) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
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
      child: Material(
        color: Colors.transparent,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: false,
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 0,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            leading: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Remix.building_2_line,
                size: 15,
                color: Color(0xFF475569),
              ),
            ),
            title: Text(
              'Contact Information',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
              overflow: TextOverflow.ellipsis,
            ),
            children: [
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 12),

              // Fields list (only available ones)
              if (hasCategory)
                _buildContactRow(
                  icon: Remix.store_2_line,
                  label: 'Category',
                  value: lead.category!,
                  iconColor: const Color(0xFF0284C7),
                ),
              if (hasPerson)
                _buildContactRow(
                  icon: Remix.user_3_line,
                  label: 'Contact Person',
                  value: contactPerson,
                  iconColor: const Color(0xFF64748B),
                ),

              if (hasPhone) ...[
                _buildContactRow(
                  icon: Remix.phone_line,
                  label: 'Phone',
                  value: lead.phone!,
                  iconColor: AppColors.primary,
                  onTap: onPhoneTap,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onWhatsAppTap != null)
                        IconButton(
                          icon: const Icon(
                            Remix.whatsapp_line,
                            size: 16,
                            color: Color(0xFF25D366),
                          ),
                          tooltip: 'WhatsApp',
                          constraints: const BoxConstraints(
                            minWidth: 28,
                            minHeight: 28,
                          ),
                          padding: EdgeInsets.zero,
                          onPressed: onWhatsAppTap,
                        ),
                      IconButton(
                        icon: const Icon(
                          Remix.phone_fill,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        tooltip: 'Call',
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                        padding: EdgeInsets.zero,
                        onPressed: onPhoneTap,
                      ),
                    ],
                  ),
                ),
              ],

              if (hasEmail)
                _buildContactRow(
                  icon: Remix.mail_line,
                  label: 'Email',
                  value: lead.email!,
                  iconColor: const Color(0xFF4F46E5),
                  onTap: onEmailTap,
                  trailing: IconButton(
                    icon: const Icon(
                      Remix.mail_send_line,
                      size: 14,
                      color: Color(0xFF4F46E5),
                    ),
                    tooltip: 'Send Email',
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: onEmailTap,
                  ),
                ),

              if (hasWebsite)
                _buildContactRow(
                  icon: Remix.global_line,
                  label: 'Website',
                  value: lead.website!,
                  iconColor: const Color(0xFF0284C7),
                  onTap: onWebsiteTap != null
                      ? () => onWebsiteTap!(lead.website!)
                      : null,
                  trailing: const Icon(
                    Remix.external_link_line,
                    size: 14,
                    color: Color(0xFF0284C7),
                  ),
                ),
              if (hasAddress)
                _buildContactRow(
                  icon: Remix.map_pin_line,
                  label: 'Address',
                  value: lead.address!,
                  iconColor: const Color(0xFF10B981),
                  onTap: () => _openGoogleMaps(lead.address!),
                  trailing: const Icon(
                    Remix.map_2_line,
                    size: 14,
                    color: Color(0xFF10B981),
                  ),
                ),

              if (hasCity)
                _buildContactRow(
                  icon: Remix.building_line,
                  label: 'City',
                  value: lead.city!,
                  iconColor: const Color(0xFF64748B),
                ),

              if (hasPincode)
                _buildContactRow(
                  icon: Remix.pushpin_line,
                  label: 'Pincode',
                  value: lead.pincode!,
                  iconColor: const Color(0xFF64748B),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactRow({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 14, color: iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                    Text(
                      value,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: onTap != null
                            ? AppColors.primary
                            : const Color(0xFF0F172A),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}
