import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quickboom_crm_customer/core/services/secure_storage_service.dart';
import 'package:remixicon/remixicon.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:quickboom_crm_customer/core/utils/app_toast.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/shared/models/data_capture_model.dart';
import 'package:quickboom_crm_customer/shared/services/data_capture_service.dart';



import 'package:quickboom_crm_customer/shared/models/lead_model.dart';
import 'package:quickboom_crm_customer/shared/viewmodels/leads_viewmodel.dart';
import 'package:quickboom_crm_customer/shared/viewmodels/lead_stages_viewmodel.dart';
import 'package:quickboom_crm_customer/roles/employee/views/dashboard_view.dart';

class ResultBusinessCard extends ConsumerStatefulWidget {
  final CapturedBusiness business;
  final ValueChanged<bool?> onToggleSelect;

  const ResultBusinessCard({
    super.key,
    required this.business,
    required this.onToggleSelect,
  });

  @override
  ConsumerState<ResultBusinessCard> createState() => _ResultBusinessCardState();
}

class _ResultBusinessCardState extends ConsumerState<ResultBusinessCard> {
  bool _isAdding = false;
  bool _isAdded = false;

  CapturedBusiness get business => widget.business;
  ValueChanged<bool?> get onToggleSelect => widget.onToggleSelect;

  Future<void> _launchUrl(String urlString) async {
    try {
      var target = urlString.trim();
      if (!target.startsWith('http://') &&
          !target.startsWith('https://') &&
          !target.startsWith('tel:') &&
          !target.startsWith('mailto:')) {
        target = 'https://$target';
      }
      final uri = Uri.parse(target);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  Future<void> _makeCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanPhone.isNotEmpty) {
      await _launchUrl('tel:$cleanPhone');
    }
  }

  Future<void> _handleAddToLead() async {
    if (_isAdding || _isAdded) return;
    setState(() => _isAdding = true);

    try {
      if (!mounted) return;

      final captureId =
          'dc_${business.googlePlaceId.isNotEmpty ? business.googlePlaceId : DateTime.now().millisecondsSinceEpoch}';

      final targetSourceRecordId =
          business.id?.toString() ??
          (business.sourceRecordId?.isNotEmpty == true
              ? business.sourceRecordId
              : (business.googlePlaceId.isNotEmpty
                    ? business.googlePlaceId
                    : null));

      // Preserve actual Data Capture source
      final resolvedSource =
          (business.source != null && business.source!.trim().isNotEmpty)
          ? business.source!.trim()
          : (business.googlePlaceId.isNotEmpty
                ? 'GOOGLE_PLACES'
                : 'GOOGLE_DISCOVERY');

      // Sanitize fields for CreateLeadDto validation
      final cleanPhone =
          (business.phone != 'N/A' &&
              business.phone.trim().isNotEmpty &&
              business.phone.trim().length >= 5)
          ? business.phone.trim()
          : null;

      final rawEmail = business.email?.trim();
      final cleanEmail =
          (rawEmail != null &&
              rawEmail.isNotEmpty &&
              rawEmail != 'N/A' &&
              rawEmail.contains('@') &&
              !rawEmail.contains(' '))
          ? rawEmail
          : null;

      final rawWebsite = business.website?.trim();
      final cleanWebsite =
          (rawWebsite != null &&
              rawWebsite.isNotEmpty &&
              rawWebsite != 'N/A' &&
              (rawWebsite.startsWith('http://') ||
                  rawWebsite.startsWith('https://') ||
                  rawWebsite.contains('.')))
          ? rawWebsite
          : null;

      final cleanAddress =
          (business.address.trim().isNotEmpty &&
              business.address.trim() != 'N/A')
          ? business.address.trim()
          : null;

      final empId = await SecureStorageService.getEmployeeId();
      final tenantId = await SecureStorageService.getCustomerId();

      debugPrint('''
[DATA_CAPTURE_TO_LEAD_SAFE]
Data Capture ID: ${business.id ?? 'N/A'}
sourceRecordId: ${targetSourceRecordId ?? 'N/A'}
googlePlaceId: ${business.googlePlaceId.isNotEmpty ? business.googlePlaceId : 'N/A'}
businessName: ${business.businessName}
phone: ${cleanPhone ?? 'N/A'}
email: ${cleanEmail ?? 'N/A'}
website: ${cleanWebsite ?? 'N/A'}
address: ${cleanAddress ?? 'N/A'}
source: $resolvedSource
employeeId: ${empId ?? 'N/A'}
companyId/tenantId: ${tenantId ?? 'N/A'}
''');

      // Section 3: The selected Data Capture result must use its REAL database ID
      final targetPlaceIdentifier =
          business.id?.toString() ??
          (business.googlePlaceId.isNotEmpty ? business.googlePlaceId : null);

      if (targetPlaceIdentifier == null || targetPlaceIdentifier.isEmpty) {
        if (mounted) {
          setState(() => _isAdding = false);
          AppToast.error(context, 'Data Capture record ID is missing.');
        }
        return;
      }

      final res = await DataCaptureService().createLeadFromPlace(
        targetPlaceIdentifier,
        captureRequestId: captureId,
        business: business,
      );

      // Section 9: Duplicate handling
      if (res['isDuplicate'] == true) {
        if (mounted) {
          setState(() {
            _isAdding = false;
            _isAdded = true;
          });
          business.isImported = true;
          AppToast.info(
            context,
            res['message'] ?? 'Lead already exists in CRM',
          );
        }
        return;
      }

      // Section 11 & 15: Store actual Lead ID and parse Lead
      final leadObj =
          res['lead'] ?? (res['data'] is Map ? res['data']['lead'] : null);
      if (leadObj is Map) {
        try {
          final createdModel = LeadModel.fromJson(
            Map<String, dynamic>.from(leadObj),
          );
          ref.read(leadsProvider.notifier).addOrUpdateLead(createdModel);
        } catch (e) {
          debugPrint('[RESULT_CARD] LeadModel parse error: $e');
        }
      }

      // Section 11 & 12: Invalidate Lead provider/ViewModel and refetch Lead Pipeline
      ref.invalidate(leadsProvider);
      await ref.read(leadsProvider.notifier).refreshLeads();
      await ref.read(leadStagesProvider.notifier).refresh();

      if (mounted) {
        setState(() {
          _isAdding = false;
          _isAdded = true;
        });
        business.isImported = true;
        AppToast.success(context, 'Lead Added from Data Capture!');

        // Section 11: Navigate to Lead Pipeline. Do NOT navigate to Lead Details automatically.
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => const DashboardView(initialTabIndex: 2),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAdding = false);
        final rawMsg = e.toString();
        final cleanMsg = rawMsg.startsWith('Exception: ')
            ? rawMsg.substring(11)
            : rawMsg;
        AppToast.error(context, cleanMsg);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = business.isSelected;
    final hasPhone = business.phone.isNotEmpty && business.phone != 'N/A';
    final hasWebsite = business.website != null && business.website!.isNotEmpty;
    final hasMap =
        business.googleMapsUrl != null && business.googleMapsUrl!.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.border,
          width: isSelected ? 1.8 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.10)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: Checkbox + Name + Category + Rating ──────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 14, 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Checkbox
                SizedBox(
                  width: 40,
                  child: Checkbox(
                    value: isSelected,
                    activeColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: onToggleSelect,
                  ),
                ),
                // Business info
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          business.businessName.isNotEmpty
                              ? business.businessName
                              : 'No business name available',
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: business.businessName.isNotEmpty
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            fontStyle: business.businessName.isNotEmpty
                                ? FontStyle.normal
                                : FontStyle.italic,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            // Category chip
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                business.category,
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ),
                            // Rating
                            if (business.rating != null)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    color: Colors.amber,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${business.rating}',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  if (business.reviewCount != null)
                                    Text(
                                      ' (${business.reviewCount})',
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Address ─────────────────────────────────────────────────
          if (business.address.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.location_on_outlined,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      business.address,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

          // ── Phone ────────────────────────────────────────────────────
          if (hasPhone)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
              child: Row(
                children: [
                  const Icon(
                    Icons.phone_outlined,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      business.phone,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

          // ── Social Media Badges (Genuine platforms only) ───────────────
          if (business.socialMedia != null &&
              business.socialMedia!.isNotEmpty) ...[
            Builder(
              builder: (context) {
                final sm = business.socialMedia!;
                final items = <Widget>[];

                void addSocial(
                  String key,
                  IconData icon,
                  Color color,
                  String name,
                ) {
                  final val = sm[key]?.toString();
                  if (val != null && val.trim().isNotEmpty && val != 'null') {
                    items.add(
                      _SocialBadge(
                        icon: icon,
                        color: color,
                        label: name,
                        url: val,
                        onTap: () => _launchUrl(val),
                      ),
                    );
                  }
                }

                addSocial(
                  'instagram',
                  Remix.instagram_line,
                  const Color(0xFFE1306C),
                  'Instagram',
                );
                addSocial(
                  'facebook',
                  Remix.facebook_fill,
                  const Color(0xFF1877F2),
                  'Facebook',
                );
                addSocial(
                  'linkedin',
                  Remix.linkedin_fill,
                  const Color(0xFF0A66C2),
                  'LinkedIn',
                );
                final tw = sm['twitter']?.toString() ?? sm['x']?.toString();
                if (tw != null && tw.trim().isNotEmpty && tw != 'null') {
                  items.add(
                    _SocialBadge(
                      icon: Remix.twitter_x_line,
                      color: const Color(0xFF0F1419),
                      label: 'X (Twitter)',
                      url: tw,
                      onTap: () => _launchUrl(tw),
                    ),
                  );
                }
                addSocial(
                  'youtube',
                  Remix.youtube_fill,
                  const Color(0xFFFF0000),
                  'YouTube',
                );
                addSocial(
                  'tiktok',
                  Remix.tiktok_fill,
                  const Color(0xFF000000),
                  'TikTok',
                );

                if (items.isEmpty) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'Social:',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: items,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],

          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.border),

          // ── Action Toolbar ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left: quick-action icon buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasPhone)
                      _ActionIconBtn(
                        icon: Icons.call_rounded,
                        color: AppColors.primary,
                        bgColor: AppColors.primaryLight,
                        tooltip: 'Call',
                        onTap: () => _makeCall(business.phone),
                      ),
                    if (hasWebsite) ...[
                      const SizedBox(width: 4),
                      _ActionIconBtn(
                        icon: Icons.language_rounded,
                        color: AppColors.secondary,
                        bgColor: AppColors.secondary.withValues(alpha: 0.1),
                        tooltip: 'Website',
                        onTap: () => _launchUrl(business.website!),
                      ),
                    ],
                    if (hasMap) ...[
                      const SizedBox(width: 4),
                      _ActionIconBtn(
                        icon: Icons.map_rounded,
                        color: Colors.blueAccent,
                        bgColor: Colors.blueAccent.withValues(alpha: 0.1),
                        tooltip: 'Maps',
                        onTap: () => _launchUrl(business.googleMapsUrl!),
                      ),
                    ],
                  ],
                ),
                const SizedBox(width: 4),

                // Right: Add Lead + Select
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _CompactTextBtn(
                          label: _isAdded
                              ? 'Added'
                              : _isAdding
                              ? 'Adding...'
                              : 'Add Lead',
                          icon: _isAdded
                              ? Icons.check_circle_rounded
                              : _isAdding
                              ? Icons.hourglass_top_rounded
                              : Icons.person_add_alt_1_rounded,
                          color: _isAdded
                              ? AppColors.success
                              : _isAdding
                              ? AppColors.textSecondary
                              : AppColors.primary,
                          onTap: (_isAdding || _isAdded)
                              ? () {}
                              : _handleAddToLead,
                        ),
                        const SizedBox(width: 2),
                        _CompactTextBtn(
                          label: isSelected ? 'Selected' : 'Select',
                          icon: isSelected
                              ? Icons.check_box_rounded
                              : Icons.check_box_outline_blank_rounded,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          onTap: () => onToggleSelect(!isSelected),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reusable icon action button ──────────────────────────────────────────────
class _ActionIconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bgColor;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionIconBtn({
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
      ),
    );
  }
}

// ── Reusable compact text button ─────────────────────────────────────────────
class _CompactTextBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _CompactTextBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reusable social badge button ─────────────────────────────────────────────
class _SocialBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String url;
  final VoidCallback onTap;

  const _SocialBadge({
    required this.icon,
    required this.color,
    required this.label,
    required this.url,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
            child: Center(child: Icon(icon, size: 14, color: color)),
          ),
        ),
      ),
    );
  }
}
