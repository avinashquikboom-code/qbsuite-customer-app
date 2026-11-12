/// Centralized AppBar title constants and route-to-title mappings
/// across the QuikBoom Flutter application.
class AppBarTitles {
  // Root Dashboard & Core Navigation
  static const String dashboard = 'Dashboard';
  static const String home = 'Home';
  static const String profile = 'Profile';
  static const String editProfile = 'Edit Profile';
  static const String settings = 'Settings';
  static const String notifications = 'Notifications';

  // Attendance Module
  static const String attendance = 'Attendance Logs';
  static const String attendanceHistory = 'Attendance History';
  static const String punchIn = 'Punch In';
  static const String punchOut = 'Punch Out';
  static const String breakLog = 'Break Log';

  // Field Visits Module
  static const String visits = 'Field Visits';
  static const String createVisit = 'Create Visit';
  static const String visitDetails = 'Visit Details';
  static const String visitHistory = 'Visit History';

  // Requests & Applications Module
  static const String requests = 'Requests & Applications';
  static const String applyLeave = 'Apply Leave';
  static const String leaveHistory = 'Leave History';
  static const String applyRemoteWork = 'Apply Remote Work';
  static const String remoteWorkHistory = 'Remote Work History';

  // Leads Module
  static const String leadsPipeline = 'Leads Pipeline';
  static const String addLead = 'Add New Lead';
  static const String myLeads = 'My Leads';
  static const String leadDetails = 'Lead Details';

  // Data Capture Module
  static const String dataCapture = 'Data Capture';
  static const String newDataCapture = 'New Data Capture';
  static const String captureResults = 'Captured Results';
  static const String captureHistory = 'Extraction History';
  static const String captureDetails = 'Extraction Details';

  // Payroll & Payslips Module
  static const String payroll = 'Payroll';
  static const String salarySlips = 'Salary Slips';
  static const String salarySlipDetails = 'Salary Slip Details';

  // Auth Module
  static const String login = 'Sign In';
  static const String forgotPassword = 'Forgot Password';
  static const String resetPassword = 'Reset Password';
  static const String otpVerification = 'Verify OTP';

  // Route to title map
  static const Map<String, String> routeTitles = {
    '/dashboard': dashboard,
    '/attendance': attendance,
    '/attendance/punch-in': punchIn,
    '/visits': visits,
    '/requests': requests,
    '/leads': leadsPipeline,
    '/leads/add': addLead,
    '/my-leads': myLeads,
    '/data-capture': dataCapture,
    '/data-capture/new': newDataCapture,
    '/data-capture/results': captureResults,
    '/data-capture/history': captureHistory,
    '/data-capture/details': captureDetails,
    '/notifications': notifications,
    '/profile': profile,
    '/settings': settings,
    '/forgot-password': forgotPassword,
  };
}
