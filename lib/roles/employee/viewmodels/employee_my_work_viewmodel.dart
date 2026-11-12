import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickboom_crm_customer/core/network/api_client.dart';
import 'package:quickboom_crm_customer/core/network/app_url.dart';
import 'package:quickboom_company_admin/roles/company_admin/models/company_admin_models.dart';
import 'package:quickboom_crm_customer/roles/employee/viewmodels/employee_calendar_viewmodel.dart';

enum MyWorkFilter { today, upcoming, completed, date }

class EmployeeMyWorkState {
  final MyWorkFilter activeFilter;
  final DateTime selectedDate;
  final bool isLoading;
  final String? errorMessage;
  final List<CustomerCalendarActivity> activities;
  final int todayTotal;
  final int todayCompleted;
  final int todayPending;
  final Set<String> actionLoadingIds;

  // Supervisory Production Manager filters
  final int? selectedCustomerId;
  final String? selectedCustomerName;
  final int? selectedEmployeeId;
  final String? selectedEmployeeName;
  final int? selectedTeamId;
  final String? selectedTeamName;
  final String
  selectedStatus; // 'ALL', 'PENDING', 'IN_PROGRESS', 'COMPLETED', 'BLOCKED'
  final String
  selectedDateRange; // 'TODAY', 'TOMORROW', 'THIS_WEEK', 'ALL', 'CUSTOM'

  // Production Metrics (from real backend data)
  final int prodTotal;
  final int prodPending;
  final int prodInProgress;
  final int prodCompleted;
  final int prodBlocked;
  final int prodToday;
  final int prodOverdue;

  // Production Filter Options (from backend)
  final List<Map<String, dynamic>> availableCustomers;
  final List<Map<String, dynamic>> availableEmployees;
  final List<Map<String, dynamic>> availableTeams;

  const EmployeeMyWorkState({
    this.activeFilter = MyWorkFilter.today,
    required this.selectedDate,
    this.isLoading = false,
    this.errorMessage,
    this.activities = const [],
    this.todayTotal = 0,
    this.todayCompleted = 0,
    this.todayPending = 0,
    this.actionLoadingIds = const {},
    this.selectedCustomerId,
    this.selectedCustomerName,
    this.selectedEmployeeId,
    this.selectedEmployeeName,
    this.selectedTeamId,
    this.selectedTeamName,
    this.selectedStatus = 'ALL',
    this.selectedDateRange = 'ALL',
    this.prodTotal = 0,
    this.prodPending = 0,
    this.prodInProgress = 0,
    this.prodCompleted = 0,
    this.prodBlocked = 0,
    this.prodToday = 0,
    this.prodOverdue = 0,
    this.availableCustomers = const [],
    this.availableEmployees = const [],
    this.availableTeams = const [],
  });

  EmployeeMyWorkState copyWith({
    MyWorkFilter? activeFilter,
    DateTime? selectedDate,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    List<CustomerCalendarActivity>? activities,
    int? todayTotal,
    int? todayCompleted,
    int? todayPending,
    Set<String>? actionLoadingIds,
    int? selectedCustomerId,
    bool clearCustomer = false,
    String? selectedCustomerName,
    int? selectedEmployeeId,
    bool clearEmployee = false,
    String? selectedEmployeeName,
    int? selectedTeamId,
    bool clearTeam = false,
    String? selectedTeamName,
    String? selectedStatus,
    String? selectedDateRange,
    int? prodTotal,
    int? prodPending,
    int? prodInProgress,
    int? prodCompleted,
    int? prodBlocked,
    int? prodToday,
    int? prodOverdue,
    List<Map<String, dynamic>>? availableCustomers,
    List<Map<String, dynamic>>? availableEmployees,
    List<Map<String, dynamic>>? availableTeams,
  }) {
    return EmployeeMyWorkState(
      activeFilter: activeFilter ?? this.activeFilter,
      selectedDate: selectedDate ?? this.selectedDate,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      activities: activities ?? this.activities,
      todayTotal: todayTotal ?? this.todayTotal,
      todayCompleted: todayCompleted ?? this.todayCompleted,
      todayPending: todayPending ?? this.todayPending,
      actionLoadingIds: actionLoadingIds ?? this.actionLoadingIds,
      selectedCustomerId: clearCustomer
          ? null
          : (selectedCustomerId ?? this.selectedCustomerId),
      selectedCustomerName: clearCustomer
          ? null
          : (selectedCustomerName ?? this.selectedCustomerName),
      selectedEmployeeId: clearEmployee
          ? null
          : (selectedEmployeeId ?? this.selectedEmployeeId),
      selectedEmployeeName: clearEmployee
          ? null
          : (selectedEmployeeName ?? this.selectedEmployeeName),
      selectedTeamId: clearTeam
          ? null
          : (selectedTeamId ?? this.selectedTeamId),
      selectedTeamName: clearTeam
          ? null
          : (selectedTeamName ?? this.selectedTeamName),
      selectedStatus: selectedStatus ?? this.selectedStatus,
      selectedDateRange: selectedDateRange ?? this.selectedDateRange,
      prodTotal: prodTotal ?? this.prodTotal,
      prodPending: prodPending ?? this.prodPending,
      prodInProgress: prodInProgress ?? this.prodInProgress,
      prodCompleted: prodCompleted ?? this.prodCompleted,
      prodBlocked: prodBlocked ?? this.prodBlocked,
      prodToday: prodToday ?? this.prodToday,
      prodOverdue: prodOverdue ?? this.prodOverdue,
      availableCustomers: availableCustomers ?? this.availableCustomers,
      availableEmployees: availableEmployees ?? this.availableEmployees,
      availableTeams: availableTeams ?? this.availableTeams,
    );
  }
}

final employeeMyWorkProvider =
    NotifierProvider<EmployeeMyWorkNotifier, EmployeeMyWorkState>(
      EmployeeMyWorkNotifier.new,
    );

final employeeMyWorkNowProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

class EmployeeMyWorkNotifier extends Notifier<EmployeeMyWorkState> {
  int _requestVersion = 0;
  @override
  EmployeeMyWorkState build() {
    ref.onDispose(() => _requestVersion++);
    final now = ref.read(employeeMyWorkNowProvider)();
    final today = DateTime(now.year, now.month, now.day);

    Future.microtask(() => loadInitial());

    return EmployeeMyWorkState(selectedDate: today);
  }

  String _formatDate(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}-'
        '${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')}';
  }

  List<CustomerCalendarActivity> _parseActivities(dynamic responseData) {
    dynamic payload = responseData;
    if (payload is String) {
      try {
        payload = jsonDecode(payload);
      } catch (e) {
        debugPrint('[MY_WORK] JSON decode error: $e');
      }
    }

    dynamic rawList;
    if (payload is List) {
      rawList = payload;
    } else if (payload is Map) {
      final d = payload['data'] ?? payload['items'] ?? payload['records'];
      if (d is List) {
        rawList = d;
      } else if (d is Map) {
        final inner = d['data'] ?? d['items'] ?? d['records'];
        if (inner is List) rawList = inner;
      }
    }

    if (rawList is List) {
      final items = <CustomerCalendarActivity>[];
      for (final item in rawList) {
        if (item is Map) {
          try {
            final act = CustomerCalendarActivity.fromJson(
              Map<String, dynamic>.from(item),
            );
            items.add(act);
          } catch (e) {
            debugPrint('[MY_WORK] Error parsing activity item: $e');
          }
        }
      }
      final deduplicated = deduplicateCustomerActivities(items);
      // TEMP regression diagnostics: counts only, no identifiers or tokens.
      debugPrint(
        '[EMPLOYEE_WORK_DEBUG] myWork apiRecords=${rawList.length} '
        'parsed=${items.length} afterDedup=${deduplicated.length}',
      );
      return deduplicated;
    }
    debugPrint(
      '[EMPLOYEE_WORK_DEBUG] myWork payload has no list '
      '(type=${payload.runtimeType})',
    );
    return const [];
  }

  Future<void> loadInitial() async {
    state = state.copyWith(isLoading: true, clearError: true);
    await Future.wait([_fetchDataForCurrentFilter(), loadFilterOptions()]);
  }

  Future<void> refresh() async {
    state = state.copyWith(clearError: true);
    await Future.wait([_fetchDataForCurrentFilter(), loadFilterOptions()]);
  }

  Future<void> loadFilterOptions() async {
    final apiClient = ref.read(apiClientProvider);
    if (apiClient.token == null || apiClient.token!.isEmpty) return;

    try {
      final res = await apiClient.get(AppUrl.productionFilterOptions);
      if (res.statusCode == 200 && res.data != null) {
        final data = (res.data is Map && res.data['data'] is Map)
            ? res.data['data']
            : (res.data is Map ? res.data : {});
        final rawCust = data['customers'];
        final rawEmp = data['employees'];
        final rawTeams = data['teams'];

        final customers = <Map<String, dynamic>>[];
        if (rawCust is List) {
          for (final c in rawCust) {
            if (c is Map) customers.add(Map<String, dynamic>.from(c));
          }
        }

        final employees = <Map<String, dynamic>>[];
        if (rawEmp is List) {
          for (final e in rawEmp) {
            if (e is Map) employees.add(Map<String, dynamic>.from(e));
          }
        }

        final teams = <Map<String, dynamic>>[];
        if (rawTeams is List) {
          for (final t in rawTeams) {
            if (t is Map) teams.add(Map<String, dynamic>.from(t));
          }
        }

        state = state.copyWith(
          availableCustomers: customers,
          availableEmployees: employees,
          availableTeams: teams,
        );
      }
    } catch (e) {
      debugPrint('[MY_WORK] Error loading production filter options: $e');
    }
  }

  Future<void> setCustomerFilter(int? customerId, String? customerName) async {
    state = state.copyWith(
      selectedCustomerId: customerId,
      clearCustomer: customerId == null,
      selectedCustomerName: customerName,
      isLoading: true,
      clearError: true,
    );
    await _fetchDataForCurrentFilter();
  }

  Future<void> setEmployeeFilter(int? employeeId, String? employeeName) async {
    state = state.copyWith(
      selectedEmployeeId: employeeId,
      clearEmployee: employeeId == null,
      selectedEmployeeName: employeeName,
      isLoading: true,
      clearError: true,
    );
    await _fetchDataForCurrentFilter();
  }

  Future<void> setTeamFilter(int? teamId, String? teamName) async {
    state = state.copyWith(
      selectedTeamId: teamId,
      clearTeam: teamId == null,
      selectedTeamName: teamName,
      isLoading: true,
      clearError: true,
    );
    await _fetchDataForCurrentFilter();
  }

  Future<void> setStatusFilter(String status) async {
    state = state.copyWith(
      selectedStatus: status,
      isLoading: true,
      clearError: true,
    );
    await _fetchDataForCurrentFilter();
  }

  Future<void> setDateRangeFilter(String range, {DateTime? customDate}) async {
    final normalized = customDate != null
        ? DateTime(customDate.year, customDate.month, customDate.day)
        : state.selectedDate;

    state = state.copyWith(
      selectedDateRange: range,
      selectedDate: normalized,
      isLoading: true,
      clearError: true,
    );
    await _fetchDataForCurrentFilter();
  }

  Future<void> setFilter(MyWorkFilter filter) async {
    if (state.activeFilter == filter && filter != MyWorkFilter.date) return;
    state = state.copyWith(
      activeFilter: filter,
      isLoading: true,
      clearError: true,
    );
    await _fetchDataForCurrentFilter();
  }

  Future<void> setDate(DateTime date) async {
    final normalized = DateTime(date.year, date.month, date.day);
    state = state.copyWith(
      activeFilter: MyWorkFilter.date,
      selectedDate: normalized,
      selectedDateRange: 'CUSTOM',
      isLoading: true,
      clearError: true,
    );
    await _fetchDataForCurrentFilter();
  }

  Future<void> _fetchDataForCurrentFilter() async {
    final requestVersion = ++_requestVersion;
    final filter = state;
    final apiClient = ref.read(apiClientProvider);

    await apiClient.ensureAuthLoaded();
    if (requestVersion != _requestVersion) return;
    if (apiClient.token == null || apiClient.token!.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        activities: const [],
        todayTotal: 0,
        todayCompleted: 0,
        todayPending: 0,
        errorMessage: 'Session not ready. Please try again.',
      );
      return;
    }

    final now = ref.read(employeeMyWorkNowProvider)();
    final today = DateTime(now.year, now.month, now.day);
    final todayStr = _formatDate(today);

    try {
      // ── UNIFIED FLOW (Production Manager + Production Team) ──
      if (true) {
        // ── SUPERVISORY FLOW (Production Manager) ──
        final queryParams = <String, dynamic>{};

        if (filter.selectedCustomerId != null) {
          queryParams['customerId'] = filter.selectedCustomerId.toString();
        }
        if (filter.selectedEmployeeId != null) {
          queryParams['employeeId'] = filter.selectedEmployeeId.toString();
        }
        if (filter.selectedTeamId != null) {
          queryParams['teamId'] = filter.selectedTeamId.toString();
        }
        if (filter.selectedStatus != 'ALL') {
          queryParams['status'] = filter.selectedStatus;
        }

        // Date filter
        switch (filter.selectedDateRange) {
          case 'TODAY':
            queryParams['date'] = todayStr;
            break;
          case 'TOMORROW':
            final tomorrow = today.add(const Duration(days: 1));
            queryParams['date'] = _formatDate(tomorrow);
            break;
          case 'THIS_WEEK':
            final weekStart = today.subtract(Duration(days: today.weekday - 1));
            final weekEnd = weekStart.add(const Duration(days: 6));
            queryParams['dateFrom'] = _formatDate(weekStart);
            queryParams['dateTo'] = _formatDate(weekEnd);
            break;
          case 'CUSTOM':
            queryParams['date'] = _formatDate(filter.selectedDate);
            break;
          case 'ALL':
          default:
            // All dates
            break;
        }

        // Fetch calendar activities and metrics in parallel
        final metricsQuery = <String, dynamic>{};
        if (filter.selectedCustomerId != null) {
          metricsQuery['customerId'] = filter.selectedCustomerId.toString();
        }
        if (filter.selectedEmployeeId != null) {
          metricsQuery['employeeId'] = filter.selectedEmployeeId.toString();
        }
        if (filter.selectedTeamId != null) {
          metricsQuery['teamId'] = filter.selectedTeamId.toString();
        }

        final results = await Future.wait([
          apiClient.get(AppUrl.employeeCalendar, queryParameters: queryParams),
          apiClient.get(
            AppUrl.productionMetrics,
            queryParameters: metricsQuery,
          ),
        ]);
        if (requestVersion != _requestVersion) return;

        final worksRes = results[0];
        final metricsRes = results[1];

        if (worksRes.statusCode != 200 || worksRes.data == null) {
          throw StateError('My Work request failed (${worksRes.statusCode})');
        }
        final activities = _parseActivities(worksRes.data);
        debugPrint(
          '[MY_WORK] query: $queryParams, '
          'dataType: ${worksRes.data.runtimeType}, '
          'parsedCount: ${activities.length}',
        );

        int pTotal = activities.length;
        int pPending = 0;
        int pInProgress = 0;
        int pCompleted = 0;
        int pBlocked = 0;
        int pToday = 0;
        int pOverdue = 0;

        dynamic metricsPayload = metricsRes.data;
        if (metricsPayload is String) {
          try {
            metricsPayload = jsonDecode(metricsPayload);
          } catch (e) {
            debugPrint('[MY_WORK] Metrics JSON decode error: $e');
          }
        }
        if (metricsRes.statusCode == 200 && metricsPayload is Map) {
          final mData = metricsPayload['data'] is Map
              ? metricsPayload['data']
              : metricsPayload;
          pTotal = mData['total'] ?? pTotal;
          pPending = mData['pending'] ?? 0;
          pInProgress = mData['inProgress'] ?? 0;
          pCompleted = mData['completed'] ?? 0;
          pBlocked = mData['blocked'] ?? 0;
          pToday = mData['today'] ?? 0;
          pOverdue = mData['overdue'] ?? 0;
        } else {
          // Derive fallback metrics from activities
          for (final a in activities) {
            final s = a.status.toUpperCase();
            if (s == 'COMPLETED' || s == 'APPROVED') {
              pCompleted++;
            } else if (s == 'IN_PROGRESS' || s == 'PROCESSING') {
              pInProgress++;
            } else if (s == 'BLOCKED') {
              pBlocked++;
            } else {
              pPending++;
            }
          }
        }

        state = state.copyWith(
          isLoading: false,
          clearError: true,
          activities: activities,
          prodTotal: pTotal,
          prodPending: pPending,
          prodInProgress: pInProgress,
          prodCompleted: pCompleted,
          prodBlocked: pBlocked,
          prodToday: pToday,
          prodOverdue: pOverdue,
          todayTotal: pToday,
          todayCompleted: pCompleted,
          todayPending: pPending,
        );
      }
    } catch (e) {
      if (requestVersion != _requestVersion) return;
      debugPrint('[MY_WORK] Error fetching activities: $e');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to load production work.',
      );
    }
  }

  Future<bool> startWork(String workId) async {
    return _updateActivityStatus(workId, 'IN_PROGRESS');
  }

  Future<bool> completeWork(String workId) async {
    return _updateActivityStatus(workId, 'COMPLETED');
  }

  Future<bool> submitWorkProgressUpdate(
    String workId, {
    String? notes,
    String? status,
  }) async {
    final newLoadingIds = Set<String>.from(state.actionLoadingIds)..add(workId);
    state = state.copyWith(actionLoadingIds: newLoadingIds);

    final apiClient = ref.read(apiClientProvider);

    try {
      final Map<String, dynamic> data = {};
      if (notes != null && notes.trim().isNotEmpty) {
        data['notes'] = notes.trim();
      }
      if (status != null && status.trim().isNotEmpty) {
        data['status'] = status.trim();
      }

      final response = await apiClient.patch('/works/$workId', data: data);

      if (response.statusCode == 200 || response.statusCode == 204) {
        ref.invalidate(employeeCalendarActivitiesForDateProvider);
        ref.invalidate(employeeCalendarActivitiesForMonthProvider);

        final finalLoadingIds = Set<String>.from(state.actionLoadingIds)
          ..remove(workId);
        state = state.copyWith(actionLoadingIds: finalLoadingIds);

        await _fetchDataForCurrentFilter();
        return true;
      }
    } catch (e) {
      debugPrint('[MY_WORK] Error submitting work progress: $e');
    }

    final finalLoadingIds = Set<String>.from(state.actionLoadingIds)
      ..remove(workId);
    state = state.copyWith(actionLoadingIds: finalLoadingIds);
    return false;
  }

  Future<bool> _updateActivityStatus(String workId, String newStatus) async {
    return submitWorkProgressUpdate(workId, status: newStatus);
  }
}
