import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/roles/employee/viewmodels/employee_ssm_viewmodel.dart';
import 'package:quickboom_crm_customer/shared/widgets/app_app_bar.dart';
import 'package:quickboom_crm_customer/roles/employee/widgets/ssm/ssm_action_dialogs.dart';
import 'package:quickboom_crm_customer/roles/employee/widgets/ssm/ssm_work_card.dart';
import 'employee_ssm_work_detail_view.dart';

class SSMClientDetailView extends ConsumerWidget {
  final String customerName;

  const SSMClientDetailView({super.key, required this.customerName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ssmState = ref.watch(employeeSSMProvider);
    final clients = ssmState.myClients
        .where((c) => c.customerName == customerName)
        .toList();

    if (clients.isEmpty) {
      return const Scaffold(
        appBar: AppAppBar(title: 'Client Details'),
        body: Center(child: Text('Client not found.')),
      );
    }

    final client = clients.first;
    final initial = client.customerName.isNotEmpty
        ? client.customerName[0].toUpperCase()
        : 'C';

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: const AppAppBar(title: 'Client Details', showBackButton: true),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Card ──
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderLight),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.subtleGreenBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              initial,
                              style: GoogleFonts.outfit(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                client.customerName,
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                client.customerBusiness,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
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
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: AppColors.borderLight),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatChip(
                            'Active',
                            '${client.activeWorks.length}',
                            AppColors.primaryDark,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildStatChip(
                            'Upcoming',
                            '${client.upcomingWorks.length}',
                            const Color(0xFFB54708),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _buildStatChip(
                            'Completed',
                            '${client.completedWorks.length}',
                            const Color(0xFF175CD3),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // ── Social Media Account & Team Info ──
              Text(
                'ACCOUNT & TEAM DETAILS',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary.withValues(alpha: 0.8),
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  children: [
                    _buildDetailRow(
                      'Social Account',
                      client.socialMediaAccount,
                    ),
                    const Divider(height: 20, color: AppColors.borderLight),
                    _buildDetailRow('Platform', client.platform),
                    const Divider(height: 20, color: AppColors.borderLight),
                    _buildDetailRow('Assigned Team', client.assignedTeam),
                    const Divider(height: 20, color: AppColors.borderLight),
                    _buildDetailRow(
                      'Team Members',
                      client.assignedEmployees.join(', '),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── 1. Active Works Section ──
              _buildSectionTitle('ACTIVE WORKS (${client.activeWorks.length})'),
              const SizedBox(height: 10),
              if (client.activeWorks.isEmpty)
                _buildEmptyWorkBox(
                  'No active work in progress for this client.',
                )
              else
                Column(
                  children: client.activeWorks.map((work) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SSMWorkCard(
                        work: work,
                        targetDate: ssmState.todayDate,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  EmployeeSSMWorkDetailView(workId: work.id),
                            ),
                          );
                        },
                      ),
                    );
                  }).toList(),
                ),

              const SizedBox(height: 16),

              // ── 2. Upcoming Works Section ──
              _buildSectionTitle(
                'UPCOMING WORKS (${client.upcomingWorks.length})',
              ),
              const SizedBox(height: 10),
              if (client.upcomingWorks.isEmpty)
                _buildEmptyWorkBox('No upcoming works scheduled.')
              else
                Column(
                  children: client.upcomingWorks.map((work) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SSMWorkCard(
                        work: work,
                        targetDate: ssmState.todayDate,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  EmployeeSSMWorkDetailView(workId: work.id),
                            ),
                          );
                        },
                        onStartWork: () async {
                          final currentDay = work.getCurrentDayNumber(
                            ssmState.todayDate,
                          );
                          final confirmed =
                              await SSMActionDialogs.showStartWorkDialog(
                                context: context,
                                work: work,
                                currentDay: currentDay,
                              );

                          if (confirmed == true && context.mounted) {
                            ref
                                .read(employeeSSMProvider.notifier)
                                .startWork(work.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Work started! Day 1 is now in progress.',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                backgroundColor: AppColors.primaryDark,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),

              const SizedBox(height: 16),

              // ── 3. Completed Works Section ──
              _buildSectionTitle(
                'COMPLETED WORKS (${client.completedWorks.length})',
              ),
              const SizedBox(height: 10),
              if (client.completedWorks.isEmpty)
                _buildEmptyWorkBox('No completed works yet.')
              else
                Column(
                  children: client.completedWorks.map((work) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SSMWorkCard(
                        work: work,
                        targetDate: ssmState.todayDate,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  EmployeeSSMWorkDetailView(workId: work.id),
                            ),
                          );
                        },
                      ),
                    );
                  }).toList(),
                ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 11.5,
        fontWeight: FontWeight.w800,
        color: AppColors.textSecondary.withValues(alpha: 0.8),
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.scaffoldBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 10.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: GoogleFonts.outfit(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyWorkBox(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Text(
        message,
        style: GoogleFonts.outfit(
          fontSize: 12.5,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
