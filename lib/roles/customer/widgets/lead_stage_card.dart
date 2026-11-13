import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/roles/customer/models/lead_model.dart';
import 'package:quickboom_crm_customer/roles/customer/models/lead_stage_model.dart';

/// Dedicated Lead Stage Card:
/// Shows current stage, dropdown arrow (if permitted to change),
/// and Next stage indicator. Uses dynamic backend stages.
class LeadStageCard extends StatelessWidget {
  final LeadModel lead;
  final LeadStageModel? currentStage;
  final LeadStageModel? nextStage;
  final List<LeadStageModel> stages;
  final bool canChangeStage;
  final VoidCallback? onChangeStageTap;
  final VoidCallback? onAdvanceNextStage;
  final bool isUpdating;

  const LeadStageCard({
    super.key,
    required this.lead,
    this.currentStage,
    this.nextStage,
    this.stages = const [],
    this.canChangeStage = false,
    this.onChangeStageTap,
    this.onAdvanceNextStage,
    this.isUpdating = false,
  });

  @override
  Widget build(BuildContext context) {
    final stageColor = currentStage?.stageColor ?? lead.stageColor;
    final stageName = currentStage?.name ?? lead.stageLabel;

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
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: stageColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Remix.git_commit_line,
                        size: 15,
                        color: stageColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Lead Stage',
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
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Current Stage Selector Tile (Dropdown)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: canChangeStage && !isUpdating ? onChangeStageTap : null,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: stageColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: stageColor.withValues(alpha: 0.3),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    // Colored Stage Dot
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: stageColor,
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Stage Name
                    Expanded(
                      child: Text(
                        stageName,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // Dropdown indicator if permitted
                    if (canChangeStage && onChangeStageTap != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: stageColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: stageColor.withValues(alpha: 0.25),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Change',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: stageColor,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Remix.arrow_down_s_line,
                              size: 16,
                              color: stageColor,
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Current',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Next Stage Section
          if (nextStage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(
                          Remix.arrow_right_line,
                          size: 14,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: RichText(
                            overflow: TextOverflow.ellipsis,
                            text: TextSpan(
                              style: GoogleFonts.outfit(fontSize: 13),
                              children: [
                                const TextSpan(
                                  text: 'Next: ',
                                  style: TextStyle(
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                TextSpan(
                                  text: nextStage!.name,
                                  style: const TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onAdvanceNextStage != null && !isUpdating) ...[
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: onAdvanceNextStage,
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 32),
                      ),
                      child: Text(
                        'Change',
                        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF2563EB)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
