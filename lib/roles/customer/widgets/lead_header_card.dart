import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';

import 'package:quickboom_crm_customer/roles/customer/models/lead_model.dart';
import 'package:quickboom_crm_customer/roles/customer/models/lead_stage_model.dart';

/// Compact Lead Header Card directly below the AppBar.
/// Shows:
/// - Initials avatar
/// - Business/Lead display name
/// - Contact person name
/// - Current stage indicator
/// - Phone (tap to call) & City
class LeadHeaderCard extends StatelessWidget {
  final LeadModel lead;
  final LeadStageModel? currentStage;

  const LeadHeaderCard({super.key, required this.lead, this.currentStage});

  String _getInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'L';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return trimmed.substring(0, trimmed.length >= 2 ? 2 : 1).toUpperCase();
  }

  static String _formatDate(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return '';
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
      return '${dt.day.toString().padLeft(2, '0')} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return isoDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final stageColor = currentStage?.stageColor ?? lead.stageColor;
    final stageName = currentStage?.name ?? lead.stageLabel;

    final hasContactPerson =
        lead.validContactPerson != null &&
        lead.validContactPerson!.isNotEmpty &&
        lead.validContactPerson != lead.displayName;

    final locationStr = [
      if (lead.city != null && lead.city!.trim().isNotEmpty) lead.city!.trim(),
      if (lead.state != null &&
          lead.state!.trim().isNotEmpty &&
          lead.state != lead.city)
        lead.state!.trim(),
    ].join(', ');

    final assignedName = lead.assignedToName?.trim();
    final hasAssigned =
        assignedName != null &&
        assignedName.isNotEmpty &&
        assignedName != 'Unassigned';
    final createdDateStr = _formatDate(lead.createdAt);

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
          // Top Row: Avatar + Business details + Stage
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                clipBehavior: Clip.antiAlias,
                child: _buildAvatar(),
              ),
              const SizedBox(width: 14),

              // Business Name, Contact Person, Stage & Source
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lead.displayTitle,
                      style: GoogleFonts.outfit(
                        fontSize: 16.5,
                        fontWeight: FontWeight.bold,
                        color: lead.displayName.isNotEmpty
                            ? const Color(0xFF0F172A)
                            : const Color(0xFF94A3B8),
                        fontStyle: lead.displayName.isNotEmpty
                            ? FontStyle.normal
                            : FontStyle.italic,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (hasContactPerson) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(
                            Remix.user_3_line,
                            size: 13,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              lead.validContactPerson ?? lead.fullName,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                color: const Color(0xFF475569),
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 6),

                    // Badges: Stage & Source
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Stage Pill Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: stageColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: stageColor.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: stageColor,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  stageName,
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: stageColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Source Badge
                        if (lead.source.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Remix.compass_3_line,
                                  size: 11,
                                  color: Color(0xFF64748B),
                                ),
                                const SizedBox(width: 3),
                                Flexible(
                                  child: Text(
                                    lead.sourceDisplayName,
                                    style: GoogleFonts.outfit(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF475569),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Metadata Sub-row: Assigned To & Created Date
          if (hasAssigned || createdDateStr.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: Row(
                children: [
                  if (hasAssigned) ...[
                    const Icon(
                      Remix.user_star_line,
                      size: 12,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      flex: createdDateStr.isNotEmpty ? 3 : 1,
                      child: Text(
                        'Assigned: $assignedName',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF475569),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  if (hasAssigned && createdDateStr.isNotEmpty)
                    Container(
                      height: 10,
                      width: 1,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      color: const Color(0xFFCBD5E1),
                    ),
                  if (createdDateStr.isNotEmpty) ...[
                    const Icon(
                      Remix.calendar_line,
                      size: 12,
                      color: Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      flex: hasAssigned ? 2 : 1,
                      child: Text(
                        'Created: $createdDateStr',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: const Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Bottom Info Row: Location
          if (locationStr.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Remix.map_pin_2_line,
                          size: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          locationStr,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: const Color(0xFF475569),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      color: const Color(0xFFE2E8F0),
      alignment: Alignment.center,
      child: Text(
        _getInitials(lead.displayName),
        style: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF334155),
        ),
      ),
    );
  }
}
