import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:remixicon/remixicon.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/roles/customer/models/lead_model.dart';
import 'package:quickboom_crm_customer/roles/customer/widgets/lead_notes_tab.dart';
import 'package:quickboom_crm_customer/roles/customer/widgets/lead_visits_tab.dart';

/// Modular Tab section for Lead Details containing:
/// Notes | Visits | Timeline | History
class LeadTabs extends StatelessWidget {
  final LeadModel lead;
  final TabController tabController;
  final bool canViewVisits;
  final VoidCallback? onScheduleVisit;
  final VoidCallback? onStartVisit;
  final VoidCallback? onCompleteVisit;
  final VoidCallback? onCreateProposal;
  final VoidCallback? onLogFinalCall;
  final VoidCallback? onRecordPayment;
  final VoidCallback? onStartWork;
  final VoidCallback? onChangeStage;

  const LeadTabs({
    super.key,
    required this.lead,
    required this.tabController,
    this.canViewVisits = true,
    this.onScheduleVisit,
    this.onStartVisit,
    this.onCompleteVisit,
    this.onCreateProposal,
    this.onLogFinalCall,
    this.onRecordPayment,
    this.onStartWork,
    this.onChangeStage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // TabBar Header Container
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TabBar(
            controller: tabController,
            indicatorColor: AppColors.primary,
            indicatorWeight: 3.0,
            indicatorSize: TabBarIndicatorSize.tab,
            labelColor: AppColors.primary,
            unselectedLabelColor: const Color(0xFF64748B),
            labelStyle: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            unselectedLabelStyle: GoogleFonts.outfit(
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
            tabs: const [
              Tab(
                icon: Icon(Remix.file_text_line, size: 18),
                text: 'Notes',
                iconMargin: EdgeInsets.only(bottom: 4),
              ),
              Tab(
                icon: Icon(Remix.calendar_check_line, size: 18),
                text: 'Visits',
                iconMargin: EdgeInsets.only(bottom: 4),
              ),
              Tab(
                icon: Icon(Remix.time_line, size: 18),
                text: 'Timeline',
                iconMargin: EdgeInsets.only(bottom: 4),
              ),
              Tab(
                icon: Icon(Remix.history_line, size: 18),
                text: 'History',
                iconMargin: EdgeInsets.only(bottom: 4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Tab Content Views
        AnimatedBuilder(
          animation: tabController,
          builder: (context, _) {
            switch (tabController.index) {
              case 0:
                return LeadNotesTab(lead: lead);
              case 1:
                return LeadVisitsTab(
                  lead: lead,
                  canViewVisits: canViewVisits,
                  onScheduleVisit: onScheduleVisit,
                );
              case 2:
                return _buildTimelineTab(lead);
              case 3:
                return _buildHistoryTab(lead);
              default:
                return const SizedBox.shrink();
            }
          },
        ),
      ],
    );
  }

  // ----------------------------------------------------
  // TAB 2: TIMELINE
  // ----------------------------------------------------
  Widget _buildTimelineTab(LeadModel lead) {
    if (lead.timeline.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          'No activity logged yet.',
          style: GoogleFonts.outfit(
            color: const Color(0xFF94A3B8),
            fontSize: 13,
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: lead.timeline.length,
      itemBuilder: (ctx, idx) {
        final item = lead.timeline[idx];
        final isLast = idx == lead.timeline.length - 1;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 52,
                    color: const Color(0xFFE2E8F0),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item.action.replaceAll('_', ' '),
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          item.createdAt.isNotEmpty
                              ? item.createdAt.split('T')[0]
                              : '',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.description,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ----------------------------------------------------
  // TAB 3: HISTORY
  // ----------------------------------------------------
  Widget _buildHistoryTab(LeadModel lead) {
    if (lead.statusHistory.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          'No status transitions recorded yet.',
          style: GoogleFonts.outfit(
            color: const Color(0xFF94A3B8),
            fontSize: 13,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: lead.statusHistory.length,
      itemBuilder: (ctx, idx) {
        final history = lead.statusHistory[idx];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Remix.arrow_right_line,
                  color: AppColors.primary,
                  size: 13,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stage: ${history.toStatus.replaceAll('_', ' ')}',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    if (history.notes != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        history.notes!,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      history.createdAt.split('T')[0],
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
