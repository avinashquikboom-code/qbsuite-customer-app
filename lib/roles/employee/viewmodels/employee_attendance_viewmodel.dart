import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickboom_crm_customer/core/network/api_client.dart';
import 'package:quickboom_crm_customer/core/services/biometric_auth_service.dart';
import 'package:quickboom_crm_customer/core/services/employee_live_tracking_service.dart';
import 'package:quickboom_crm_customer/core/services/employee_location_service.dart';
import 'package:quickboom_crm_customer/core/utils/app_date_formatter.dart';
import 'package:quickboom_crm_customer/core/services/permission_manager.dart';
import '../models/employee_attendance_model.dart';
import '../services/employee_api_service.dart';

class AttendanceState {
  final bool isLoading;
  final bool isActionRunning;
  final String? actionFeedback;
  final MyAttendanceStatus status;
  final String? pageError;
  final String? actionError;
  final String? successMessage;
  final List<AttendanceLogItem> historyLogs;
  final bool isHistoryLoading;

  // Single Shared Geofence & GPS State
  final bool isLocating;
  final double? currentLatitude;
  final double? currentLongitude;
  final double? currentAccuracy;
  final double? distanceToOfficeMeters;
  final bool isInsideOfficeRadius;
  final String? locationError;

  const AttendanceState({
    this.isLoading = false,
    this.isActionRunning = false,
    this.actionFeedback,
    required this.status,
    this.pageError,
    this.actionError,
    this.successMessage,
    this.historyLogs = const [],
    this.isHistoryLoading = false,
    this.isLocating = false,
    this.currentLatitude,
    this.currentLongitude,
    this.currentAccuracy,
    this.distanceToOfficeMeters,
    this.isInsideOfficeRadius = false,
    this.locationError,
  });

  String? get errorMessage => actionError ?? pageError;

  EmployeeAttendancePhase get phase => status.status.phase;
  bool get isPunchedIn => status.status.isPunchedIn;
  bool get isOnBreak => status.status.isOnBreak;
  bool get isCompleted => status.status.isCompleted;

  String get punchInTimeFormatted =>
      AppDateFormatter.formatAttendanceTime(status.status.punchInTime);

  String get punchOutTimeFormatted =>
      AppDateFormatter.formatAttendanceTime(status.status.punchOutTime);

  String get workingHoursFormatted => status.status.hasWorkingHours
      ? AppDateFormatter.formatDurationHoursMinutes(
          (status.status.workingHours * 60).round(),
        )
      : '--';

  String get breakDurationFormatted => status.status.hasBreakDuration
      ? AppDateFormatter.formatDurationHoursMinutes(
          (status.status.breakDuration * 60).round(),
        )
      : '--';

  bool get isRemoteWork =>
      status.isRemoteWorkActive ||
      (status.approvedRemote?.isCurrentlyActive ?? false) ||
      (status.approvedRemote?.status.toUpperCase() == 'APPROVED');
  String get remoteReason =>
      status.approvedRemote?.reason ?? 'Approved Remote Duty';

  AssignedShiftInfo? get assignedShift => status.assignedShift;

  String get shiftStartTime =>
      status.assignedShift?.startTime ??
      status.policy?.officeStartTime ??
      '09:30 AM';
  String get shiftEndTime =>
      status.assignedShift?.endTime ??
      status.policy?.officeEndTime ??
      '06:30 PM';
  String get shiftTimeFormatted => '$shiftStartTime - $shiftEndTime';

  int get gracePeriodMinutes =>
      status.assignedShift?.gracePeriodMinutes ??
      status.policy?.gracePeriodMinutes ??
      15;

  double get expectedWorkingHours =>
      status.assignedShift?.durationHours ??
      status.policy?.minWorkingHours ??
      9.0;

  String get expectedWorkingHoursFormatted {
    final h = expectedWorkingHours.floor();
    final m = ((expectedWorkingHours - h) * 60).round();
    return '${h.toString().padLeft(2, '0')}h ${m.toString().padLeft(2, '0')}m';
  }

  bool get isOvertimeEligible => status.overtime?.isEligible ?? true;
  OvertimeRequestItem? get activeOvertime => status.overtime?.activeRequest;
  bool get hasActiveOvertime => activeOvertime != null;
  bool get isOvertimeInProgress => activeOvertime?.isInProgress ?? false;
  bool get isOvertimeApproved => activeOvertime?.isApproved ?? false;
  bool get isOvertimePending => activeOvertime?.isPending ?? false;

  double get workingProgressRatio {
    if (expectedWorkingHours <= 0) return 0.0;
    return (status.status.workingHours / expectedWorkingHours).clamp(0.0, 1.0);
  }

  String get remainingWorkingDurationFormatted {
    final remaining = (expectedWorkingHours - status.status.workingHours).clamp(
      0.0,
      24.0,
    );
    if (remaining <= 0) return '00h 00m';
    final h = remaining.floor();
    final m = ((remaining - h) * 60).round();
    return '${h.toString().padLeft(2, '0')}h ${m.toString().padLeft(2, '0')}m';
  }

  String? get activeBreakStartedFormatted {
    if (status.status.activeBreakStart == null) return null;
    return AppDateFormatter.formatAttendanceTime(
      status.status.activeBreakStart,
    );
  }

  bool get isLateArrival {
    if (status.status.rawStatus == 'LATE') return true;
    if (status.status.punchInTime != null) {
      try {
        final punchIn = DateTime.parse(status.status.punchInTime!).toLocal();
        final startParts = _parseTimeString(shiftStartTime);
        if (startParts != null) {
          final shiftStart = DateTime(
            punchIn.year,
            punchIn.month,
            punchIn.day,
            startParts[0],
            startParts[1],
          );
          final diff = punchIn.difference(shiftStart).inMinutes;
          return diff > gracePeriodMinutes;
        }
      } catch (_) {}
    }
    return false;
  }

  int get lateByMinutes {
    if (status.status.punchInTime != null) {
      try {
        final punchIn = DateTime.parse(status.status.punchInTime!).toLocal();
        final startParts = _parseTimeString(shiftStartTime);
        if (startParts != null) {
          final shiftStart = DateTime(
            punchIn.year,
            punchIn.month,
            punchIn.day,
            startParts[0],
            startParts[1],
          );
          final diff = punchIn.difference(shiftStart).inMinutes;
          return diff > 0 ? diff : 0;
        }
      } catch (_) {}
    }
    return 0;
  }

  static List<int>? _parseTimeString(String timeStr) {
    try {
      final clean = timeStr.trim().toUpperCase();
      final reg = RegExp(r'(\d+):(\d+)(?::\d+)?\s*(AM|PM)?');
      final match = reg.firstMatch(clean);
      if (match != null) {
        var hour = int.parse(match.group(1)!);
        final min = int.parse(match.group(2)!);
        final mer = match.group(3);
        if (mer == 'PM' && hour < 12) hour += 12;
        if (mer == 'AM' && hour == 12) hour = 0;
        return [hour, min];
      }
    } catch (_) {}
    return null;
  }

  AttendanceState copyWith({
    bool? isLoading,
    bool? isActionRunning,
    String? actionFeedback,
    MyAttendanceStatus? status,
    String? pageError,
    String? actionError,
    String? errorMessage,
    String? successMessage,
    List<AttendanceLogItem>? historyLogs,
    bool? isHistoryLoading,
    bool? isLocating,
    double? currentLatitude,
    double? currentLongitude,
    double? currentAccuracy,
    double? distanceToOfficeMeters,
    bool? isInsideOfficeRadius,
    String? locationError,
    bool clearMessages = false,
  }) {
    return AttendanceState(
      isLoading: isLoading ?? this.isLoading,
      isActionRunning: isActionRunning ?? this.isActionRunning,
      actionFeedback: actionFeedback,
      status: status ?? this.status,
      pageError: clearMessages ? null : (pageError ?? this.pageError),
      actionError: clearMessages
          ? null
          : (actionError ?? errorMessage ?? this.actionError),
      successMessage: clearMessages
          ? null
          : (successMessage ?? this.successMessage),
      historyLogs: historyLogs ?? this.historyLogs,
      isHistoryLoading: isHistoryLoading ?? this.isHistoryLoading,
      isLocating: isLocating ?? this.isLocating,
      currentLatitude: currentLatitude ?? this.currentLatitude,
      currentLongitude: currentLongitude ?? this.currentLongitude,
      currentAccuracy: currentAccuracy ?? this.currentAccuracy,
      distanceToOfficeMeters:
          distanceToOfficeMeters ?? this.distanceToOfficeMeters,
      isInsideOfficeRadius: isInsideOfficeRadius ?? this.isInsideOfficeRadius,
      locationError: clearMessages
          ? null
          : (locationError ?? this.locationError),
    );
  }
}

class EmployeeAttendanceNotifier extends Notifier<AttendanceState> {
  @override
  AttendanceState build() {
    final perms = ref.watch(permissionManagerProvider);
    // Only automatically fetch attendance if permissions have loaded and attendance is permitted
    if (perms.isReady && perms.canViewAttendance) {
      Future.microtask(() => loadStatus());
    }
    return AttendanceState(
      status: MyAttendanceStatus.empty(),
      isLoading: perms.isLoading || (perms.isReady && perms.canViewAttendance),
    );
  }

  EmployeeApiService get _service => ref.read(employeeApiServiceProvider);

  /// Load current attendance status from `/attendance/me`
  Future<void> loadStatus() async {
    final perms = ref.read(permissionManagerProvider);
    if (!perms.isReady) {
      debugPrint(
        '[ATTENDANCE_NOTIFIER] Permissions still loading; deferring loadStatus',
      );
      return;
    }
    if (!perms.canViewAttendance) {
      debugPrint(
        '[ATTENDANCE_NOTIFIER] Skipping /attendance/me call: ATTENDANCE:VIEW permission not granted',
      );
      state = state.copyWith(isLoading: false, pageError: null);
      return;
    }

    try {
      state = state.copyWith(isLoading: true, clearMessages: true);
      final status = await _service.getMyAttendanceStatus();

      // If we already have a position, recalculate distance against the newly loaded office
      double? dist;
      bool inside = false;
      final office = status.assignedOffice;
      if (office != null &&
          office.latitude != 0.0 &&
          office.longitude != 0.0 &&
          state.currentLatitude != null &&
          state.currentLongitude != null) {
        dist = office.distanceTo(
          state.currentLatitude!,
          state.currentLongitude!,
        );
        inside = dist <= office.radiusMeters;
      }

      state = state.copyWith(
        isLoading: false,
        status: status,
        pageError: null,
        distanceToOfficeMeters: dist ?? state.distanceToOfficeMeters,
        isInsideOfficeRadius: dist != null
            ? inside
            : state.isInsideOfficeRadius,
      );

      // Auto-start live tracking if currently punched in, or stop if completed
      final isWorking =
          status.status.isPunchedIn &&
          (status.status.punchOutTime == null ||
              status.status.punchOutTime!.isEmpty);

      if (isWorking) {
        EmployeeLiveTrackingService().startTracking(
          employeeId: status.employee?.employeeCode,
          apiClient: ref.read(apiClientProvider),
        );
      } else if (status.status.punchOutTime != null &&
          status.status.punchOutTime!.isNotEmpty) {
        EmployeeLiveTrackingService().stopTracking();
      }
    } catch (e) {
      final cleanMsg = e.toString().replaceFirst('Exception: ', '');
      debugPrint('[ATTENDANCE_NOTIFIER] loadStatus error: $cleanMsg');
      state = state.copyWith(isLoading: false, pageError: cleanMsg);
    }
  }

  /// Request fresh GPS location and calculate distance to assigned office
  Future<void> checkLocation({bool forceFresh = true}) async {
    state = state.copyWith(isLocating: true, clearMessages: true);

    final locResult = await EmployeeLocationService.getCurrentLocation(
      forceFresh: forceFresh,
    );

    if (locResult.isSuccess && locResult.position != null) {
      final pos = locResult.position!;
      final office = state.status.assignedOffice;

      if (office != null && office.latitude != 0.0 && office.longitude != 0.0) {
        final dist = office.distanceTo(pos.latitude, pos.longitude);
        final inside = dist <= office.radiusMeters;

        debugPrint('''[GEOFENCE_TELEMETRY]
currentLat: ${pos.latitude}
currentLng: ${pos.longitude}
accuracy: ${pos.accuracy}
officeLat: ${office.latitude}
officeLng: ${office.longitude}
calculatedDistance: ${dist.round()}
allowedRadius: ${office.radiusMeters.round()}
isInsideRadius: $inside''');

        state = state.copyWith(
          isLocating: false,
          currentLatitude: pos.latitude,
          currentLongitude: pos.longitude,
          currentAccuracy: pos.accuracy,
          distanceToOfficeMeters: dist,
          isInsideOfficeRadius: inside,
          locationError: null,
        );
      } else {
        state = state.copyWith(
          isLocating: false,
          currentLatitude: pos.latitude,
          currentLongitude: pos.longitude,
          currentAccuracy: pos.accuracy,
          distanceToOfficeMeters: null,
          isInsideOfficeRadius: false,
          locationError: office == null
              ? 'Loading assigned office location...'
              : 'Office coordinates not configured.',
        );
      }
    } else {
      state = state.copyWith(
        isLocating: false,
        distanceToOfficeMeters: null,
        isInsideOfficeRadius: false,
        locationError:
            locResult.errorMessage ?? 'Unable to acquire GPS signal.',
      );
    }
  }

  /// Execute Punch-In with mandatory GPS and Geofence radius verification
  Future<bool> punchIn() async {
    if (state.isActionRunning) return false;

    try {
      state = state.copyWith(
        isActionRunning: true,
        actionFeedback: 'Verifying Biometrics...',
        clearMessages: true,
      );

      // 1. Mandatory Biometric / Fingerprint verification
      final bioResult = await BiometricAuthService.authenticate(
        localizedReason: 'Scan fingerprint or face to record Punch In',
      );

      if (!bioResult.isSuccess) {
        final errorMsg = bioResult.status == BiometricAuthStatus.cancelled
            ? 'Authentication cancelled.'
            : bioResult.status == BiometricAuthStatus.unavailable
            ? bioResult.message
            : 'Biometric verification failed.';
        debugPrint('[PUNCH_IN_BIOMETRIC_ABORTED] $errorMsg');
        state = state.copyWith(isActionRunning: false, actionError: errorMsg);
        return false;
      }

      state = state.copyWith(actionFeedback: 'Checking Location...');

      // 2. Ensure office and attendance policy are loaded
      if (state.status.assignedOffice == null) {
        await loadStatus();
      }

      // 3. Acquire a 100% fresh, high-accuracy GPS fix and compute geodesic distance
      await checkLocation(forceFresh: true);

      if (state.currentLatitude == null || state.currentLongitude == null) {
        state = state.copyWith(
          isActionRunning: false,
          actionError:
              state.locationError ??
              'Location permission is required for attendance.',
        );
        return false;
      }

      final lat = state.currentLatitude!;
      final lng = state.currentLongitude!;
      final acc = state.currentAccuracy;
      final dist = state.distanceToOfficeMeters;
      final inside = state.isInsideOfficeRadius;
      final office = state.status.assignedOffice;

      // 4. Local pre-validation check (unless approved remote work)
      if (!state.isRemoteWork && dist != null && !inside) {
        final errText =
            'You are outside the allowed office attendance area. Distance: ${dist.round()}m (Allowed: ${office?.radiusMeters.round() ?? 200}m for ${office?.name ?? "Office"}).';
        debugPrint('[PUNCH_IN_BLOCKED_OUTSIDE_RADIUS] $errText');
        state = state.copyWith(isActionRunning: false, actionError: errText);
        return false;
      }

      // 5. Send Check-In request with exact GPS coordinates & biometric audit
      state = state.copyWith(actionFeedback: 'Punching In...');
      final resp = await _service.checkIn(
        latitude: lat,
        longitude: lng,
        accuracy: acc != null && acc > 0 ? acc : null,
        biometricVerified: true,
      );

      // 6. Reload fresh status and activate 25s live tracking
      await loadStatus();
      EmployeeLiveTrackingService().startTracking(
        employeeId: state.status.employee?.employeeCode,
        apiClient: ref.read(apiClientProvider),
      );

      state = state.copyWith(
        isActionRunning: false,
        successMessage:
            resp['message']?.toString() ??
            'Punch In successful! Have a great shift.',
      );
      return true;
    } catch (e) {
      final cleanMsg = e.toString().replaceFirst('Exception: ', '');
      final office = state.status.assignedOffice;
      debugPrint('''[GEOFENCE_MISMATCH]
API_STATUS: 403 / ERROR
API_MESSAGE: $cleanMsg
currentLat: ${state.currentLatitude}
currentLng: ${state.currentLongitude}
accuracy: ${state.currentAccuracy}
officeLat: ${office?.latitude}
officeLng: ${office?.longitude}
calculatedDistance: ${state.distanceToOfficeMeters?.round()}
allowedRadius: ${office?.radiusMeters}''');

      state = state.copyWith(isActionRunning: false, actionError: cleanMsg);
      return false;
    }
  }

  /// Start employee break
  Future<bool> startBreak() async {
    if (state.isActionRunning) return false;

    try {
      state = state.copyWith(
        isActionRunning: true,
        actionFeedback: 'Starting Break...',
        clearMessages: true,
      );

      final resp = await _service.startBreak();
      await loadStatus();

      state = state.copyWith(
        isActionRunning: false,
        successMessage: resp['message']?.toString() ?? 'Break started.',
      );
      return true;
    } catch (e) {
      final cleanMsg = e.toString().replaceFirst('Exception: ', '');
      state = state.copyWith(isActionRunning: false, errorMessage: cleanMsg);
      return false;
    }
  }

  /// End employee break
  Future<bool> endBreak() async {
    if (state.isActionRunning) return false;

    try {
      state = state.copyWith(
        isActionRunning: true,
        actionFeedback: 'Ending Break...',
        clearMessages: true,
      );

      final resp = await _service.endBreak();
      await loadStatus();

      state = state.copyWith(
        isActionRunning: false,
        successMessage:
            resp['message']?.toString() ?? 'Break ended. Welcome back!',
      );
      return true;
    } catch (e) {
      final cleanMsg = e.toString().replaceFirst('Exception: ', '');
      state = state.copyWith(isActionRunning: false, errorMessage: cleanMsg);
      return false;
    }
  }

  /// Execute Punch-Out with GPS verification
  Future<bool> punchOut() async {
    if (state.isActionRunning) return false;

    try {
      state = state.copyWith(
        isActionRunning: true,
        actionFeedback: 'Verifying Biometrics...',
        clearMessages: true,
      );

      // 1. Mandatory Biometric / Fingerprint verification before Punch Out
      final bioResult = await BiometricAuthService.authenticate(
        localizedReason:
            'Scan fingerprint or face to confirm Punch Out and finalize shift',
      );

      if (!bioResult.isSuccess) {
        final errorMsg = bioResult.status == BiometricAuthStatus.cancelled
            ? 'Authentication cancelled.'
            : bioResult.status == BiometricAuthStatus.unavailable
            ? bioResult.message
            : 'Biometric verification failed. Punch out was not completed.';
        debugPrint('[PUNCH_OUT_BIOMETRIC_ABORTED] $errorMsg');
        state = state.copyWith(
          isActionRunning: false,
          actionError: errorMsg,
          errorMessage: errorMsg,
        );
        return false;
      }

      state = state.copyWith(actionFeedback: 'Checking Location...');

      final locResult = await EmployeeLocationService.getCurrentLocation();
      double lat = 0.0;
      double lng = 0.0;
      double? acc;
      if (locResult.isSuccess && locResult.position != null) {
        lat = locResult.position!.latitude;
        lng = locResult.position!.longitude;
        acc = locResult.position!.accuracy > 0
            ? locResult.position!.accuracy
            : null;
      }

      state = state.copyWith(actionFeedback: 'Punching Out...');
      final resp = await _service.checkOut(
        latitude: lat,
        longitude: lng,
        accuracy: acc,
        biometricVerified: true,
      );

      // 2. Stop 25s live tracking upon successful punch out
      EmployeeLiveTrackingService().stopTracking();
      await loadStatus();

      state = state.copyWith(
        isActionRunning: false,
        successMessage:
            resp['message']?.toString() ??
            'Punch Out successful. Shift completed!',
      );
      return true;
    } catch (e) {
      final cleanMsg = e.toString().replaceFirst('Exception: ', '');
      state = state.copyWith(
        isActionRunning: false,
        actionError: cleanMsg,
        errorMessage: cleanMsg,
      );
      return false;
    }
  }

  /// Load Attendance history logs
  Future<void> loadHistory({String? date, String? branch}) async {
    try {
      state = state.copyWith(isHistoryLoading: true, pageError: null);
      final logs = await _service.getAttendanceHistory(
        date: date,
        branch: branch,
      );
      state = state.copyWith(
        isHistoryLoading: false,
        historyLogs: logs,
        pageError: null,
      );
    } catch (e) {
      final cleanMsg = e.toString().replaceFirst('Exception: ', '');
      debugPrint('[ATTENDANCE_NOTIFIER] loadHistory error: $cleanMsg');
      state = state.copyWith(isHistoryLoading: false, pageError: cleanMsg);
    }
  }
}

final employeeAttendanceProvider =
    NotifierProvider<EmployeeAttendanceNotifier, AttendanceState>(
      EmployeeAttendanceNotifier.new,
    );
