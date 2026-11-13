import 'package:material_ui/material_ui.dart';
import 'package:quickboom_crm_customer/core/theme/app_colors.dart';
import 'package:quickboom_crm_customer/roles/employee/models/employee_ssm_work_model.dart';
import 'package:quickboom_crm_customer/shared/widgets/app_app_bar.dart';
import 'package:quickboom_crm_customer/roles/employee/widgets/ssm/team_calendar_widget.dart';
import 'employee_ssm_work_detail_view.dart';

class EmployeeTeamCalendarView extends StatelessWidget {
  final int? initialTeamId;
  final DateTime? initialDate;

  const EmployeeTeamCalendarView({
    super.key,
    this.initialTeamId,
    this.initialDate,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: const AppAppBar(title: 'Team Calendar', showBackButton: true),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: TeamCalendarWidget(
            initialTeamId: initialTeamId,
            initialDate: initialDate,
            onWorkTap: (SSMWorkSchedule work) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EmployeeSSMWorkDetailView(workId: work.id),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
