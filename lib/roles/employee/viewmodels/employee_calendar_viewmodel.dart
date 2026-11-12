import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:quickboom_crm_customer/core/network/api_client.dart';
import 'package:quickboom_crm_customer/core/network/app_url.dart';
import 'package:quickboom_crm_customer/core/services/permission_manager.dart';
import 'package:quickboom_company_admin/roles/company_admin/models/company_admin_models.dart';



/// Provider for managing selected calendar date on Employee side
final employeeCalendarSelectedDateProvider =
    NotifierProvider<EmployeeCalendarSelectedDateNotifier, DateTime>(
      EmployeeCalendarSelectedDateNotifier.new,
    );

class EmployeeCalendarSelectedDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void setDate(DateTime date) {
    state = DateTime(date.year, date.month, date.day);
  }
}

/// Provider for managing active work category filter
final employeeCalendarFilterProvider =
    NotifierProvider<EmployeeCalendarFilterNotifier, String>(
      EmployeeCalendarFilterNotifier.new,
    );

class EmployeeCalendarFilterNotifier extends Notifier<String> {
  @override
  String build() => 'All';

  void setFilter(String filter) {
    state = filter;
  }
}

Future<List<CustomerCalendarActivity>> _loadEmployeeCalendarActivities(
  ApiClient apiClient, {
  Map<String, dynamic>? queryParameters,
}) async {
  await apiClient.ensureAuthLoaded();
  final token = apiClient.token;
  if (token == null || token.trim().isEmpty) {
    throw StateError(
      'Employee calendar requested before the session was ready',
    );
  }

  final response = await apiClient.get(
    AppUrl.employeeCalendar,
    queryParameters: queryParameters,
  );

  debugPrint(
    '[EMPLOYEE_CALENDAR_DEBUG]\n'
    'endpoint: ${AppUrl.employeeCalendar}\n'
    'queryParameters: $queryParameters\n'
    'httpStatus: ${response.statusCode}\n'
    'timezone: ${DateTime.now().timeZoneName} (offset: ${DateTime.now().timeZoneOffset})\n'
    'hasData: ${response.data != null}',
  );

  if (response.statusCode == 403) {
    throw StateError(
      'Access denied: Missing required permission [CALENDAR:VIEW] on backend.',
    );
  }
  if (response.statusCode == 401) {
    throw StateError('Session expired. Please log in again to view Calendar.');
  }

  if (response.statusCode != 200 || response.data == null) {
    throw StateError(
      'Employee calendar request failed (${response.statusCode})',
    );
  }

  dynamic payload = response.data;
  if (payload is String) {
    try {
      payload = jsonDecode(payload);
    } catch (e) {
      debugPrint('[EMPLOYEE_CALENDAR] JSON decode error: $e');
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
      if (inner is List) {
        rawList = inner;
      }
    } else if (payload['records'] is List) {
      rawList = payload['records'];
    } else if (payload['items'] is List) {
      rawList = payload['items'];
    }
  }

  if (rawList is! List) {
    debugPrint(
      '[EMPLOYEE_CALENDAR_DEBUG] Response payload did not contain a valid list. Payload type: ${payload.runtimeType}',
    );
    throw StateError('Employee calendar API returned an invalid activity list.');
  }

  final activities = <CustomerCalendarActivity>[];
  var skipped = 0;
  for (final item in rawList) {
    if (item is! Map) {
      skipped++;
      continue;
    }
    try {
      activities.add(
        CustomerCalendarActivity.fromJson(Map<String, dynamic>.from(item)),
      );
    } catch (e, st) {
      skipped++;
      debugPrint('[EMPLOYEE_CALENDAR] Skipped unreadable activity ($e):\n$st');
    }
  }
  if (skipped > 0) {
    throw StateError('Unable to read $skipped employee calendar activities. Please refresh or contact support.');
  }
  final deduplicated = deduplicateCustomerActivities(activities);
  // TEMP regression diagnostics: counts only, no identifiers or tokens.
  debugPrint(
    '[EMPLOYEE_WORK_DEBUG] calendar query=$queryParameters '
    'apiRecords=${rawList.length} parsed=${activities.length} '
    'skipped=$skipped afterDedup=${deduplicated.length}',
  );
  debugPrint(
    '[EMPLOYEE_CALENDAR_DEBUG] Successfully parsed ${deduplicated.length} calendar activities',
  );
  return deduplicated;
}

/// Provider for fetching ALL authenticated employee calendar activities (no date/month filter)
final employeeCalendarAllActivitiesProvider =
    FutureProvider<List<CustomerCalendarActivity>>((ref) async {
      final apiClient = ref.watch(apiClientProvider);
      ref.watch(permissionManagerProvider);
      return _loadEmployeeCalendarActivities(apiClient);
    });

/// Provider for fetching authenticated employee activities for a specific date (YYYY-MM-DD)
final employeeCalendarActivitiesForDateProvider =
    FutureProvider.family<List<CustomerCalendarActivity>, String>((
      ref,
      dateStr,
    ) async {
      final apiClient = ref.watch(apiClientProvider);
      ref.watch(permissionManagerProvider);
      return _loadEmployeeCalendarActivities(
        apiClient,
        queryParameters: {
          'date': dateStr,
          'dateFrom': dateStr,
          'dateTo': dateStr,
        },
      );
    });

/// Provider for fetching authenticated employee activities for an entire month ('YYYY-MM')
final employeeCalendarActivitiesForMonthProvider =
    FutureProvider.family<List<CustomerCalendarActivity>, String>((
      ref,
      monthStr,
    ) async {
      final apiClient = ref.watch(apiClientProvider);
      ref.watch(permissionManagerProvider);
      final parts = monthStr.split('-');
      final year = int.tryParse(parts[0]);
      final month = parts.length > 1 ? int.tryParse(parts[1]) : null;
      final queryParams = <String, dynamic>{};
      if (year != null) queryParams['year'] = year.toString();
      if (month != null) queryParams['month'] = month.toString();
      return _loadEmployeeCalendarActivities(
        apiClient,
        queryParameters: queryParams,
      );
    });

/// Computes set of unique scheduled dates in month for rendering calendar dots
final employeeCalendarScheduledDatesForMonthProvider =
    Provider.family<Set<DateTime>, String>((ref, monthStr) {
      final activitiesAsync = ref.watch(
        employeeCalendarActivitiesForMonthProvider(monthStr),
      );
      final activities =
          activitiesAsync.asData?.value ?? const <CustomerCalendarActivity>[];

      final dates = <DateTime>{};
      for (final a in activities) {
        dates.add(DateTime(a.date.year, a.date.month, a.date.day));
      }
      return dates;
    });

/// Provider for fetching authenticated employee activities for a 7-day rolling window
final employeeCalendarActivitiesFor7DayWindowProvider =
    FutureProvider.family<List<CustomerCalendarActivity>, String>((
      ref,
      startDateStr,
    ) async {
      final apiClient = ref.watch(apiClientProvider);
      ref.watch(permissionManagerProvider);
      final start = DateTime.tryParse(startDateStr);
      final end = start != null
          ? DateTime(start.year, start.month, start.day + 6)
          : null;
      final endDateStr = end != null
          ? '${end.year.toString().padLeft(4, '0')}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}'
          : startDateStr;

      return _loadEmployeeCalendarActivities(
        apiClient,
        // Range keys only: the API maps `startDate` onto the single-day `date`
        // filter, which would collapse the week to its first day.
        queryParameters: {
          'dateFrom': startDateStr,
          'dateTo': endDateStr,
        },
      );
    });

/// Provider for computing monthly employee task summary (total, completed, remaining)
final employeeCalendarPlanSummaryProvider =
    Provider.family<({int total, int completed, int remaining}), String>((
      ref,
      monthStr,
    ) {
      final monthActivitiesAsync = ref.watch(
        employeeCalendarActivitiesForMonthProvider(monthStr),
      );
      final activities =
          monthActivitiesAsync.asData?.value ??
          const <CustomerCalendarActivity>[];

      final total = activities.length;
      final completed = activities.where((a) {
        final s = a.status.toUpperCase();
        return s == 'COMPLETED' || s == 'APPROVED' || s == 'DONE';
      }).length;
      final remaining = total > completed ? total - completed : 0;

      return (total: total, completed: completed, remaining: remaining);
    });

/// Filters activities matching selected category
bool matchesEmployeeCategoryFilter(
  CustomerCalendarActivity activity,
  String filter,
) {
  if (filter == 'All') return true;
  final taskCat = resolveTaskCategory(activity);
  final filterLower = filter.toLowerCase();

  if (filter == 'Video Shoot' ||
      filter == 'Reel Shoot' ||
      filter == 'Reels Shoot') {
    return taskCat == TaskCategory.reelShoot ||
        taskCat == TaskCategory.videoShoot;
  } else if (filter == 'Video Editing' ||
      filter == 'Reel Edit' ||
      filter == 'Reel Editing') {
    return taskCat == TaskCategory.reelEdit ||
        taskCat == TaskCategory.videoEditing;
  } else if (filter == 'Reel Post' || filter == 'Posting') {
    return taskCat == TaskCategory.reelPost ||
        taskCat == TaskCategory.postPublish;
  } else if (filter == 'Story Design' || filter == 'Story') {
    return taskCat == TaskCategory.storyDesign ||
        taskCat == TaskCategory.storyPost;
  } else if (filter == 'Photo Shoot' || filter == 'Photoshoot') {
    final haystack =
        '${activity.title ?? ''} ${activity.serviceName ?? ''} ${activity.type} ${activity.productName ?? ''}'
            .toLowerCase();
    return haystack.contains('photo');
  } else if (filter == 'Other') {
    return !_matchesNamedEmployeeCategory(activity);
  } else if (filter == 'Creative Work' || filter == 'Post Design') {
    return taskCat == TaskCategory.postDesign ||
        (activity.title ?? '').toLowerCase().contains('creative');
  } else if (filter == 'Content Work') {
    return taskCat == TaskCategory.storyDesign ||
        taskCat == TaskCategory.postDesign ||
        (activity.title ?? '').toLowerCase().contains('content');
  } else if (filter == 'Social Media Work') {
    return taskCat == TaskCategory.reelPost ||
        taskCat == TaskCategory.storyPost ||
        taskCat == TaskCategory.postPublish ||
        (activity.title ?? '').toLowerCase().contains('social');
  }

  final title = (activity.title ?? '').toLowerCase();
  final notes = (activity.notes ?? '').toLowerCase();
  final service = (activity.serviceName ?? '').toLowerCase();
  final type = activity.type.toLowerCase();

  return title.contains(filterLower) ||
      notes.contains(filterLower) ||
      service.contains(filterLower) ||
      type.contains(filterLower);
}

bool _matchesNamedEmployeeCategory(CustomerCalendarActivity activity) {
  return matchesEmployeeCategoryFilter(activity, 'Reels Shoot') ||
      matchesEmployeeCategoryFilter(activity, 'Video Editing') ||
      matchesEmployeeCategoryFilter(activity, 'Post Design') ||
      matchesEmployeeCategoryFilter(activity, 'Photoshoot');
}

/// Updates an activity status and/or notes on the backend and invalidates active calendar providers
Future<bool> updateEmployeeWorkProgress(
  WidgetRef ref,
  dynamic workId, {
  String? newStatus,
  String? notes,
}) async {
  final apiClient = ref.read(apiClientProvider);
  try {
    final data = <String, dynamic>{};
    if (newStatus != null && newStatus.isNotEmpty) {
      data['status'] = newStatus;
    }
    if (notes != null && notes.trim().isNotEmpty) {
      data['notes'] = notes.trim();
    }
    final response = await apiClient.patch('/works/$workId', data: data);
    if (response.statusCode == 200 || response.statusCode == 204) {
      ref.invalidate(employeeCalendarAllActivitiesProvider);
      ref.invalidate(employeeCalendarActivitiesForDateProvider);
      ref.invalidate(employeeCalendarActivitiesForMonthProvider);
      ref.invalidate(employeeCalendarActivitiesFor7DayWindowProvider);
      return true;
    }
  } catch (e) {
    debugPrint('Error updating work progress: $e');
  }
  return false;
}

void refreshEmployeeCalendarProviders(WidgetRef ref) {
  ref.invalidate(employeeCalendarAllActivitiesProvider);
  ref.invalidate(employeeCalendarActivitiesForDateProvider);
  ref.invalidate(employeeCalendarActivitiesForMonthProvider);
  ref.invalidate(employeeCalendarActivitiesFor7DayWindowProvider);
}

/// Creates a calendar schedule for the authenticated employee via POST /works.
Future<void> createEmployeeCalendarEvent(
  WidgetRef ref, {
  required int customerId,
  required String title,
  required String workType,
  required String scheduledDate,
  required String scheduledTime,
  String? notes,
  String? serviceName,
}) async {
  if (customerId <= 0) {
    throw Exception('Customer/resource not found');
  }
  final apiClient = ref.read(apiClientProvider);
  final payload = <String, dynamic>{
    'title': title.trim(),
    'workType': workType,
    'scheduledDate': scheduledDate,
    'scheduledTime': scheduledTime,
    'customerId': customerId,
  };
  if (notes != null && notes.trim().isNotEmpty) {
    payload['notes'] = notes.trim();
  }
  if (serviceName != null && serviceName.trim().isNotEmpty) {
    payload['serviceName'] = serviceName.trim();
  }

  await apiClient.post(AppUrl.works, data: payload);
  refreshEmployeeCalendarProviders(ref);
}

/// Updates an activity status on the backend and invalidates active calendar providers
Future<bool> updateEmployeeActivityStatus(
  WidgetRef ref,
  dynamic workId,
  String newStatus,
) async {
  return updateEmployeeWorkProgress(ref, workId, newStatus: newStatus);
}
