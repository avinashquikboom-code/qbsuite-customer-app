import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:quickboom_crm_customer/core/network/api_client.dart';
import 'package:quickboom_crm_customer/core/network/app_url.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/roles/customer/models/customer_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Blinking status dot widget
// ─────────────────────────────────────────────────────────────────────────────

class _BlinkingDot extends StatefulWidget {
  final Color color;

  const _BlinkingDot({required this.color});

  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _opacity = Tween<double>(
      begin: 0.35,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

    // Avoid infinite animation loop during widget tests to allow pumpAndSettle
    final isTesting = WidgetsBinding.instance.runtimeType.toString().contains(
      'Test',
    );
    if (!isTesting) {
      _ctrl.repeat(reverse: true);
    } else {
      _ctrl.value = 1.0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CustomerCard widget
// ─────────────────────────────────────────────────────────────────────────────

class CustomerCard extends ConsumerWidget {
  final CustomerModel customer;
  final VoidCallback? onTap;

  const CustomerCard({super.key, required this.customer, this.onTap});

  /// Format ISO date string into "DD MMM YYYY" (e.g. "19 Sep 2026")
  static String formatDate(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return 'N/A';
    try {
      final dt = DateTime.parse(isoDate);
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
      final day = dt.day.toString().padLeft(2, '0');
      final month = months[dt.month - 1];
      return '$day $month ${dt.year}';
    } catch (_) {
      return isoDate;
    }
  }

  /// Format number into Indian currency format (e.g. ₹2,500, ₹10,000, ₹1,25,000)
  static String formatIndianCurrency(double amount) {
    final rounded = amount.round();
    final str = rounded.toString();
    if (str.length <= 3) return '₹$str';

    final lastThree = str.substring(str.length - 3);
    final remaining = str.substring(0, str.length - 3);
    final formattedRemaining = remaining.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{2})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
    return '₹$formattedRemaining,$lastThree';
  }

  void _callNumber(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.isEmpty) return;
    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _openWhatsApp(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanPhone.isEmpty) return;
    final uri = Uri.parse('https://wa.me/$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String? _getSubtitleText() {
    return customer.displaySubtitle;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ── Status theming ────────────────────────────────────────────────────
    final isActive = customer.isSubscriptionActive;

    final Color statusBg;
    final Color statusBorder;
    final Color statusDot;
    final Color statusText;
    final String statusLabel;

    if (customer.hasUpcomingCall) {
      statusBg = const Color(0xFFFFF7ED);
      statusBorder = const Color(0xFFFED7AA);
      statusDot = const Color(0xFFF59E0B);
      statusText = const Color(0xFFB45309);
      statusLabel = 'Upcoming';
    } else if (isActive) {
      statusBg = const Color(0xFFECFDF5);
      statusBorder = const Color(0xFFA7F3D0);
      statusDot = const Color(0xFF10B981);
      statusText = const Color(0xFF065F46);
      statusLabel = 'Active';
    } else {
      statusBg = const Color(0xFFFEF2F2);
      statusBorder = const Color(0xFFFECACA);
      statusDot = const Color(0xFFEF4444);
      statusText = const Color(0xFF991B1B);
      statusLabel = 'Inactive';
    }

    // ── Avatar initial ────────────────────────────────────────────────────
    final titleText = customer.displayTitle;
    final initial = titleText.trim().isNotEmpty
        ? titleText.trim()[0].toUpperCase()
        : 'C';

    // ── Subtitle (e.g. distinct Customer Name / Contact Person) ───────────
    final subtitleText = _getSubtitleText();

    // ── Plan info ─────────────────────────────────────────────────────────
    final hasPlan =
        customer.planName != null &&
        customer.planName!.isNotEmpty &&
        customer.planName != 'No Active Plan';

    final planDisplayName = hasPlan
        ? customer.planName!
        : (customer.leadStageName != null && customer.leadStageName!.isNotEmpty
              ? 'Stage: ${customer.leadStageName}'
              : 'No Active Plan');
    final hasUpcomingCommission =
        customer.upcomingCommission != null && customer.upcomingCommission! > 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap:
              onTap ??
              () {
                _openCustomerDetails(context, ref);
              },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Row 1: Header (Avatar + Customer Name + Status Badge) ───
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Fixed Avatar (42x42)
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withValues(alpha: 0.85),
                            AppColors.primary,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initial,
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Customer Name & Optional Contact/Secondary Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            titleText,
                            style: GoogleFonts.outfit(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (subtitleText != null &&
                              subtitleText.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Remix.user_3_line,
                                  size: 12,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    subtitleText,
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (customer.isConvertedFromLead) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3E8FF),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: const Color(0xFFDDD6FE),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Remix.user_received_2_line,
                                    size: 10,
                                    color: Color(0xFF7C3AED),
                                  ),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      'Converted from Lead',
                                      style: GoogleFonts.outfit(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF6D28D9),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Fixed-height, non-shrinking Status Badge with Blinking Dot
                    Container(
                      height: 26,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusBorder),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _BlinkingDot(color: statusDot),
                          const SizedBox(width: 5),
                          Text(
                            statusLabel,
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: statusText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // ── Row 2: Plan Section (Consistent Structure & Rhythm) ────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: (hasPlan || hasUpcomingCommission)
                        ? const Color(0xFFF0FDF4)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: (hasPlan || hasUpcomingCommission)
                          ? const Color(0xFFBBF7D0)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Plan name row
                      Row(
                        children: [
                          Icon(
                            hasPlan
                                ? Remix.shield_check_line
                                : Remix.shield_line,
                            size: 14,
                            color: hasPlan
                                ? const Color(0xFF10B981)
                                : AppColors.textPlaceholder,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              planDisplayName,
                              style: GoogleFonts.outfit(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: hasPlan
                                    ? const Color(0xFF065F46)
                                    : AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      // Start / Expires dates — only when dates are available
                      if (hasPlan &&
                          (customer.subscriptionStartDate != null ||
                              customer.subscriptionEndDate != null)) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            // Started
                            if (customer.subscriptionStartDate != null) ...[
                              const Icon(
                                Remix.calendar_check_line,
                                size: 11,
                                color: AppColors.textPlaceholder,
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  'Started: ${formatDate(customer.subscriptionStartDate)}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                            if (customer.subscriptionStartDate != null &&
                                customer.subscriptionEndDate != null)
                              const SizedBox(width: 8),
                            // Expires
                            if (customer.subscriptionEndDate != null) ...[
                              Icon(
                                Remix.calendar_close_line,
                                size: 11,
                                color: isActive
                                    ? AppColors.textPlaceholder
                                    : const Color(0xFFEF4444),
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  'Expires: ${formatDate(customer.subscriptionEndDate)}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    color: isActive
                                        ? AppColors.textSecondary
                                        : const Color(0xFFEF4444),
                                    fontWeight: isActive
                                        ? FontWeight.normal
                                        : FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],

                      // Upcoming Commission row (Only when eligible & commission > 0)
                      if (hasUpcomingCommission) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Remix.money_rupee_circle_line,
                              size: 13,
                              color: Color(0xFF10B981),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: 'Upcoming Commission: ',
                                      style: GoogleFonts.outfit(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF065F46),
                                      ),
                                    ),
                                    TextSpan(
                                      text: formatIndianCurrency(
                                        customer.upcomingCommission!,
                                      ),
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF047857),
                                      ),
                                    ),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (!hasPlan &&
                          customer.assignedEmployee.isNotEmpty &&
                          customer.assignedEmployee != 'Unassigned') ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Remix.user_star_line,
                              size: 11,
                              color: AppColors.textPlaceholder,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Assigned: ${customer.assignedEmployee}',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // ── Row 2b: Upcoming Call Section (When customer has upcoming/final call) ──
                if (customer.hasUpcomingCall) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFED7AA)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Remix.phone_line,
                            size: 14,
                            color: Color(0xFFD97706),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                customer.upcomingCallType ?? 'Final Call',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFB45309),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 1),
                              Text(
                                '${customer.upcomingCallDate ?? "Upcoming"}${customer.upcomingCallTime != null && customer.upcomingCallTime!.isNotEmpty ? " • ${customer.upcomingCallTime}" : ""}',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFFD97706),
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
                ],

                const SizedBox(height: 12),

                // ── Row 3: Bottom Row Alignment (Phone, Location, Actions) ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // LEFT: Phone (Expanded, 1 line, ellipsis)
                    Expanded(
                      flex: 5,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Remix.phone_line,
                            size: 13,
                            color: AppColors.textPlaceholder,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              customer.mobile.isNotEmpty
                                  ? customer.mobile
                                  : 'N/A',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    // CENTER: Location (Expanded, 1 line, ellipsis, fallback N/A)
                    Expanded(
                      flex: 4,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Remix.map_pin_2_line,
                            size: 13,
                            color: AppColors.textPlaceholder,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              customer.city.isNotEmpty ? customer.city : 'N/A',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    // RIGHT: WhatsApp + Call buttons (Fixed-size, equal dimensions 32x32)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // WhatsApp button
                        InkWell(
                          onTap: customer.mobile.isNotEmpty
                              ? () => _openWhatsApp(customer.mobile)
                              : null,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF25D366,
                              ).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Remix.whatsapp_line,
                              size: 16,
                              color: Color(0xFF25D366),
                            ),
                          ),
                        ),

                        const SizedBox(width: 6),

                        // Call button
                        InkWell(
                          onTap: customer.mobile.isNotEmpty
                              ? () => _callNumber(customer.mobile)
                              : null,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Remix.phone_fill,
                              size: 15,
                              color: AppColors.primary,
                            ),
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
      ),
    );
  }

  void _openCustomerDetails(BuildContext context, WidgetRef ref) async {
    final cleanId = customer.customerId
        .replaceAll(RegExp(r'^[^\d]+'), '')
        .trim();
    if (cleanId.isEmpty) return;

    try {
      final client = ApiClient();
      final res = await client.get(AppUrl.customerDetails(cleanId));
      if (!context.mounted) return;
      if (res.statusCode == 200 && res.data != null) {
        final dynamic raw = res.data;
        final Map<String, dynamic> data =
            (raw is Map<String, dynamic> && raw['data'] is Map<String, dynamic>)
            ? raw['data'] as Map<String, dynamic>
            : (raw is Map<String, dynamic> ? raw : {});
        _showDetailsModal(context, data);
      }
    } on DioException catch (dioErr) {
      if (!context.mounted) return;
      if (dioErr.response?.statusCode == 404) {
        // If 404, it might be an unconverted upcoming lead; show modal with customer's local model details
        _showDetailsModal(context, {});
        return;
      }
    } catch (_) {
      if (context.mounted) {
        _showDetailsModal(context, {});
      }
    }
  }

  void _showDetailsModal(BuildContext context, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Color(0xFFDCFCE7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Remix.user_star_line,
                      size: 20,
                      color: Color(0xFF16A34A),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.displayTitle,
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          customer.customerStatus,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              const SizedBox(height: 12),
              if (customer.contactPerson.isNotEmpty)
                _buildInfoRow('Contact Person', customer.contactPerson),
              if (customer.mobile.isNotEmpty)
                _buildInfoRow('Phone', customer.mobile),
              if (customer.email.isNotEmpty && customer.email != 'N/A')
                _buildInfoRow('Email', customer.email),
              if (customer.city.isNotEmpty && customer.city != 'N/A')
                _buildInfoRow(
                  'Location',
                  '${customer.city}, ${customer.state}',
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: const Color(0xFF64748B),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }
}
