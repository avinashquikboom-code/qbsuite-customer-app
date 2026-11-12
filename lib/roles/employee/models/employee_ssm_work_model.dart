enum SSMWorkType {
  reel,
  post,
  shoot;

  String get displayName {
    switch (this) {
      case SSMWorkType.reel:
        return 'Reel';
      case SSMWorkType.post:
        return 'Post';
      case SSMWorkType.shoot:
        return 'Shoot';
    }
  }

  int get defaultDurationDays {
    switch (this) {
      case SSMWorkType.reel:
        return 3;
      case SSMWorkType.shoot:
        return 3;
      case SSMWorkType.post:
        return 1;
    }
  }

  static SSMWorkType parse(dynamic val) {
    if (val == null) return SSMWorkType.reel;
    final s = val.toString().toUpperCase();
    if (s.contains('POST') ||
        s.contains('GRAPHIC') ||
        s.contains('BANNER') ||
        s.contains('CREATIVE')) {
      return SSMWorkType.post;
    }
    if (s.contains('SHOOT') && !s.contains('REEL')) {
      return SSMWorkType.shoot;
    }
    return SSMWorkType.reel;
  }
}

enum SSMWorkStatus {
  scheduled,
  inProgress,
  completed,
  cancelled;

  String get displayName {
    switch (this) {
      case SSMWorkStatus.scheduled:
        return 'Scheduled';
      case SSMWorkStatus.inProgress:
        return 'In Progress';
      case SSMWorkStatus.completed:
        return 'Completed';
      case SSMWorkStatus.cancelled:
        return 'Cancelled';
    }
  }

  static SSMWorkStatus parse(dynamic val) {
    if (val == null) return SSMWorkStatus.scheduled;
    final s = val.toString().toUpperCase();
    if (s.contains('PROGRESS') ||
        s.contains('STARTED') ||
        s.contains('REVIEW') ||
        s.contains('CUSTOMER_REVIEW')) {
      return SSMWorkStatus.inProgress;
    }
    if (s.contains('COMPLET') || s.contains('DONE') || s.contains('APPROVED')) {
      return SSMWorkStatus.completed;
    }
    if (s.contains('CANCEL')) {
      return SSMWorkStatus.cancelled;
    }
    return SSMWorkStatus.scheduled;
  }
}

class SSMTaskStage {
  final int dayNumber;
  final String title;
  final String description;
  final DateTime date;
  final bool isCompleted;

  const SSMTaskStage({
    required this.dayNumber,
    required this.title,
    required this.description,
    required this.date,
    this.isCompleted = false,
  });

  factory SSMTaskStage.fromJson(
    Map<String, dynamic> json, {
    int fallbackDay = 1,
    DateTime? baseDate,
  }) {
    final dayNum = json['dayNumber'] is int
        ? json['dayNumber'] as int
        : (json['stepOrder'] is int
              ? json['stepOrder'] as int
              : int.tryParse(
                      json['stepOrder']?.toString() ??
                          json['dayNumber']?.toString() ??
                          '$fallbackDay',
                    ) ??
                    fallbackDay);
    final title = (json['title'] ?? 'Deliverable Stage $dayNum')
        .toString()
        .trim();
    final desc =
        (json['description'] ?? json['notes'] ?? 'Deliverable task details.')
            .toString()
            .trim();

    DateTime date;
    if (json['date'] != null) {
      date =
          DateTime.tryParse(json['date'].toString()) ??
          baseDate ??
          DateTime.now();
    } else if (json['createdAt'] != null) {
      date =
          DateTime.tryParse(json['createdAt'].toString()) ??
          baseDate ??
          DateTime.now();
    } else {
      date = baseDate != null
          ? baseDate.add(Duration(days: dayNum - 1))
          : DateTime.now();
    }

    final statusStr = json['status']?.toString().toUpperCase() ?? '';
    final isDone = json['isCompleted'] == true || statusStr == 'COMPLETED';

    return SSMTaskStage(
      dayNumber: dayNum,
      title: title,
      description: desc,
      date: date,
      isCompleted: isDone,
    );
  }

  SSMTaskStage copyWith({
    int? dayNumber,
    String? title,
    String? description,
    DateTime? date,
    bool? isCompleted,
  }) {
    return SSMTaskStage(
      dayNumber: dayNumber ?? this.dayNumber,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

class SSMWorkSchedule {
  final String id;
  final String customerName;
  final String customerBusiness;
  final String socialMediaAccount;
  final String platform; // Instagram, Facebook, YouTube, LinkedIn
  final SSMWorkType workType;
  final DateTime startDate;
  final int durationDays;
  final DateTime endDate;
  final String assignedTeam; // "SSM Team A" or "SSM Team B"
  final List<String> assignedEmployees;
  final String priority; // "Low", "Medium", "High"
  final String notes;
  final SSMWorkStatus status;
  final List<SSMTaskStage> dailyTasks;
  final DateTime createdAt;

  const SSMWorkSchedule({
    required this.id,
    required this.customerName,
    required this.customerBusiness,
    required this.socialMediaAccount,
    required this.platform,
    required this.workType,
    required this.startDate,
    required this.durationDays,
    required this.endDate,
    required this.assignedTeam,
    required this.assignedEmployees,
    this.priority = 'Medium',
    this.notes = '',
    this.status = SSMWorkStatus.scheduled,
    required this.dailyTasks,
    required this.createdAt,
  });

  factory SSMWorkSchedule.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? json['activityId'] ?? '').toString();
    final custName = (json['customerName'] ?? 'Customer').toString().trim();
    final custBusiness =
        (json['customerBusiness'] ?? json['companyName'] ?? custName)
            .toString()
            .trim();
    final platform = (json['platform'] ?? 'Instagram').toString().trim();
    final smAccount =
        (json['socialMediaAccount'] ??
                (custName.isNotEmpty
                    ? '@${custName.toLowerCase().replaceAll(RegExp(r'\s+'), '')}'
                    : '@customer'))
            .toString()
            .trim();
    final workType = SSMWorkType.parse(
      json['workType'] ?? json['type'] ?? json['activityType'],
    );
    final status = SSMWorkStatus.parse(json['status']);

    DateTime startDate;
    if (json['scheduledDate'] != null) {
      startDate =
          DateTime.tryParse(json['scheduledDate'].toString()) ?? DateTime.now();
    } else if (json['date'] != null) {
      startDate = DateTime.tryParse(json['date'].toString()) ?? DateTime.now();
    } else {
      startDate = DateTime.now();
    }

    final durationDays = json['durationDays'] is int
        ? json['durationDays'] as int
        : int.tryParse(
                json['durationDays']?.toString() ??
                    '${workType.defaultDurationDays}',
              ) ??
              workType.defaultDurationDays;

    DateTime endDate;
    if (json['endDate'] != null) {
      endDate =
          DateTime.tryParse(json['endDate'].toString()) ??
          startDate.add(
            Duration(days: durationDays > 1 ? durationDays - 1 : 0),
          );
    } else {
      endDate = startDate.add(
        Duration(days: durationDays > 1 ? durationDays - 1 : 0),
      );
    }

    final team = (json['assignedTeam'] ?? json['team'] ?? 'Creative Team')
        .toString()
        .trim();

    final rawEmps = json['assignedEmployees'];
    final List<String> assignedEmps = [];
    if (rawEmps is List) {
      for (final e in rawEmps) {
        if (e != null) {
          final s = e.toString().trim();
          if (s.isNotEmpty && !assignedEmps.contains(s)) assignedEmps.add(s);
        }
      }
    }
    if (assignedEmps.isEmpty) {
      final singleEmp =
          (json['assignedEmployee'] ?? json['assignedToName'] ?? '')
              .toString()
              .trim();
      if (singleEmp.isNotEmpty && singleEmp != 'Staff') {
        assignedEmps.add(singleEmp);
      }
      final editor = (json['editorName'] ?? '').toString().trim();
      if (editor.isNotEmpty && !assignedEmps.contains(editor)) {
        assignedEmps.add(editor);
      }
    }

    // Daily tasks
    final tasks = <SSMTaskStage>[];
    final rawTasks = json['tasks'] ?? json['dailyTasks'];
    if (rawTasks is List && rawTasks.isNotEmpty) {
      for (int i = 0; i < rawTasks.length; i++) {
        final t = rawTasks[i];
        if (t is Map<String, dynamic>) {
          tasks.add(
            SSMTaskStage.fromJson(t, fallbackDay: i + 1, baseDate: startDate),
          );
        } else if (t is Map) {
          tasks.add(
            SSMTaskStage.fromJson(
              Map<String, dynamic>.from(t),
              fallbackDay: i + 1,
              baseDate: startDate,
            ),
          );
        }
      }
    } else {
      final defaultTitles = workType == SSMWorkType.reel
          ? [
              'Shoot / Content Capture',
              'Editing / Production',
              'Final Review / Submission',
            ]
          : (workType == SSMWorkType.shoot
                ? [
                    'Location / Preparation',
                    'Shooting',
                    'Remaining Shots / Backup',
                  ]
                : ['Post Creation / Publishing']);
      final defaultDescs = workType == SSMWorkType.reel
          ? [
              'On-site video recording, angle capture, and b-roll footage.',
              'Color grading, audio sync, effects, and typography overlays.',
              'Client review, revisions, caption writing, and upload preparation.',
            ]
          : (workType == SSMWorkType.shoot
                ? [
                    'Equipment setup, lighting check, venue staging, and talent briefing.',
                    'Full schedule shoot execution, interview takes, and product captures.',
                    'B-roll pickups, RAW data backup, and handoff to editor.',
                  ]
                : [
                    'Design creative banner, write engaging hashtags, and publish.',
                  ]);

      for (int i = 0; i < durationDays; i++) {
        final taskDate = startDate.add(Duration(days: i));
        final title = i < defaultTitles.length
            ? defaultTitles[i]
            : '${workType.displayName} Deliverable ${i + 1}';
        final desc = i < defaultDescs.length
            ? defaultDescs[i]
            : 'Deliverable execution and review.';
        tasks.add(
          SSMTaskStage(
            dayNumber: i + 1,
            title: title,
            description: desc,
            date: taskDate,
            isCompleted: status == SSMWorkStatus.completed,
          ),
        );
      }
    }

    DateTime createdAt;
    if (json['createdAt'] != null) {
      createdAt = DateTime.tryParse(json['createdAt'].toString()) ?? startDate;
    } else {
      createdAt = startDate;
    }

    return SSMWorkSchedule(
      id: id,
      customerName: custName,
      customerBusiness: custBusiness,
      socialMediaAccount: smAccount,
      platform: platform,
      workType: workType,
      startDate: startDate,
      durationDays: durationDays,
      endDate: endDate,
      assignedTeam: team,
      assignedEmployees: assignedEmps,
      priority: (json['priority'] ?? 'Medium').toString(),
      notes: (json['notes'] ?? json['title'] ?? '').toString(),
      status: status,
      dailyTasks: tasks,
      createdAt: createdAt,
    );
  }

  /// Get current active day number (1-indexed, or last day if completed)
  int getCurrentDayNumber(DateTime targetDate) {
    if (targetDate.isBefore(startDate)) return 1;
    final diff = targetDate.difference(startDate).inDays;
    final currentDay = diff + 1;
    if (currentDay > durationDays) return durationDays;
    if (currentDay < 1) return 1;
    return currentDay;
  }

  /// Get task for specific day number
  SSMTaskStage? getTaskForDay(int dayNumber) {
    try {
      return dailyTasks.firstWhere((t) => t.dayNumber == dayNumber);
    } catch (_) {
      return null;
    }
  }

  /// Get task for specific date
  SSMTaskStage? getTaskForDate(DateTime date) {
    try {
      return dailyTasks.firstWhere(
        (t) =>
            t.date.year == date.year &&
            t.date.month == date.month &&
            t.date.day == date.day,
      );
    } catch (_) {
      return null;
    }
  }

  /// Checks if work spans across the given date
  bool spansDate(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    return !d.isBefore(start) && !d.isAfter(end);
  }

  SSMWorkSchedule copyWith({
    String? id,
    String? customerName,
    String? customerBusiness,
    String? socialMediaAccount,
    String? platform,
    SSMWorkType? workType,
    DateTime? startDate,
    int? durationDays,
    DateTime? endDate,
    String? assignedTeam,
    List<String>? assignedEmployees,
    String? priority,
    String? notes,
    SSMWorkStatus? status,
    List<SSMTaskStage>? dailyTasks,
    DateTime? createdAt,
  }) {
    return SSMWorkSchedule(
      id: id ?? this.id,
      customerName: customerName ?? this.customerName,
      customerBusiness: customerBusiness ?? this.customerBusiness,
      socialMediaAccount: socialMediaAccount ?? this.socialMediaAccount,
      platform: platform ?? this.platform,
      workType: workType ?? this.workType,
      startDate: startDate ?? this.startDate,
      durationDays: durationDays ?? this.durationDays,
      endDate: endDate ?? this.endDate,
      assignedTeam: assignedTeam ?? this.assignedTeam,
      assignedEmployees: assignedEmployees ?? this.assignedEmployees,
      priority: priority ?? this.priority,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      dailyTasks: dailyTasks ?? this.dailyTasks,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class SSMClientSummary {
  final String customerName;
  final String customerBusiness;
  final String socialMediaAccount;
  final String platform;
  final String assignedTeam;
  final List<String> assignedEmployees;
  final List<SSMWorkSchedule> allWorks;

  const SSMClientSummary({
    required this.customerName,
    required this.customerBusiness,
    required this.socialMediaAccount,
    required this.platform,
    required this.assignedTeam,
    required this.assignedEmployees,
    required this.allWorks,
  });

  List<SSMWorkSchedule> get activeWorks =>
      allWorks.where((w) => w.status == SSMWorkStatus.inProgress).toList();

  List<SSMWorkSchedule> get upcomingWorks =>
      allWorks.where((w) => w.status == SSMWorkStatus.scheduled).toList();

  List<SSMWorkSchedule> get completedWorks =>
      allWorks.where((w) => w.status == SSMWorkStatus.completed).toList();

  SSMWorkSchedule get primaryWork {
    if (activeWorks.isNotEmpty) return activeWorks.first;
    if (upcomingWorks.isNotEmpty) return upcomingWorks.first;
    return allWorks.first;
  }

  String get clientStatus {
    if (activeWorks.isNotEmpty) return 'ACTIVE';
    if (upcomingWorks.isNotEmpty) return 'UPCOMING';
    if (completedWorks.isNotEmpty) return 'COMPLETED';
    return 'INACTIVE';
  }
}

class EmployeeActivityEvent {
  final String id;
  final String title;
  final String description;
  final String customerName;
  final String team;
  final DateTime timestamp;
  final String timeText;

  const EmployeeActivityEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.customerName,
    required this.team,
    required this.timestamp,
    required this.timeText,
  });
}
