import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/roles/customer/models/lead_model.dart';

/// Dedicated Visits tab for Lead Details.
/// Lists existing Visit records already attached to this Lead.
class LeadVisitsTab extends StatelessWidget {
  final LeadModel lead;
  final bool canViewVisits;
  final VoidCallback? onScheduleVisit;

  const LeadVisitsTab({
    super.key,
    required this.lead,
    this.canViewVisits = true,
    this.onScheduleVisit,
  });

  static String _formatDate(String raw) {
    if (raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
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
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return raw.split('T').first;
    }
  }

  static String _formatDateTime(String raw) {
    if (raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
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
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final amPm = dt.hour >= 12 ? 'PM' : 'AM';
      final minute = dt.minute.toString().padLeft(2, '0');
      return '${dt.day} ${months[dt.month - 1]} ${dt.year} • $hour:$minute $amPm';
    } catch (_) {
      return raw;
    }
  }

  static String _displayStatus(String raw) {
    final cleaned = raw.trim().replaceAll('_', ' ');
    if (cleaned.isEmpty) return raw;
    return cleaned
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  Color _statusBg(String status) {
    final s = status.toUpperCase();
    if (s == 'IN_PROGRESS' || s == 'ONGOING') return const Color(0xFFFEF3C7);
    if (s == 'COMPLETED') return const Color(0xFFECFDF5);
    if (s == 'SCHEDULED') return const Color(0xFFEEF2FF);
    return const Color(0xFFF1F5F9);
  }

  Color _statusFg(String status) {
    final s = status.toUpperCase();
    if (s == 'IN_PROGRESS' || s == 'ONGOING') return const Color(0xFFD97706);
    if (s == 'COMPLETED') return const Color(0xFF047857);
    if (s == 'SCHEDULED') return const Color(0xFF4F46E5);
    return const Color(0xFF64748B);
  }

  @override
  Widget build(BuildContext context) {
    if (!canViewVisits) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Text(
          'Visit information is not available.',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            color: const Color(0xFF94A3B8),
            fontSize: 13,
          ),
        ),
      );
    }

    final visits = List<LeadVisitModel>.from(lead.visits);
    visits.sort((a, b) {
      final aDate = DateTime.tryParse(a.date) ?? DateTime.tryParse(a.createdAt);
      final bDate = DateTime.tryParse(b.date) ?? DateTime.tryParse(b.createdAt);
      if (aDate != null && bDate != null) {
        return bDate.compareTo(aDate);
      }
      return b.createdAt.compareTo(a.createdAt);
    });

    if (visits.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Remix.calendar_check_line,
                size: 36,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No Visits Scheduled',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Visits scheduled for this lead will appear here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            if (onScheduleVisit != null) ...[
              const SizedBox(height: 18),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Remix.add_line, size: 16),
                label: Text(
                  'Schedule Visit',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: onScheduleVisit,
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onScheduleVisit != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Field Visits (${visits.length})',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                InkWell(
                  onTap: onScheduleVisit,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Remix.add_line,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Schedule Visit',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 4),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: visits.length,
          itemBuilder: (context, index) => _buildVisitCard(visits[index]),
        ),
      ],
    );
  }

  Widget _buildVisitCard(LeadVisitModel visit) {
    final dateLabel = _formatDate(visit.date);
    final timeLabel = (visit.time != null && visit.time!.trim().isNotEmpty)
        ? visit.time!.trim()
        : null;
    final completedAtLabel =
        (visit.completedAt != null && visit.completedAt!.trim().isNotEmpty)
        ? _formatDateTime(visit.completedAt!)
        : null;
    final visitor = visit.assignedEmployee?.trim();
    final completedBy = visit.completedBy?.trim();
    final notes = visit.notes?.trim();
    final outcome = visit.outcome?.trim();
    final isCompleted = visit.status.toUpperCase() == 'COMPLETED';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusBg(visit.status),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _displayStatus(visit.status),
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _statusFg(visit.status),
                  ),
                ),
              ),
            ],
          ),
          if (dateLabel.isNotEmpty || timeLabel != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Remix.time_line, size: 14, color: Color(0xFF4F46E5)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    [
                      if (dateLabel.isNotEmpty) dateLabel,
                      if (timeLabel != null) timeLabel,
                    ].join(' • '),
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (visit.purpose.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              visit.purpose.trim(),
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF334155),
              ),
            ),
          ],
          if (visitor != null && visitor.isNotEmpty) ...[
            const SizedBox(height: 6),
            _metaRow(Remix.user_3_line, 'Visitor: $visitor'),
          ],
          if (isCompleted && completedBy != null && completedBy.isNotEmpty) ...[
            const SizedBox(height: 4),
            _metaRow(
              Remix.checkbox_circle_line,
              'Completed By: $completedBy',
              color: const Color(0xFF047857),
            ),
          ],
          if (completedAtLabel != null && completedAtLabel.isNotEmpty) ...[
            const SizedBox(height: 4),
            _metaRow(Remix.check_double_line, completedAtLabel),
          ],
          if (visit.location.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            _metaRow(Remix.map_pin_2_line, visit.location.trim()),
          ],
          if (notes != null &&
              notes.isNotEmpty &&
              notes != 'Visit scheduled from CRM') ...[
            const SizedBox(height: 12),
            Text(
              'Visitor Comment:',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              notes,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppColors.textPrimary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (outcome != null && outcome.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Outcome: $outcome',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF047857),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _metaRow(IconData icon, String text, {Color? color}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 13, color: color ?? const Color(0xFF94A3B8)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color ?? const Color(0xFF64748B),
            ),
          ),
        ),
      ],
    );
  }
}
