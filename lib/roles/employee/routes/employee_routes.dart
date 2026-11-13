import 'package:material_ui/material_ui.dart';
import 'package:quickboom_crm_customer/core/models/permission_model.dart';
import 'package:quickboom_crm_customer/shared/widgets/permission_guarded_view.dart';
import 'package:quickboom_crm_customer/shared/views/data_capture/data_capture_home_screen.dart';
import 'package:quickboom_crm_customer/shared/views/leads/leads_view.dart';
import '../views/views.dart';
import 'package:quickboom_crm_customer/roles/employee/views/sidebar_views/customers_view.dart';

/// Centralized route definitions for Employee workspace.
class EmployeeRoutes {
  EmployeeRoutes._();

  static const String dashboard = '/employee/dashboard';
  static const String home = '/employee/home';
  static const String profile = '/employee/profile';
  static const String editProfile = '/employee/edit-profile';
  static const String requests = '/employee/requests';
  static const String salarySlip = '/employee/salary-slip';
  static const String commission = '/employee/commission';
  static const String settings = '/employee/settings';
  static const String notifications = '/employee/notifications';
  static const String visits = '/employee/visits';
  static const String schedule = '/employee/schedule';
  static const String ssmWorkList = '/employee/ssm-work';
  static const String teamCalendar = '/employee/team-calendar';
  static const String attendance = '/employee/attendance';
  static const String followUps = '/employee/follow-ups';
  static const String packages = '/employee/packages';
  static const String payments = '/employee/payments';
  static const String proposals = '/employee/proposals';
  static const String remoteWork = '/employee/remote-work';
  static const String tasks = '/employee/tasks';
  static const String work = '/employee/work';
  static const String dataCapture = '/employee/data-capture';
  static const String leads = '/employee/leads';
  static const String customers = '/employee/customers';

  static Map<String, WidgetBuilder> getRoutes() {
    return {
      dashboard: (_) => const DashboardView(),
      home: (_) => const EmployeeHomeView(),

      profile: (_) => const ProfileView(),
      editProfile: (_) => const EditProfileView(),
      requests: (_) => const PermissionGuardedView(
        moduleKey: AppModule.leave,
        moduleTitle: 'Requests & Leaves',
        child: RequestsView(),
      ),
      salarySlip: (_) => const PermissionGuardedView(
        moduleKey: AppModule.salary,
        moduleTitle: 'Salary Slips',
        child: SalarySlipView(),
      ),
      commission: (_) => const PermissionGuardedView(
        moduleKey: AppModule.commission,
        moduleTitle: 'My Commissions',
        child: EmployeeCommissionView(),
      ),
      settings: (_) => const PermissionGuardedView(
        moduleKey: AppModule.settings,
        moduleTitle: 'Settings',
        child: SettingsView(),
      ),
      notifications: (_) => const NotificationsView(),
      visits: (_) => const PermissionGuardedView(
        moduleKey: AppModule.visits,
        moduleTitle: 'Visits',
        child: VisitsView(),
      ),
      schedule: (_) => const PermissionGuardedView(
        moduleKey: AppModule.calendar,
        moduleTitle: 'Calendar',
        child: EmployeeScheduleView(),
      ),
      ssmWorkList: (_) => const PermissionGuardedView(
        moduleKey: AppModule.creativeWork,
        moduleTitle: 'Social Media Work',
        child: EmployeeSSMWorkListView(),
      ),
      teamCalendar: (_) => const PermissionGuardedView(
        moduleKey: AppModule.calendar,
        moduleTitle: 'Team Calendar',
        child: EmployeeScheduleView(),
      ),
      attendance: (_) => const PermissionGuardedView(
        moduleKey: AppModule.attendance,
        moduleTitle: 'Attendance',
        child: AttendanceView(),
      ),

      packages: (_) => const PermissionGuardedView(
        moduleKey: AppModule.packages,
        moduleTitle: 'Packages',
        child: PackagesView(),
      ),

      remoteWork: (_) => const PermissionGuardedView(
        moduleKey: AppModule.remoteWork,
        moduleTitle: 'Remote Work',
        child: RemoteWorkView(),
      ),
      tasks: (_) => const PermissionGuardedView(
        moduleKey: AppModule.tasks,
        moduleTitle: 'Assigned Tasks',
        child: TasksView(),
      ),

      dataCapture: (_) => const PermissionGuardedView(
        moduleKey: AppModule.dataCapture,
        moduleTitle: 'Data Capture',
        child: DataCaptureHomeScreen(),
      ),
      customers: (_) => const PermissionGuardedView(
        moduleKey: AppModule.customers,
        moduleTitle: 'Customers',
        child: CustomersView(),
      ),
      leads: (_) => const PermissionGuardedView(
        moduleKey: AppModule.leads,
        moduleTitle: 'Leads Pipeline',
        child: LeadsView(),
      ),
    };
  }
}
