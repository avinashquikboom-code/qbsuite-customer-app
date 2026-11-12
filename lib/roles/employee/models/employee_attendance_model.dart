import 'dart:math';
import 'package:quickboom_crm_customer/core/utils/app_date_formatter.dart';

/// Representation of the Employee's current Attendance status for the day.
class MyAttendanceStatus {
  final EmployeeShortInfo? employee;
  final AssignedOffice? assignedOffice;
  final AttendanceStatusDetails status;
  final Map<String, dynamic>? todayAttendance;
  final AssignedShiftInfo? assignedShift;
  final ApprovedRemoteInfo? approvedRemote;
  final AttendancePolicyInfo? policy;
  final OvertimeInfo? overtime;
  final bool isRemoteWorkActive;
  final String workMode;

  MyAttendanceStatus({
    this.employee,
    this.assignedOffice,
    required this.status,
    this.todayAttendance,
    this.assignedShift,
    this.approvedRemote,
    this.policy,
    this.overtime,
    this.isRemoteWorkActive = false,
    this.workMode = 'OFFICE',
  });

  factory MyAttendanceStatus.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> root = (json['data'] is Map)
        ? Map<String, dynamic>.from(json['data'])
        : json;

    return MyAttendanceStatus(
      employee: root['employee'] != null
          ? EmployeeShortInfo.fromJson(
              Map<String, dynamic>.from(root['employee']),
            )
          : null,
      assignedOffice: (root['assignedOffice'] != null || root['office'] != null)
          ? AssignedOffice.fromJson(
              Map<String, dynamic>.from(
                root['assignedOffice'] ?? root['office'],
              ),
            )
          : null,
      status: root['status'] != null
          ? AttendanceStatusDetails.fromJson(
              Map<String, dynamic>.from(root['status']),
            )
          : AttendanceStatusDetails.empty(),
      todayAttendance: root['todayAttendance'] != null
          ? Map<String, dynamic>.from(root['todayAttendance'])
          : null,
      assignedShift: root['assignedShift'] != null
          ? AssignedShiftInfo.fromJson(
              Map<String, dynamic>.from(root['assignedShift']),
            )
          : null,
      approvedRemote: root['approvedRemote'] != null
          ? ApprovedRemoteInfo.fromJson(
              Map<String, dynamic>.from(root['approvedRemote']),
            )
          : null,
      policy: root['policy'] != null
          ? AttendancePolicyInfo.fromJson(
              Map<String, dynamic>.from(root['policy']),
            )
          : null,
      overtime: root['overtime'] != null
          ? OvertimeInfo.fromJson(
              Map<String, dynamic>.from(root['overtime']),
            )
          : null,
      isRemoteWorkActive:
          root['isRemoteWorkActive'] == true ||
          (root['approvedRemote'] != null &&
              root['approvedRemote']['isCurrentlyActive'] == true),
      workMode: (root['workMode'] ?? 'OFFICE').toString(),
    );
  }

  factory MyAttendanceStatus.empty() {
    return MyAttendanceStatus(status: AttendanceStatusDetails.empty());
  }
}

class AssignedShiftInfo {
  final dynamic id;
  final String name;
  final String code;
  final String startTime;
  final String endTime;
  final double durationHours;
  final int gracePeriodMinutes;
  final int breakDurationMinutes;

  AssignedShiftInfo({
    required this.id,
    required this.name,
    required this.code,
    required this.startTime,
    required this.endTime,
    required this.durationHours,
    required this.gracePeriodMinutes,
    required this.breakDurationMinutes,
  });

  factory AssignedShiftInfo.fromJson(Map<String, dynamic> json) {
    return AssignedShiftInfo(
      id: json['id'],
      name: (json['name'] ?? 'General Shift').toString(),
      code: (json['code'] ?? 'GEN').toString(),
      startTime: (json['startTime'] ?? '09:30 AM').toString(),
      endTime: (json['endTime'] ?? '06:30 PM').toString(),
      durationHours: (json['durationHours'] as num?)?.toDouble() ?? 9.0,
      gracePeriodMinutes: (json['gracePeriodMinutes'] as num?)?.toInt() ?? 15,
      breakDurationMinutes:
          (json['breakDurationMinutes'] as num?)?.toInt() ?? 60,
    );
  }
}

class ApprovedRemoteInfo {
  final dynamic id;
  final String status;
  final String reason;
  final String? fromDate;
  final String? toDate;
  final String? startTime;
  final String? endTime;
  final bool isCurrentlyActive;

  ApprovedRemoteInfo({
    required this.id,
    required this.status,
    required this.reason,
    this.fromDate,
    this.toDate,
    this.startTime = '09:00 AM',
    this.endTime = '06:00 PM',
    this.isCurrentlyActive = false,
  });

  factory ApprovedRemoteInfo.fromJson(Map<String, dynamic> json) {
    return ApprovedRemoteInfo(
      id: json['id'],
      status: (json['status'] ?? 'APPROVED').toString(),
      reason: (json['reason'] ?? 'Approved Remote Duty').toString(),
      fromDate: json['fromDate']?.toString(),
      toDate: json['toDate']?.toString(),
      startTime: (json['startTime'] ?? '09:00 AM').toString(),
      endTime: (json['endTime'] ?? '06:00 PM').toString(),
      isCurrentlyActive: json['isCurrentlyActive'] == true,
    );
  }
}

class AttendancePolicyInfo {
  final String officeStartTime;
  final String officeEndTime;
  final int gracePeriodMinutes;
  final double minWorkingHours;

  AttendancePolicyInfo({
    required this.officeStartTime,
    required this.officeEndTime,
    required this.gracePeriodMinutes,
    required this.minWorkingHours,
  });

  factory AttendancePolicyInfo.fromJson(Map<String, dynamic> json) {
    return AttendancePolicyInfo(
      officeStartTime: (json['officeStartTime'] ?? '09:30').toString(),
      officeEndTime: (json['officeEndTime'] ?? '18:30').toString(),
      gracePeriodMinutes: (json['gracePeriodMinutes'] as num?)?.toInt() ?? 15,
      minWorkingHours: (json['minWorkingHours'] as num?)?.toDouble() ?? 8.0,
    );
  }
}

class EmployeeShortInfo {
  final dynamic id;
  final String employeeCode;
  final String name;
  final String email;
  final String department;
  final String designation;
  final String? profilePhoto;
  final String? phone;

  EmployeeShortInfo({
    required this.id,
    required this.employeeCode,
    required this.name,
    required this.email,
    required this.department,
    required this.designation,
    this.profilePhoto,
    this.phone,
  });

  factory EmployeeShortInfo.fromJson(Map<String, dynamic> json) {
    final directName =
        (json['name'] ?? json['fullName'] ?? json['employeeName'] ?? '')
            .toString()
            .trim();
    final fName = (json['firstName'] ?? json['first_name'] ?? '')
        .toString()
        .trim();
    final lName = (json['lastName'] ?? json['last_name'] ?? '')
        .toString()
        .trim();
    final combinedName = directName.isNotEmpty
        ? directName
        : [fName, lName].where((s) => s.isNotEmpty).join(' ');

    return EmployeeShortInfo(
      id: json['id'],
      employeeCode: (json['employeeCode'] ?? json['code'] ?? 'EMP-001')
          .toString()
          .trim(),
      name: combinedName.isNotEmpty ? combinedName : '',
      email: (json['email'] ?? '').toString().trim(),
      department: (json['department'] ?? 'General').toString().trim(),
      designation: (json['designation'] ?? 'Staff').toString().trim(),
      profilePhoto:
          (json['profilePhoto'] ??
                  json['avatar'] ??
                  json['profileImage'] ??
                  json['photo'])
              ?.toString(),
      phone: (json['phone'] ?? json['mobile'] ?? '').toString().trim(),
    );
  }
}

class AssignedOffice {
  final dynamic id;
  final String name;
  final String city;
  final double latitude;
  final double longitude;
  final double radiusMeters;

  AssignedOffice({
    required this.id,
    required this.name,
    required this.city,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
  });

  factory AssignedOffice.fromJson(Map<String, dynamic> json) {
    return AssignedOffice(
      id: json['id'],
      name: (json['name'] ?? 'Main Office').toString(),
      city: (json['city'] ?? '').toString(),
      latitude: (json['latitude'] != null
          ? (json['latitude'] as num).toDouble()
          : 0.0),
      longitude: (json['longitude'] != null
          ? (json['longitude'] as num).toDouble()
          : 0.0),
      radiusMeters: (json['radiusMeters'] != null
          ? (json['radiusMeters'] as num).toDouble()
          : 200.0),
    );
  }

  /// Calculates geodesic distance in meters from given coordinates.
  double distanceTo(double lat, double lon) {
    const double r = 6371000; // Earth radius in meters
    final double phi1 = latitude * (pi / 180.0);
    final double phi2 = lat * (pi / 180.0);
    final double deltaPhi = (lat - latitude) * (pi / 180.0);
    final double deltaLambda = (lon - longitude) * (pi / 180.0);

    final double a =
        sin(deltaPhi / 2) * sin(deltaPhi / 2) +
        cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return r * c;
  }
}

class AttendanceStatusDetails {
  final bool isPunchedIn;
  final bool isOnBreak;
  final String? activeBreakStart;
  final String? punchInTime;
  final String? punchOutTime;
  final double workingHours;
  final double breakDuration;
  final bool hasWorkingHours;
  final bool hasBreakDuration;
  final String rawStatus;

  AttendanceStatusDetails({
    required this.isPunchedIn,
    required this.isOnBreak,
    this.activeBreakStart,
    this.punchInTime,
    this.punchOutTime,
    required this.workingHours,
    required this.breakDuration,
    this.hasWorkingHours = true,
    this.hasBreakDuration = true,
    required this.rawStatus,
  });

  factory AttendanceStatusDetails.fromJson(Map<String, dynamic> json) {
    return AttendanceStatusDetails(
      isPunchedIn: json['isPunchedIn'] == true,
      isOnBreak: json['isOnBreak'] == true,
      activeBreakStart: json['activeBreakStart']?.toString(),
      punchInTime: json['punchInTime']?.toString(),
      punchOutTime: json['punchOutTime']?.toString(),
      workingHours: (json['workingHours'] as num?)?.toDouble() ?? 0.0,
      breakDuration: (json['breakDuration'] as num?)?.toDouble() ?? 0.0,
      hasWorkingHours: json['workingHours'] is num,
      hasBreakDuration: json['breakDuration'] is num,
      rawStatus: (json['rawStatus'] ?? 'NOT_MARKED').toString(),
    );
  }

  factory AttendanceStatusDetails.empty() {
    return AttendanceStatusDetails(
      isPunchedIn: false,
      isOnBreak: false,
      workingHours: 0.0,
      breakDuration: 0.0,
      hasWorkingHours: false,
      hasBreakDuration: false,
      rawStatus: 'NOT_MARKED',
    );
  }

  /// Whether today's attendance has been completed (punched out).
  bool get isCompleted =>
      !isPunchedIn && punchInTime != null && punchOutTime != null;

  /// Current 5-phase attendance state
  EmployeeAttendancePhase get phase {
    if (isCompleted) {
      return EmployeeAttendancePhase.completed;
    }
    if (isOnBreak) {
      return EmployeeAttendancePhase.onBreak;
    }
    if (isPunchedIn) {
      // If we have breaks recorded previously
      if (breakDuration > 0) {
        return EmployeeAttendancePhase.workingAfterBreak;
      }
      return EmployeeAttendancePhase.checkedIn;
    }
    return EmployeeAttendancePhase.notCheckedIn;
  }
}

enum EmployeeAttendancePhase {
  notCheckedIn,
  checkedIn,
  onBreak,
  workingAfterBreak,
  completed,
}

/// Representation of an Attendance history log entry
class AttendanceLogItem {
  final String id;
  final String date;
  final String day;
  final String checkIn;
  final String checkOut;
  final String workingHours;
  final String breakDuration;
  final int breaksCount;
  final String status;
  final bool isLate;
  final String location;
  final DateTime? parsedDate;

  AttendanceLogItem({
    required this.id,
    required this.date,
    required this.day,
    required this.checkIn,
    required this.checkOut,
    required this.workingHours,
    required this.breakDuration,
    required this.breaksCount,
    required this.status,
    required this.isLate,
    required this.location,
    this.parsedDate,
  });

  factory AttendanceLogItem.fromJson(Map<String, dynamic> json) {
    final statusStr = (json['status'] ?? 'PRESENT').toString().toUpperCase();
    final bool isLateCalc = statusStr == 'LATE' || statusStr.contains('LATE');

    final rawCheckIn = json['punchIn'] ?? json['punchInAt'] ?? json['checkIn'];
    final rawCheckOut =
        json['punchOut'] ?? json['punchOutAt'] ?? json['checkOut'];

    final rawDate = (json['date'] ?? json['attendanceDate'] ?? '').toString();
    DateTime? dt;
    if (rawDate.isNotEmpty && rawDate != '—') {
      dt = DateTime.tryParse(rawDate) ?? AppDateFormatter.parseToLocal(rawDate);
    }

    String dayStr = (json['day'] ?? '').toString().trim();
    if (dayStr.isEmpty && dt != null) {
      const dayNames = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      dayStr = dayNames[dt.weekday - 1];
    }

    return AttendanceLogItem(
      id: (json['id'] ?? '').toString(),
      date: rawDate,
      day: dayStr,
      checkIn: AppDateFormatter.formatAttendanceTime(rawCheckIn),
      checkOut: AppDateFormatter.formatAttendanceTime(rawCheckOut),
      workingHours: AppDateFormatter.formatDurationHoursMinutes(
        json['workingMinutes'] ?? json['workingHours'],
      ),
      breakDuration: AppDateFormatter.formatDurationHoursMinutes(
        json['totalBreakMinutes'] ??
            json['totalBreak'] ??
            json['breakDuration'],
      ),
      breaksCount: (json['breaksCount'] as num?)?.toInt() ?? 0,
      status: statusStr,
      isLate: isLateCalc,
      location: (json['location'] ?? json['branch'] ?? 'Head Office')
          .toString(),
      parsedDate: dt,
    );
  }

  /// Normalized YYYY-MM-DD date key for grouping and deduplication
  String get normalizedDateKey {
    if (parsedDate != null) {
      final y = parsedDate!.year.toString().padLeft(4, '0');
      final m = parsedDate!.month.toString().padLeft(2, '0');
      final d = parsedDate!.day.toString().padLeft(2, '0');
      return '$y-$m-$d';
    }
    final raw = date.trim();
    if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(raw)) {
      return raw.substring(0, 10);
    }
    return raw;
  }

  /// Consolidates attendance entries by unique calendar date so that
  /// exactly ONE daily attendance record card is shown per date.
  static List<AttendanceLogItem> consolidateDaily(
    List<AttendanceLogItem> items,
  ) {
    if (items.isEmpty) return const [];

    final Map<String, AttendanceLogItem> dailyMap = {};
    for (final item in items) {
      final key = item.normalizedDateKey;
      if (!dailyMap.containsKey(key)) {
        dailyMap[key] = item;
      } else {
        final existing = dailyMap[key]!;

        // Pick earliest valid check-in
        final checkIn =
            (existing.checkIn != '—' &&
                existing.checkIn != '--:--' &&
                existing.checkIn.isNotEmpty)
            ? existing.checkIn
            : item.checkIn;

        // Pick latest valid check-out
        final checkOut =
            (item.checkOut != '—' &&
                item.checkOut != '--:--' &&
                item.checkOut.isNotEmpty)
            ? item.checkOut
            : existing.checkOut;

        // Best status
        final status =
            (existing.status == 'PRESENT' || item.status == 'PRESENT')
            ? 'PRESENT'
            : (existing.status.contains('LATE') || item.status.contains('LATE'))
            ? 'LATE'
            : existing.status;

        // Best location
        final location =
            (existing.location.isNotEmpty && existing.location != 'Head Office')
            ? existing.location
            : (item.location.isNotEmpty ? item.location : existing.location);

        // Working hours & break duration
        final workingHours =
            (existing.workingHours != '0h 0m' && existing.workingHours != '—')
            ? existing.workingHours
            : item.workingHours;

        final breakDuration =
            (existing.breakDuration != '0h 0m' && existing.breakDuration != '—')
            ? existing.breakDuration
            : item.breakDuration;

        dailyMap[key] = AttendanceLogItem(
          id: existing.id,
          date: existing.date,
          day: existing.day.isNotEmpty ? existing.day : item.day,
          checkIn: checkIn,
          checkOut: checkOut,
          workingHours: workingHours,
          breakDuration: breakDuration,
          breaksCount: max(existing.breaksCount, item.breaksCount),
          status: status,
          isLate: existing.isLate || item.isLate,
          location: location,
          parsedDate: existing.parsedDate ?? item.parsedDate,
        );
      }
    }

    final list = dailyMap.values.toList();
    list.sort((a, b) {
      if (a.parsedDate != null && b.parsedDate != null) {
        return b.parsedDate!.compareTo(a.parsedDate!);
      }
      return b.normalizedDateKey.compareTo(a.normalizedDateKey);
    });
    return list;
  }
}

class OvertimeInfo {
  final bool isEligible;
  final OvertimeRequestItem? activeRequest;

  OvertimeInfo({
    required this.isEligible,
    this.activeRequest,
  });

  factory OvertimeInfo.fromJson(Map<String, dynamic> json) {
    return OvertimeInfo(
      isEligible: json['isEligible'] == true,
      activeRequest: json['activeRequest'] != null
          ? OvertimeRequestItem.fromJson(
              Map<String, dynamic>.from(json['activeRequest']),
            )
          : null,
    );
  }
}

class OvertimeRequestItem {
  final int id;
  final String status; // PENDING, APPROVED, REJECTED, IN_PROGRESS, COMPLETED, CANCELLED
  final String otType; // PRE_SHIFT, POST_SHIFT
  final String otDate;
  final String plannedStartTime;
  final String plannedEndTime;
  final int plannedDurationMinutes;
  final int? approvedDurationMinutes;
  final String? actualStartTime;
  final String? actualEndTime;
  final String? serverNow;
  final int? payableMinutes;
  final int? remainingApprovedMinutes;
  final double payableHours;
  final String reason;
  final String? rejectionReason;
  final String? approvedByName;
  final String? approvedAt;
  final bool cancellationRejected;
  final String? cancellationReason;
  final String? cancellationDecisionNotes;

  OvertimeRequestItem({
    required this.id,
    required this.status,
    required this.otType,
    required this.otDate,
    required this.plannedStartTime,
    required this.plannedEndTime,
    required this.plannedDurationMinutes,
    this.approvedDurationMinutes,
    this.actualStartTime,
    this.actualEndTime,
    this.serverNow,
    this.payableMinutes,
    this.remainingApprovedMinutes,
    this.payableHours = 0.0,
    required this.reason,
    this.rejectionReason,
    this.approvedByName,
    this.approvedAt,
    this.cancellationRejected = false,
    this.cancellationReason,
    this.cancellationDecisionNotes,
  });

  factory OvertimeRequestItem.fromJson(Map<String, dynamic> json) {
    final rawStatus = (json['sessionStatus'] ?? json['status'] ?? 'PENDING')
        .toString()
        .toUpperCase();
    final cancellationRejected = rawStatus == 'CANCELLATION_REJECTED';
    final date = (json['overtimeDate'] ?? json['otDate'] ?? '').toString();
    return OvertimeRequestItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      status: cancellationRejected ? 'APPROVED' : rawStatus,
      otType: (json['overtimeType'] ?? json['otType'] ?? 'AFTER_SHIFT')
          .toString()
          .toUpperCase(),
      otDate: date.length >= 10 ? date.substring(0, 10) : date,
      plannedStartTime: (json['startTime'] ?? json['plannedStartTime'] ?? '')
          .toString(),
      plannedEndTime: (json['endTime'] ?? json['plannedEndTime'] ?? '')
          .toString(),
      plannedDurationMinutes:
          (json['totalMinutes'] as num?)?.toInt() ??
          (json['plannedDurationMinutes'] as num?)?.toInt() ??
          0,
      approvedDurationMinutes:
          (json['approvedMinutes'] as num?)?.toInt() ??
          (json['approvedDurationMinutes'] as num?)?.toInt(),
      actualStartTime: json['actualStartAt']?.toString() ?? json['actualStartTime']?.toString(),
      actualEndTime: json['actualEndAt']?.toString() ?? json['actualEndTime']?.toString(),
      serverNow: json['serverNow']?.toString(),
      payableMinutes: (json['payableMinutes'] as num?)?.toInt(),
      remainingApprovedMinutes: (json['remainingApprovedMinutes'] as num?)?.toInt(),
      payableHours: (json['payableHours'] as num?)?.toDouble() ??
          (json['actualHours'] as num?)?.toDouble() ??
          0.0,
      reason: (json['reason'] ?? '').toString(),
      rejectionReason: json['rejectionReason']?.toString(),
      approvedByName: json['approvedByName']?.toString(),
      approvedAt: json['approvedAt']?.toString(),
      cancellationRejected: cancellationRejected,
      cancellationReason: json['cancellationReason']?.toString(),
      cancellationDecisionNotes: json['cancellationDecisionNotes']?.toString(),
    );
  }

  bool get isPending => status == 'PENDING';
  bool get isApproved => status == 'APPROVED';
  bool get isInProgress => status == 'IN_PROGRESS';
  bool get isCompleted => status == 'COMPLETED';
  bool get isRejected => status == 'REJECTED';
  bool get isCancellationRequested => status == 'CANCELLATION_REQUESTED';
  bool get isCancelled => status == 'CANCELLED';

  String get displayStatus {
    if (isCancellationRequested) return 'Cancellation Requested';
    if (cancellationRejected) return 'Cancellation Rejected';
    if (isCancelled) return 'Cancelled';
    if (isApproved) return 'Approved';
    if (isPending) return 'Pending';
    if (isRejected) return 'Rejected';
    if (isInProgress) return 'In Progress';
    if (isCompleted) return 'Completed';
    return status;
  }
}

