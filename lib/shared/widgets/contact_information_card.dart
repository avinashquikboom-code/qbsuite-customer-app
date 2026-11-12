import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/core/utils/app_toast.dart';

/// Reusable Contact Information Card displaying business name, contact person,
/// mobile number with Call action, email with Email action, website with Open Website action,
/// and business address with Google Maps action.
class ContactInformationCard extends StatelessWidget {
  final String? businessName;
  final String? contactPerson;
  final String? phone;
  final String? email;
  final String? website;
  final String? address;
  final String? city;
  final String? state;
  final String? pincode;
  final String? country;
  final String? category;
  final String? googlePlaceId;
  final String? googleMapsUrl;
  final String title;

  const ContactInformationCard({
    super.key,
    this.businessName,
    this.contactPerson,
    this.phone,
    this.email,
    this.website,
    this.address,
    this.city,
    this.state,
    this.pincode,
    this.country,
    this.category,
    this.googlePlaceId,
    this.googleMapsUrl,
    this.title = 'Contact Information',
  });

  String get _fullAddress {
    return [
      address,
      city,
      state,
      pincode,
      country,
    ].where((s) => s != null && s.trim().isNotEmpty).join(', ').trim();
  }

  Future<void> _makeCall(BuildContext context, String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$clean');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else if (context.mounted) {
        _showError(context, 'Could not open phone dialer');
      }
    } catch (_) {
      if (context.mounted) {
        _showError(context, 'Could not open phone dialer');
      }
    }
  }

  Future<void> _openEmail(BuildContext context, String email) async {
    final uri = Uri.parse('mailto:${email.trim()}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else if (context.mounted) {
        _showError(context, 'Could not open email application');
      }
    } catch (_) {
      if (context.mounted) {
        _showError(context, 'Could not open email application');
      }
    }
  }

  Future<void> _openWebsite(BuildContext context, String rawUrl) async {
    var formatted = rawUrl.trim();
    if (!formatted.startsWith('http://') && !formatted.startsWith('https://')) {
      formatted = 'https://$formatted';
    }
    final uri = Uri.tryParse(formatted);
    try {
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (context.mounted) {
        _showError(context, 'Could not open website URL');
      }
    } catch (_) {
      if (context.mounted) {
        _showError(context, 'Could not open website URL');
      }
    }
  }

  Future<void> _openGoogleMaps(BuildContext context) async {
    try {
      if (googleMapsUrl != null && googleMapsUrl!.trim().isNotEmpty) {
        final uri = Uri.tryParse(googleMapsUrl!.trim());
        if (uri != null && await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
      }

      final queryParts = [
        if (businessName != null && businessName!.trim().isNotEmpty)
          businessName!.trim(),
        if (_fullAddress.isNotEmpty) _fullAddress,
      ];
      final query = queryParts.join(', ');

      if (query.isEmpty && (googlePlaceId == null || googlePlaceId!.isEmpty)) {
        if (context.mounted) {
          _showError(context, 'Address details are not available for Maps');
        }
        return;
      }

      final placeIdParam = googlePlaceId != null && googlePlaceId!.isNotEmpty
          ? '&query_place_id=${Uri.encodeComponent(googlePlaceId!)}'
          : '';
      final mapsUrl =
          'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}$placeIdParam';
      final uri = Uri.parse(mapsUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (context.mounted) {
        _showError(context, 'Could not open Google Maps');
      }
    } catch (_) {
      if (context.mounted) {
        _showError(context, 'Could not open Google Maps');
      }
    }
  }

  void _copyToClipboard(BuildContext context, String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied $label to clipboard'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showError(BuildContext context, String message) {
    try {
      AppToast.error(context, message);
    } catch (_) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasBusinessName =
        businessName != null && businessName!.trim().isNotEmpty;
    final hasPerson =
        contactPerson != null &&
        contactPerson!.trim().isNotEmpty &&
        contactPerson!.trim() != businessName?.trim();
    final hasPhone = phone != null && phone!.trim().isNotEmpty;
    final hasEmail = email != null && email!.trim().isNotEmpty;
    final hasWebsite = website != null && website!.trim().isNotEmpty;
    final hasAddress = _fullAddress.isNotEmpty;
    final hasCategory = category != null && category!.trim().isNotEmpty;

    final hasAnyContent =
        hasBusinessName ||
        hasPerson ||
        hasPhone ||
        hasEmail ||
        hasWebsite ||
        hasAddress ||
        hasCategory;

    if (!hasAnyContent) {
      return const SizedBox.shrink();
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Remix.contacts_book_2_line, size: 18, color: AppColors.primary),
          ),
          title: Text(
            title,
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          children: [
          // Business / Lead Name
          if (hasBusinessName) ...[
            _buildRow(
              context: context,
              icon: Remix.building_2_line,
              label: 'Business Name',
              value: businessName!.trim(),
              onCopy: () => _copyToClipboard(
                context,
                'Business Name',
                businessName!.trim(),
              ),
            ),
            const Divider(height: 18, color: Color(0xFFF1F5F9)),
          ],

          // Contact Person
          if (hasPerson) ...[
            _buildRow(
              context: context,
              icon: Remix.user_3_line,
              label: 'Contact Person',
              value: contactPerson!.trim(),
              onCopy: () => _copyToClipboard(
                context,
                'Contact Person',
                contactPerson!.trim(),
              ),
            ),
            const Divider(height: 18, color: Color(0xFFF1F5F9)),
          ],

          // Mobile Number with Call Action
          if (hasPhone) ...[
            _buildRow(
              context: context,
              icon: Remix.phone_line,
              label: 'Mobile Number',
              value: phone!.trim(),
              actionTooltip: 'Call Mobile Number',
              actionIcon: Remix.phone_fill,
              actionColor: AppColors.primary,
              onTap: () => _makeCall(context, phone!),
              onCopy: () =>
                  _copyToClipboard(context, 'Mobile Number', phone!.trim()),
            ),
            const Divider(height: 18, color: Color(0xFFF1F5F9)),
          ],

          // Email with Email Action
          if (hasEmail) ...[
            _buildRow(
              context: context,
              icon: Remix.mail_line,
              label: 'Email Address',
              value: email!.trim(),
              actionTooltip: 'Send Email',
              actionIcon: Remix.mail_send_line,
              actionColor: AppColors.primary,
              onTap: () => _openEmail(context, email!),
              onCopy: () =>
                  _copyToClipboard(context, 'Email Address', email!.trim()),
            ),
            const Divider(height: 18, color: Color(0xFFF1F5F9)),
          ],

          // Website with Open Website Action
          if (hasWebsite) ...[
            _buildRow(
              context: context,
              icon: Remix.global_line,
              label: 'Website',
              value: website!.trim(),
              actionTooltip: 'Open Website',
              actionIcon: Remix.external_link_line,
              actionColor: const Color(0xFF0284C7),
              onTap: () => _openWebsite(context, website!),
              onCopy: () =>
                  _copyToClipboard(context, 'Website', website!.trim()),
            ),
            const Divider(height: 18, color: Color(0xFFF1F5F9)),
          ],

          // Address with Google Maps Action
          if (hasAddress) ...[
            _buildRow(
              context: context,
              icon: Remix.map_pin_2_line,
              label: 'Business Address',
              value: _fullAddress,
              actionTooltip: 'Open in Google Maps',
              actionIcon: Remix.map_2_line,
              actionColor: const Color(0xFF10B981),
              onTap: () => _openGoogleMaps(context),
              onCopy: () => _copyToClipboard(context, 'Address', _fullAddress),
            ),
          ],

          // Category
          if (hasCategory) ...[
            if (hasAddress) const Divider(height: 18, color: Color(0xFFF1F5F9)),
            _buildRow(
              context: context,
              icon: Remix.price_tag_3_line,
              label: 'Category',
              value: category!.trim(),
              onCopy: () =>
                  _copyToClipboard(context, 'Category', category!.trim()),
            ),
          ],
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
    VoidCallback? onCopy,
    IconData? actionIcon,
    Color? actionColor,
    String? actionTooltip,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: const Color(0xFF475569)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: onTap != null
                            ? (actionColor ?? AppColors.primary)
                            : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              if (onCopy != null)
                IconButton(
                  icon: const Icon(
                    Remix.file_copy_line,
                    size: 15,
                    color: Color(0xFF94A3B8),
                  ),
                  tooltip: 'Copy $label',
                  onPressed: onCopy,
                ),
              if (actionIcon != null)
                IconButton(
                  icon: Icon(
                    actionIcon,
                    size: 18,
                    color: actionColor ?? AppColors.primary,
                  ),
                  tooltip: actionTooltip,
                  onPressed: onTap,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
