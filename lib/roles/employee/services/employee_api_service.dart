import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickboom_crm_customer/core/network/api_client.dart';
import '../models/employee_attendance_model.dart';
import '../models/employee_leave_model.dart';
import '../models/employee_payroll_model.dart';
import '../models/employee_claim_model.dart';
import '../models/employee_loan_model.dart';
import '../models/work_permission_model.dart';
import '../models/lead_limit_model.dart';
import '../models/commission_model.dart';

final employeeApiServiceProvider = Provider<EmployeeApiService>((ref) {
  return EmployeeApiService(ref.read(apiClientProvider));
});

class EmployeeApiService {
  final ApiClient _apiClient;

  EmployeeApiService(this._apiClient);

  // ── 1. ATTENDANCE & SHIFT APIS ─────────────────────────────────────────────

  /// Fetch live attendance status and assigned office geofence for authenticated employee.
  Future<MyAttendanceStatus> getMyAttendanceStatus() async {
    try {
      final response = await _apiClient.get('/attendance/me');
      if (response.statusCode == 200 && response.data != null) {
        final Map<String, dynamic> rawData =
            response.data is Map<String, dynamic>
            ? response.data
            : Map<String, dynamic>.from(response.data);
        final Map<String, dynamic> data = (rawData['data'] is Map)
            ? Map<String, dynamic>.from(rawData['data'])
            : rawData;
        return MyAttendanceStatus.fromJson(data);
      }
      return MyAttendanceStatus.empty();
    } on DioException catch (dioErr) {
      if (dioErr.response?.statusCode == 403) {
        debugPrint(
          '[EMPLOYEE_API] getMyAttendanceStatus 403: Attendance access is not available for your account.',
        );
        throw Exception('Attendance access is not available for your account.');
      }
      final msg = _extractErrorMessage(dioErr);
      debugPrint('[EMPLOYEE_API] getMyAttendanceStatus DioException: $msg');
      throw Exception(msg);
    } catch (e) {
      debugPrint('[EMPLOYEE_API] getMyAttendanceStatus error: $e');
      throw Exception(
        'Unable to load attendance status. Please check connection and try again.',
      );
    }
  }

  /// Perform Check-In / Punch-In with mandatory GPS coordinates.
  Future<Map<String, dynamic>> checkIn({
    required double latitude,
    required double longitude,
    double? accuracy,
    String? address,
    bool biometricVerified = true,
  }) async {
    try {
      final response = await _apiClient.post(
        '/attendance/check-in',
        data: {
          'latitude': latitude,
          'longitude': longitude,
          'accuracy': ?accuracy,
          'address': ?address,
          'biometricVerified': biometricVerified,
        },
      );
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (dioErr) {
      final serverMsg = _extractErrorMessage(dioErr);
      throw Exception(serverMsg);
    }
  }

  /// Perform Check-Out / Punch-Out with GPS coordinates.
  Future<Map<String, dynamic>> checkOut({
    required double latitude,
    required double longitude,
    double? accuracy,
    String? address,
    bool biometricVerified = true,
  }) async {
    try {
      final response = await _apiClient.post(
        '/attendance/check-out',
        data: {
          'latitude': latitude,
          'longitude': longitude,
          'accuracy': ?accuracy,
          'address': ?address,
          'biometricVerified': biometricVerified,
        },
      );
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (dioErr) {
      final serverMsg = _extractErrorMessage(dioErr);
      throw Exception(serverMsg);
    }
  }

  /// Send live employee GPS location update to POST /api/v1/mobile/location/update
  Future<Map<String, dynamic>> updateLiveLocation({
    required double latitude,
    required double longitude,
    double? accuracy,
    String? address,
    String? timestamp,
    String trackingType = 'ATTENDANCE',
  }) async {
    try {
      final response = await _apiClient.post(
        '/mobile/location/update',
        data: {
          'latitude': latitude,
          'longitude': longitude,
          'accuracy': ?accuracy,
          'address': ?address,
          'timestamp': ?timestamp,
          'trackingType': trackingType,
        },
      );
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (dioErr) {
      final serverMsg = _extractErrorMessage(dioErr);
      throw Exception(serverMsg);
    }
  }

  /// Fetch today's punch state and duration summary from `/attendance/today`
  Future<Map<String, dynamic>> getTodayAttendance() async {
    try {
      final response = await _apiClient.get('/attendance/today');
      if (response.statusCode == 200 && response.data != null) {
        return Map<String, dynamic>.from(response.data);
      }
      return {'success': false, 'data': null};
    } on DioException catch (dioErr) {
      final msg = _extractErrorMessage(dioErr);
      throw Exception(msg);
    }
  }

  /// Start employee break.
  Future<Map<String, dynamic>> startBreak() async {
    try {
      final response = await _apiClient.post('/attendance/break/start');
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (dioErr) {
      final serverMsg = _extractErrorMessage(dioErr);
      throw Exception(serverMsg);
    }
  }

  /// End employee break.
  Future<Map<String, dynamic>> endBreak() async {
    try {
      final response = await _apiClient.post('/attendance/break/end');
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (dioErr) {
      final serverMsg = _extractErrorMessage(dioErr);
      throw Exception(serverMsg);
    }
  }

  // ── OVERTIME APIS ──────────────────────────────────────────────────────────

  /// Submit an Overtime request at least 1 day in advance
  Future<Map<String, dynamic>> submitOvertimeRequest({
    required String otDate,
    required String otType,
    required String plannedStartTime,
    required String plannedEndTime,
    required int plannedDurationMinutes,
    required String reason,
    required bool employeeConsent,
    String? employeeNotes,
    int? shiftId,
  }) async {
    try {
      final response = await _apiClient.post(
        '/overtime/my',
        data: {
          'overtimeDate': otDate,
          'overtimeType': otType,
          'startTime': plannedStartTime,
          'endTime': plannedEndTime,
          'reason': reason,
          if (shiftId != null && shiftId > 0) 'shiftId': shiftId,
          if ((employeeNotes ?? '').trim().isNotEmpty) 'employeeNotes': employeeNotes!.trim(),
          if (employeeConsent && (employeeNotes ?? '').trim().isEmpty)
            'employeeNotes': 'Employee confirmed this overtime request.',
        },
      );
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (dioErr) {
      final serverMsg = _extractErrorMessage(dioErr);
      throw Exception(serverMsg);
    }
  }

  /// Start an approved overtime session
  Future<Map<String, dynamic>> startOvertimeSession(int id) async {
    try {
      final response = await _apiClient.post('/overtime/$id/start');
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (dioErr) {
      final serverMsg = _extractErrorMessage(dioErr);
      throw Exception(serverMsg);
    }
  }

  Future<void> cancelPendingOvertime(int id) async {
    try {
      await _apiClient.patch('/overtime/$id/cancel', data: const {});
    } on DioException catch (dioErr) {
      throw Exception(_extractErrorMessage(dioErr));
    }
  }

  Future<void> requestOvertimeCancellation(int id, {required String reason, String? remarks}) async {
    try {
      await _apiClient.post('/overtime/$id/cancel', data: {
        'reason': reason,
        if (remarks != null && remarks.trim().isNotEmpty) 'remarks': remarks.trim(),
      });
    } on DioException catch (dioErr) {
      throw Exception(_extractErrorMessage(dioErr));
    }
  }

  /// End an active overtime session
  Future<Map<String, dynamic>> endOvertimeSession(int id) async {
    try {
      final response = await _apiClient.post('/overtime/$id/end');
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (dioErr) {
      final serverMsg = _extractErrorMessage(dioErr);
      throw Exception(serverMsg);
    }
  }

  /// Fetch employee's overtime requests
  Future<List<OvertimeRequestItem>> getMyOvertimeRequests({String? status}) async {
    try {
      final response = await _apiClient.get(
        '/overtime',
        queryParameters: {
          if (status != null && status != 'ALL') 'status': status,
        },
      );
      final dynamic data = response.data;
      final List<dynamic> rawList = data is List
          ? data
          : (data is Map && data['data'] is List)
          ? data['data']
          : [];
      return rawList
          .map((item) => OvertimeRequestItem.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      debugPrint('[EMPLOYEE_API] getMyOvertimeRequests error: $e');
      return [];
    }
  }

  /// Fetch current overtime live status
  Future<Map<String, dynamic>?> getCurrentOvertimeStatus() async {
    try {
      final response = await _apiClient.get('/overtime/current');
      if (response.data is Map && response.data['data'] != null) {
        return Map<String, dynamic>.from(response.data['data']);
      }
      return null;
    } catch (e) {
      debugPrint('[EMPLOYEE_API] getCurrentOvertimeStatus error: $e');
      return null;
    }
  }

  /// Get attendance history logs with optional date & status filtering.
  Future<List<AttendanceLogItem>> getAttendanceHistory({
    String? date,
    String? branch,
    int page = 1,
    int limit = 100,
  }) async {
    try {
      final response = await _apiClient.get(
        '/employees/hrm/attendance',
        queryParameters: {
          if (date != null && date.isNotEmpty) 'date': date,
          if (branch != null && branch != 'ALL') 'branch': branch,
          'page': page,
          'limit': limit,
        },
      );

      final dynamic data = response.data;
      final List<dynamic> rawList = data is List
          ? data
          : (data is Map && data['data'] is List)
          ? data['data']
          : (data is Map && data['items'] is List)
          ? data['items']
          : [];

      return rawList
          .map(
            (item) =>
                AttendanceLogItem.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    } on DioException catch (dioErr) {
      final serverMsg = _extractErrorMessage(dioErr);
      throw Exception(serverMsg);
    } catch (e) {
      debugPrint('[EMPLOYEE_API] getAttendanceHistory error: $e');
      rethrow;
    }
  }

  // ── 2. LEAVE & REMOTE WORK APIS ────────────────────────────────────────────

  /// Fetch active leave balances for employee.
  Future<List<LeaveBalanceItem>> getLeaveBalances() async {
    try {
      final response = await _apiClient.get('/leaves/balances');
      final dynamic data = response.data;
      final List<dynamic> rawList = data is List
          ? data
          : (data is Map && data['data'] is List)
          ? data['data']
          : (data is Map && data['balances'] is List)
          ? data['balances']
          : [];

      return rawList
          .map(
            (item) =>
                LeaveBalanceItem.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    } catch (e) {
      debugPrint('[EMPLOYEE_API] getLeaveBalances error: $e');
      rethrow;
    }
  }

  /// Fetch active leave types from server.
  Future<List<Map<String, dynamic>>> getLeaveTypes() async {
    try {
      final response = await _apiClient.get('/leaves/types');
      final dynamic data = response.data;
      final List<dynamic> rawList = data is List
          ? data
          : (data is Map && data['data'] is List)
          ? data['data']
          : [];
      return rawList.map((item) => Map<String, dynamic>.from(item)).toList();
    } catch (e) {
      debugPrint('[EMPLOYEE_API] getLeaveTypes error: $e');
      return [];
    }
  }

  /// Fetch employee leave applications list.
  Future<List<LeaveRequestItem>> getLeaveRequests({
    String? status,
    int page = 1,
  }) async {
    try {
      final response = await _apiClient.get(
        '/leaves/requests',
        queryParameters: {
          if (status != null && status != 'ALL') 'status': status,
          'page': page,
          'limit': 100,
        },
      );

      final dynamic data = response.data;
      final List<dynamic> rawList = data is List
          ? data
          : (data is Map && data['data'] is List)
          ? data['data']
          : (data is Map && data['items'] is List)
          ? data['items']
          : [];

      return rawList
          .map(
            (item) =>
                LeaveRequestItem.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    } catch (e) {
      debugPrint('[EMPLOYEE_API] getLeaveRequests error: $e');
      rethrow;
    }
  }

  /// Submit new leave application.
  Future<Map<String, dynamic>> applyLeave({
    required int leaveTypeId,
    required String fromDate,
    required String toDate,
    required String reason,
  }) async {
    try {
      final response = await _apiClient.post(
        '/leaves/requests',
        data: {
          'leaveTypeId': leaveTypeId,
          'fromDate': fromDate,
          'toDate': toDate,
          'reason': reason,
        },
      );
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (dioErr) {
      final serverMsg = _extractErrorMessage(dioErr);
      throw Exception(serverMsg);
    }
  }

  /// Fetch employee remote work (WFH) requests.
  Future<List<RemoteRequestItem>> getRemoteRequests({String? status}) async {
    try {
      final response = await _apiClient.get(
        '/remote-requests',
        queryParameters: {
          if (status != null && status != 'ALL') 'status': status,
        },
      );
      final dynamic data = response.data;
      final List<dynamic> rawList = data is List
          ? data
          : (data is Map && data['data'] is List)
          ? data['data']
          : (data is Map && data['requests'] is List)
          ? data['requests']
          : (data is Map && data['items'] is List)
          ? data['items']
          : [];

      return rawList
          .map(
            (item) =>
                RemoteRequestItem.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    } catch (e) {
      debugPrint(
        '[EMPLOYEE_API] getRemoteRequests primary error: $e. Trying fallback...',
      );
      try {
        final fallbackResp = await _apiClient.get(
          '/employees/hrm/remote-requests',
        );
        final dynamic fData = fallbackResp.data;
        final List<dynamic> fList = fData is List
            ? fData
            : (fData is Map && fData['data'] is List)
            ? fData['data']
            : (fData is Map && fData['items'] is List)
            ? fData['items']
            : [];
        return fList
            .map(
              (item) =>
                  RemoteRequestItem.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
      } catch (fallbackErr) {
        debugPrint(
          '[EMPLOYEE_API] getRemoteRequests fallback error: $fallbackErr',
        );
        rethrow;
      }
    }
  }

  /// Submit new WFH request.
  Future<Map<String, dynamic>> applyRemoteWork({
    required String fromDate,
    required String toDate,
    String? startTime,
    String? endTime,
    required String reason,
  }) async {
    try {
      final response = await _apiClient.post(
        '/remote-requests',
        data: {
          'fromDate': fromDate,
          'toDate': toDate,
          'startTime': startTime ?? '09:00 AM',
          'endTime': endTime ?? '06:00 PM',
          'reason': reason,
        },
      );
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (dioErr) {
      final serverMsg = _extractErrorMessage(dioErr);
      throw Exception(serverMsg);
    }
  }

  // ── 3. EXPENSE CLAIM APIS ──────────────────────────────────────────────────

  /// Fetch employee expense claims list.
  Future<List<EmployeeClaimItem>> getExpenseClaims({
    String? status,
    int page = 1,
  }) async {
    try {
      final response = await _apiClient.get(
        '/claims',
        queryParameters: {
          if (status != null && status != 'ALL') 'status': status,
          'page': page,
          'limit': 50,
        },
      );

      final dynamic data = response.data;
      final List<dynamic> rawList = data is List
          ? data
          : (data is Map && data['data'] is List)
          ? data['data']
          : (data is Map && data['items'] is List)
          ? data['items']
          : [];

      return rawList
          .map(
            (item) =>
                EmployeeClaimItem.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    } catch (e) {
      debugPrint('[EMPLOYEE_API] getExpenseClaims error: $e');
      return [];
    }
  }

  /// Submit new employee expense claim.
  Future<Map<String, dynamic>> applyExpenseClaim({
    required String category,
    required double amount,
    required String description,
    String? claimDate,
    String? receiptUrl,
  }) async {
    try {
      final response = await _apiClient.post(
        '/claims',
        data: {
          'category': category.toUpperCase(),
          'amount': amount,
          'description': description,
          'claimDate': ?claimDate,
          'receiptUrl': ?receiptUrl,
        },
      );
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (dioErr) {
      final serverMsg = _extractErrorMessage(dioErr);
      throw Exception(serverMsg);
    }
  }

  // ── 4. LOAN APIS ───────────────────────────────────────────────────────────

  /// Fetch employee loans list.
  Future<List<EmployeeLoanItem>> getLoans({
    String? status,
    int page = 1,
  }) async {
    try {
      final response = await _apiClient.get(
        '/loans',
        queryParameters: {
          if (status != null && status != 'ALL') 'status': status,
          'page': page,
          'limit': 50,
        },
      );

      final dynamic data = response.data;
      final List<dynamic> rawList = data is List
          ? data
          : (data is Map && data['data'] is List)
          ? data['data']
          : (data is Map && data['items'] is List)
          ? data['items']
          : [];

      return rawList
          .map(
            (item) =>
                EmployeeLoanItem.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    } catch (e) {
      debugPrint('[EMPLOYEE_API] getLoans error: $e');
      return [];
    }
  }

  /// Submit new employee loan request.
  Future<Map<String, dynamic>> applyLoan({
    required double loanAmount,
    required String reason,
    int termMonths = 12,
  }) async {
    try {
      final response = await _apiClient.post(
        '/loans',
        data: {
          'loanAmount': loanAmount,
          'reason': reason,
          'termMonths': termMonths,
        },
      );
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (dioErr) {
      final serverMsg = _extractErrorMessage(dioErr);
      throw Exception(serverMsg);
    }
  }

  // ── 5. PAYROLL & SALARY SLIP APIS ──────────────────────────────────────────

  /// Current compensation is resolved by the server from the authenticated user.
  Future<Map<String, dynamic>?> getSalaryDetails() async {
    final response = await _apiClient.get('/admin/payroll/salary');
    final body = response.data;
    final map = body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
    final nested = map['data'] is Map ? Map<String, dynamic>.from(map['data']) : map;
    final salary = nested['salaryStructure'] ?? map['salaryStructure'];
    return salary == null ? null : Map<String, dynamic>.from(salary);
  }

  Future<Map<String, dynamic>?> getSalaryTarget() async {
    final response = await _apiClient.get('/admin/payroll/targets/me');
    final body = response.data;
    if (body is Map && body['data'] is Map) return Map<String, dynamic>.from(body['data']);
    if (body is Map) return Map<String, dynamic>.from(body);
    return null;
  }

  /// Fetch employee salary slips list.
  Future<List<SalarySlipItem>> getSalarySlips({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _apiClient.get(
        '/admin/payroll/slips',
        queryParameters: {'page': page, 'limit': limit},
      );

      final dynamic data = response.data;
      final List<dynamic> rawList = data is List
          ? data
          : (data is Map && data['data'] is List)
          ? data['data']
          : (data is Map && data['slips'] is List)
          ? data['slips']
          : (data is Map && data['items'] is List)
          ? data['items']
          : [];

      return rawList
          .map(
            (item) => SalarySlipItem.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    } catch (e) {
      debugPrint('[EMPLOYEE_API] getSalarySlips error: $e');
      rethrow;
    }
  }

  // ── 6. NOTIFICATIONS APIS ──────────────────────────────────────────────────

  /// Fetch notifications list for current employee.
  Future<List<Map<String, dynamic>>> getNotifications({
    int page = 1,
    bool unreadOnly = false,
  }) async {
    try {
      final response = await _apiClient.get(
        '/notifications',
        queryParameters: {
          'page': page,
          'limit': 30,
          if (unreadOnly) 'unreadOnly': 'true',
        },
      );

      final dynamic data = response.data;
      final List<dynamic> rawList = data is List
          ? data
          : (data is Map && data['data'] is List)
          ? data['data']
          : (data is Map && data['items'] is List)
          ? data['items']
          : [];

      return rawList
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    } catch (e) {
      debugPrint('[EMPLOYEE_API] getNotifications error: $e');
      return [];
    }
  }

  /// Mark single notification as read.
  Future<void> markNotificationAsRead(String id) async {
    try {
      await _apiClient.patch('/notifications/$id/read');
    } catch (e) {
      debugPrint('[EMPLOYEE_API] markNotificationAsRead error: $e');
    }
  }

  /// Delete a single notification.
  Future<void> deleteNotification(String id) async {
    try {
      await _apiClient.delete('/notifications/$id');
    } catch (e) {
      debugPrint('[EMPLOYEE_API] deleteNotification error: $e');
      rethrow;
    }
  }

  /// Mark all notifications as read.
  Future<void> markAllNotificationsAsRead() async {
    try {
      await _apiClient.patch('/notifications/read-all');
    } catch (e) {
      debugPrint('[EMPLOYEE_API] markAllNotificationsAsRead error: $e');
    }
  }

  // ── WORK MODULE PERMISSIONS & ACCESS REQUESTS ──────────────────────────────

  /// Fetch effective work module permissions for the authenticated employee.
  /// Existing widget adapter: assigned work is available to every active employee.
  Future<EmployeeWorkPermissions> getMyWorkPermissions() async {
    final response = await _apiClient.get('/auth/me');
    if (response.statusCode != 200 || response.data is! Map) {
      throw Exception('Unable to load authenticated profile');
    }
    final envelope = Map<String, dynamic>.from(response.data as Map);
    final profile = envelope['data'] is Map
        ? Map<String, dynamic>.from(envelope['data'] as Map)
        : envelope;
    final employee = profile['employee'] is Map
        ? Map<String, dynamic>.from(profile['employee'] as Map)
        : null;
    final empStatus = employee?['status']?.toString().toUpperCase().trim();
    final isEmployeeAccount =
        profile['accountType']?.toString().toUpperCase() == 'EMPLOYEE' ||
        profile['role']?.toString().toUpperCase() == 'EMPLOYEE' ||
        profile['employeeId'] != null;

    if (employee == null && !isEmployeeAccount) {
      throw Exception('Active employee profile required');
    }
    if (empStatus != null &&
        empStatus != 'ACTIVE' &&
        empStatus != 'PROBATION') {
      throw Exception('Active employee profile required');
    }
    return EmployeeWorkPermissions(
      employeeId: int.tryParse(
        employee?['id']?.toString() ?? profile['employeeId']?.toString() ?? '',
      ),
      employeeCode:
          employee?['employeeCode']?.toString() ??
          profile['employeeCode']?.toString(),
      firstName:
          employee?['firstName']?.toString() ??
          profile['firstName']?.toString(),
      lastName:
          employee?['lastName']?.toString() ?? profile['lastName']?.toString(),
      role: profile['accountType']?.toString() ?? 'EMPLOYEE',
      workPermissions: const [
        'my_work',
        'creative_work',
        'video_edit',
        'post_design',
        'story_design',
        'reel_shoot',
        'reel_post',
        'story_post',
        'post_publish',
        'influencer_promo',
      ],
      isCrmEligible: profile['crmMobileAccess'] == true,
    );
  }

  // ── HELPER: Clean User-Friendly Error Formatting ───────────────────────────
  static String _extractErrorMessage(DioException dioErr) {
    if (dioErr.response?.data != null) {
      final data = dioErr.response!.data;
      if (data is Map) {
        String? msg;
        if (data['message'] is String) msg = data['message'];
        if (data['message'] is List && (data['message'] as List).isNotEmpty) {
          msg = (data['message'] as List).first.toString();
        }
        if (msg == null && data['error'] is String) msg = data['error'];

        if (msg != null && msg.isNotEmpty) {
          if (msg.contains('No active office location') ||
              msg.contains('office location configured')) {
            return 'Attendance location is not configured. Please contact Admin.';
          }
          return msg;
        }
      }
    }

    final statusCode = dioErr.response?.statusCode;
    if (statusCode == 400) {
      return 'Invalid request. Please verify details and try again.';
    }
    if (statusCode == 401) return 'Session expired. Please log in again.';
    if (statusCode == 403) {
      return 'You do not have permission to perform this action.';
    }
    if (statusCode == 404) return 'The requested resource was not found.';
    if (statusCode != null && statusCode >= 500) {
      return 'Server error occurred. Please try again later.';
    }

    return 'Network connection issue. Please check your internet connection.';
  }

  // ── 7. LEAD GENERATION LIMITS APIS ────────────────────────────────────────

  /// Fetch authenticated employee's effective daily/monthly lead limit and usage
  Future<EmployeeLeadLimitModel> getMyLeadLimit() async {
    try {
      final response = await _apiClient.get('/lead-generation-limits/me');
      if (response.statusCode == 200 && response.data != null) {
        final Map<String, dynamic> rawData =
            response.data is Map<String, dynamic>
                ? response.data
                : Map<String, dynamic>.from(response.data);
        final Map<String, dynamic> data = (rawData['data'] is Map)
            ? Map<String, dynamic>.from(rawData['data'])
            : rawData;
        final parsed = EmployeeLeadLimitModel.fromJson(data);
        debugPrint(
          '[LEAD QUOTA DEBUG] Mobile received: daily=${parsed.daily.limit} (used: ${parsed.daily.used}, rem: ${parsed.daily.remaining}), monthly=${parsed.monthly.limit} (used: ${parsed.monthly.used}, rem: ${parsed.monthly.remaining}), role=${parsed.roleName}, custom=${parsed.isCustom}',
        );
        return parsed;
      }
      return EmployeeLeadLimitModel.empty();
    } on DioException catch (dioErr) {
      final msg = _extractErrorMessage(dioErr);
      debugPrint('[EMPLOYEE_API] getMyLeadLimit DioException: $msg');
      throw Exception(msg);
    } catch (e) {
      debugPrint('[EMPLOYEE_API] getMyLeadLimit error: $e');
      throw Exception('Unable to load lead generation limits.');
    }
  }

  // ── 8. COMMISSION APIS ──────────────────────────────────────────────────

  /// Fetch authenticated employee's commission records and summary.
  Future<EmployeeCommissionResponse> getMyCommissions({
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{'page': page, 'limit': limit};
      if (status != null && status != 'ALL' && status.isNotEmpty) {
        queryParams['status'] = status;
      }

      final response = await _apiClient.get(
        '/commissions/me',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data != null) {
        final Map<String, dynamic> rawData =
            response.data is Map<String, dynamic>
            ? response.data
            : Map<String, dynamic>.from(response.data);
        return EmployeeCommissionResponse.fromJson(rawData);
      }
      return EmployeeCommissionResponse(
        items: [],
        summary: CommissionSummary.empty(),
        total: 0,
        page: page,
        limit: limit,
      );
    } on DioException catch (dioErr) {
      if (dioErr.response?.statusCode == 403) {
        debugPrint(
          '[EMPLOYEE_API] getMyCommissions 403: Commission access is not available for your account.',
        );
        throw Exception('Commission access is not available for your account.');
      }
      final msg = _extractErrorMessage(dioErr);
      debugPrint('[EMPLOYEE_API] getMyCommissions DioException: $msg');
      throw Exception(msg);
    } catch (e) {
      debugPrint('[EMPLOYEE_API] getMyCommissions error: $e');
      throw Exception(
        'Unable to load commissions. Please check connection and try again.',
      );
    }
  }

  Future<Map<String, dynamic>> monthlyReports() async {
    final response = await _apiClient.get('/hrm/my-reports');
    final body = response.data;
    if (body is Map && body['data'] is Map) return Map<String, dynamic>.from(body['data'] as Map);
    if (body is Map) return Map<String, dynamic>.from(body);
    return {};
  }

  Future<String> monthlyReportUrl(int id) async {
    final response = await _apiClient.get('/hrm/my-reports/$id/download');
    final body = response.data;
    final data = body is Map && body['data'] is Map ? body['data'] as Map : body;
    return data is Map ? data['url']?.toString() ?? '' : '';
  }

  Future<Map<String, dynamic>> getMySalarySummary({int? year, int? month}) async {
    final response = await _apiClient.get(
      '/hrm/my-salary-summary',
      queryParameters: {
        'year': ?year,
        'month': ?month,
      },
    );
    final body = response.data;
    if (body is Map && body['data'] is Map) return Map<String, dynamic>.from(body['data'] as Map);
    if (body is Map) return Map<String, dynamic>.from(body);
    return {};
  }

  Future<List<Map<String, dynamic>>> getMySalaryHistory() async {
    final response = await _apiClient.get('/hrm/my-salary-summary/history');
    final body = response.data;
    final dynamic list = body is List
        ? body
        : (body is Map && body['data'] is List ? body['data'] : []);
    return (list as List).map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> getTeamAttendanceLeaves({int? year, int? month}) async {
    final response = await _apiClient.get(
      '/hrm/team/attendance-leaves',
      queryParameters: {
        'year': ?year,
        'month': ?month,
      },
    );
    final body = response.data;
    final dynamic list = body is List
        ? body
        : (body is Map && body['data'] is List ? body['data'] : []);
    return (list as List).map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  Future<Map<String, dynamic>> getAdminHrmDashboard({int? year, int? month}) async {
    final response = await _apiClient.get(
      '/admin/hrm/reports/dashboard',
      queryParameters: {
        'year': ?year,
        'month': ?month,
      },
    );
    final body = response.data;
    if (body is Map && body['data'] is Map) return Map<String, dynamic>.from(body['data'] as Map);
    if (body is Map) return Map<String, dynamic>.from(body);
    return {};
  }

  Future<String> getAdminReportDownloadUrl(int reportId) async {
    final response = await _apiClient.get('/admin/hrm/reports/download/$reportId');
    final body = response.data;
    final data = body is Map && body['data'] is Map ? body['data'] as Map : body;
    return data is Map ? data['url']?.toString() ?? '' : '';
  }

  Future<void> retryAdminReportDelivery(int deliveryId) async {
    await _apiClient.post('/admin/hrm/reports/retry/$deliveryId');
  }
}

final employeeSalaryDetailsProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) {
  return ref.watch(employeeApiServiceProvider).getSalaryDetails();
});
