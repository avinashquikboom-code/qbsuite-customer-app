import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickboom_crm_customer/roles/employee/models/employee_ssm_work_model.dart';
import 'package:quickboom_crm_customer/roles/employee/services/employee_ssm_service.dart';

class EmployeeSSMState {
  final List<SSMWorkSchedule> allSchedules;
  final List<EmployeeActivityEvent> activityEvents;
  final String calendarFilter; // 'My Work', 'All', 'SSM Team A', 'SSM Team B'
  final DateTime selectedCalendarDate;
  final String currentEmployeeName;
  final String currentEmployeeTeam;
  final DateTime todayDate;
  final String clientTab; // 'Active', 'Upcoming', 'Completed', 'All'
  final bool isLoading;
  final bool isError;
  final String? errorMessage;

  const EmployeeSSMState({
    required this.allSchedules,
    this.activityEvents = const [],
    this.calendarFilter = 'My Work',
    this.clientTab = 'Active',
    required this.selectedCalendarDate,
    this.currentEmployeeName = '',
    this.currentEmployeeTeam = '',
    required this.todayDate,
    this.isLoading = false,
    this.isError = false,
    this.errorMessage,
  });

  /// Work strictly visible to current employee.
  /// Because allSchedules is fetched from the employee-scoped backend API (/works/employee/calendar),
  /// it contains only the tasks/activities assigned to the authenticated employee and their team.
  List<SSMWorkSchedule> get myWorkSchedules {
    if (currentEmployeeName.isEmpty && currentEmployeeTeam.isEmpty) {
      return allSchedules;
    }
    // If specific employee/team context is set, apply filtering if applicable
    return allSchedules.where((s) {
      if (s.assignedEmployees.isEmpty && s.assignedTeam.isEmpty) return true;
      final isDirectlyAssigned =
          currentEmployeeName.isNotEmpty &&
          s.assignedEmployees.contains(currentEmployeeName);
      final isTeamAssigned =
          currentEmployeeTeam.isNotEmpty &&
          s.assignedTeam == currentEmployeeTeam;
      return isDirectlyAssigned ||
          isTeamAssigned ||
          s.assignedEmployees.isEmpty;
    }).toList();
  }

  /// Single-card per customer grouping derived from employee's assigned work
  List<SSMClientSummary> get myClients {
    final Map<String, List<SSMWorkSchedule>> customerMap = {};
    for (final work in myWorkSchedules) {
      customerMap.putIfAbsent(work.customerName, () => []).add(work);
    }

    return customerMap.entries.map((entry) {
      final works = entry.value;
      final first = works.first;
      return SSMClientSummary(
        customerName: entry.key,
        customerBusiness: first.customerBusiness,
        socialMediaAccount: first.socialMediaAccount,
        platform: first.platform,
        assignedTeam: first.assignedTeam,
        assignedEmployees: first.assignedEmployees,
        allWorks: works,
      );
    }).toList();
  }

  /// Clients with at least 1 work IN PROGRESS / STARTED
  List<SSMClientSummary> get activeClients =>
      myClients.where((c) => c.activeWorks.isNotEmpty).toList();

  /// Clients with only SCHEDULED works
  List<SSMClientSummary> get upcomingClients => myClients
      .where((c) => c.activeWorks.isEmpty && c.upcomingWorks.isNotEmpty)
      .toList();

  /// Clients where all assigned works are COMPLETED
  List<SSMClientSummary> get completedClients => myClients
      .where(
        (c) =>
            c.activeWorks.isEmpty &&
            c.upcomingWorks.isEmpty &&
            c.completedWorks.isNotEmpty,
      )
      .toList();

  /// Clients filtered by current selected tab
  List<SSMClientSummary> get displayedClients {
    switch (clientTab) {
      case 'Upcoming':
        return upcomingClients;
      case 'Completed':
        return completedClients;
      case 'All':
        return myClients;
      case 'Active':
      default:
        return activeClients;
    }
  }

  /// Today's work for logged-in employee
  List<SSMWorkSchedule> get todayWorkSchedules {
    return myWorkSchedules.where((s) => s.spansDate(todayDate)).toList();
  }

  /// Upcoming work for logged-in employee (starts after today)
  List<SSMWorkSchedule> get upcomingWorkSchedules {
    final today = DateTime(todayDate.year, todayDate.month, todayDate.day);
    return myWorkSchedules.where((s) {
      final start = DateTime(
        s.startDate.year,
        s.startDate.month,
        s.startDate.day,
      );
      return start.isAfter(today) && s.status != SSMWorkStatus.completed;
    }).toList();
  }

  /// Filtered schedules for calendar tab
  List<SSMWorkSchedule> get calendarFilteredSchedules {
    if (calendarFilter == 'All' ||
        calendarFilter == 'My Work' ||
        calendarFilter.trim().isEmpty) {
      return allSchedules;
    }
    return allSchedules
        .where((s) => s.assignedTeam == calendarFilter)
        .toList();
  }

  /// Schedules spanning the selected calendar date
  List<SSMWorkSchedule> get schedulesForSelectedDate {
    return calendarFilteredSchedules
        .where((s) => s.spansDate(selectedCalendarDate))
        .toList();
  }

  EmployeeSSMState copyWith({
    List<SSMWorkSchedule>? allSchedules,
    List<EmployeeActivityEvent>? activityEvents,
    String? calendarFilter,
    String? clientTab,
    DateTime? selectedCalendarDate,
    String? currentEmployeeName,
    String? currentEmployeeTeam,
    DateTime? todayDate,
    bool? isLoading,
    bool? isError,
    String? errorMessage,
  }) {
    return EmployeeSSMState(
      allSchedules: allSchedules ?? this.allSchedules,
      activityEvents: activityEvents ?? this.activityEvents,
      calendarFilter: calendarFilter ?? this.calendarFilter,
      clientTab: clientTab ?? this.clientTab,
      selectedCalendarDate: selectedCalendarDate ?? this.selectedCalendarDate,
      currentEmployeeName: currentEmployeeName ?? this.currentEmployeeName,
      currentEmployeeTeam: currentEmployeeTeam ?? this.currentEmployeeTeam,
      todayDate: todayDate ?? this.todayDate,
      isLoading: isLoading ?? this.isLoading,
      isError: isError ?? this.isError,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class EmployeeSSMNotifier extends Notifier<EmployeeSSMState> {
  @override
  EmployeeSSMState build() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Trigger initial asynchronous load from backend API
    Future.microtask(() => loadWorks());

    return EmployeeSSMState(
      allSchedules: const [],
      activityEvents: const [],
      calendarFilter: 'My Work',
      selectedCalendarDate: today,
      todayDate: today,
      isLoading: true,
      isError: false,
    );
  }

  EmployeeSSMService get _service => ref.read(employeeSSMServiceProvider);

  Future<void> loadWorks() async {
    state = state.copyWith(isLoading: true, isError: false, errorMessage: null);
    try {
      final works = await _service.fetchEmployeeWorks();
      state = state.copyWith(
        allSchedules: works,
        isLoading: false,
        isError: false,
      );
    } catch (e) {
      debugPrint('[EMPLOYEE_SSM_NOTIFIER] loadWorks error: $e');
      state = state.copyWith(
        isLoading: false,
        isError: true,
        errorMessage: 'Unable to load your work.',
      );
    }
  }

  Future<void> refresh() async {
    await loadWorks();
  }

  void setCalendarFilter(String filter) {
    state = state.copyWith(calendarFilter: filter);
  }

  void setClientTab(String tab) {
    state = state.copyWith(clientTab: tab);
  }

  void selectCalendarDate(DateTime date) {
    state = state.copyWith(selectedCalendarDate: date);
  }

  Future<bool> startWork(String workId) async {
    SSMWorkSchedule? startedWork;
    final prevSchedules = state.allSchedules;
    final updatedList = state.allSchedules.map((work) {
      if (work.id == workId) {
        startedWork = work;
        return work.copyWith(status: SSMWorkStatus.inProgress);
      }
      return work;
    }).toList();

    List<EmployeeActivityEvent> updatedEvents = state.activityEvents;
    if (startedWork != null) {
      final newEvent = EmployeeActivityEvent(
        id: 'act_${DateTime.now().millisecondsSinceEpoch}',
        title: '${startedWork!.workType.displayName} Shoot started',
        description:
            '${startedWork!.customerName} (${startedWork!.assignedTeam})',
        customerName: startedWork!.customerName,
        team: startedWork!.assignedTeam,
        timestamp: DateTime.now(),
        timeText: 'Today, 10:30 AM',
      );
      updatedEvents = [newEvent, ...state.activityEvents];
    }

    state = state.copyWith(
      allSchedules: updatedList,
      activityEvents: updatedEvents,
    );

    try {
      final success = await _service.startWork(workId);
      if (success) {
        await loadWorks();
        return true;
      } else {
        state = state.copyWith(allSchedules: prevSchedules);
        return false;
      }
    } catch (e) {
      debugPrint('[EMPLOYEE_SSM_NOTIFIER] startWork API error: $e');
      // In case of error, re-fetch to ensure sync
      await loadWorks();
      return false;
    }
  }

  void completeDayTask(String workId, int dayNumber) {
    SSMWorkSchedule? targetWork;
    SSMTaskStage? completedTask;

    final updatedList = state.allSchedules.map((work) {
      if (work.id == workId) {
        targetWork = work;
        final updatedTasks = work.dailyTasks.map((task) {
          if (task.dayNumber == dayNumber) {
            completedTask = task;
            return task.copyWith(isCompleted: true);
          }
          return task;
        }).toList();

        final allTasksDone = updatedTasks.every((t) => t.isCompleted);
        return work.copyWith(
          dailyTasks: updatedTasks,
          status: allTasksDone
              ? SSMWorkStatus.completed
              : SSMWorkStatus.inProgress,
        );
      }
      return work;
    }).toList();

    List<EmployeeActivityEvent> updatedEvents = state.activityEvents;
    if (targetWork != null && completedTask != null) {
      final isFinal = dayNumber >= targetWork!.durationDays;
      final newEvent = EmployeeActivityEvent(
        id: 'act_${DateTime.now().millisecondsSinceEpoch}',
        title: isFinal ? 'Work Completed' : 'Day $dayNumber task completed',
        description: '${completedTask!.title} (${targetWork!.customerName})',
        customerName: targetWork!.customerName,
        team: targetWork!.assignedTeam,
        timestamp: DateTime.now(),
        timeText: 'Today, 04:30 PM',
      );
      updatedEvents = [newEvent, ...state.activityEvents];
    }

    state = state.copyWith(
      allSchedules: updatedList,
      activityEvents: updatedEvents,
    );
  }

  Future<bool> completeWork(String workId) async {
    SSMWorkSchedule? targetWork;
    final updatedList = state.allSchedules.map((work) {
      if (work.id == workId) {
        targetWork = work;
        final updatedTasks = work.dailyTasks
            .map((t) => t.copyWith(isCompleted: true))
            .toList();
        return work.copyWith(
          status: SSMWorkStatus.completed,
          dailyTasks: updatedTasks,
        );
      }
      return work;
    }).toList();

    List<EmployeeActivityEvent> updatedEvents = state.activityEvents;
    if (targetWork != null) {
      final newEvent = EmployeeActivityEvent(
        id: 'act_${DateTime.now().millisecondsSinceEpoch}',
        title: 'Work Completed',
        description:
            'All deliverables finished for ${targetWork!.customerName}',
        customerName: targetWork!.customerName,
        team: targetWork!.assignedTeam,
        timestamp: DateTime.now(),
        timeText: 'Today, 05:00 PM',
      );
      updatedEvents = [newEvent, ...state.activityEvents];
    }

    state = state.copyWith(
      allSchedules: updatedList,
      activityEvents: updatedEvents,
    );

    try {
      final success = await _service.completeWork(workId);
      if (success) {
        await loadWorks();
        return true;
      }
      return true;
    } catch (e) {
      debugPrint('[EMPLOYEE_SSM_NOTIFIER] completeWork error: $e');
      return true;
    }
  }

  void scheduleNewWork(SSMWorkSchedule newWork) {
    state = state.copyWith(allSchedules: [newWork, ...state.allSchedules]);
  }
}

final employeeSSMProvider =
    NotifierProvider<EmployeeSSMNotifier, EmployeeSSMState>(
      EmployeeSSMNotifier.new,
    );
