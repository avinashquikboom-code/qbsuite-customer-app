import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/app_url.dart';
import '../../../core/providers/auth_provider.dart';
import 'package:quickboom_company_admin/roles/company_admin/models/company_admin_models.dart';
import 'package:quickboom_company_admin/roles/company_admin/viewmodels/company_admin_viewmodel.dart';
import 'customer_subscription_viewmodel.dart';
import 'customer_profile_viewmodel.dart';
import '../../../core/services/secure_storage_service.dart';

/// Provider that exposes the current logged-in customer ID from auth state, customer profile, or secure storage.
final currentCustomerIdProvider = FutureProvider<String>((ref) async {
  // 1. Resolve verified customer ID from customerProfileProvider (/api/v1/customers/me)
  final profile = ref.watch(customerProfileProvider).asData?.value;
  if (profile != null) {
    if (profile.id > 0) {
      return profile.id.toString();
    }
    if (profile.customerId.trim().isNotEmpty) {
      return profile.customerId.trim();
    }
  }

  // 2. Resolve from login state
  final loginState = ref.watch(loginStateProvider);
  if (loginState.customerId != null &&
      loginState.customerId!.trim().isNotEmpty &&
      loginState.customerId != '0') {
    return loginState.customerId!.trim();
  }

  // 3. Resolve from canonical SecureStorageService
  final secureCustId = await SecureStorageService.getCustomerId();
  if (secureCustId != null &&
      secureCustId.trim().isNotEmpty &&
      secureCustId != '0') {
    return secureCustId.trim();
  }

  // 4. Fallback from SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString('customer_id') ?? prefs.getString('tenant_id');
  if (saved != null && saved.trim().isNotEmpty && saved != '0') {
    return saved.trim();
  }

  return '';
});

/// Provider that exposes the current logged-in customer person's full name.
final currentCustomerNameProvider = FutureProvider<String>((ref) async {
  final profile = ref.watch(customerProfileProvider).asData?.value;
  if (profile != null &&
      profile.personFullName.isNotEmpty &&
      profile.personFullName != 'Customer' &&
      profile.personFullName != 'Valued Customer') {
    return profile.personFullName;
  }

  final prefs = await SharedPreferences.getInstance();
  final savedPerson =
      prefs.getString('user_full_name') ?? prefs.getString('user_name');
  if (savedPerson != null && savedPerson.trim().isNotEmpty) {
    return savedPerson.trim();
  }

  final saved = prefs.getString('customer_name');
  if (saved != null && saved.trim().isNotEmpty) {
    return saved.trim();
  }
  final customerId = await ref.watch(currentCustomerIdProvider.future);
  if (customerId.isNotEmpty) {
    return 'Customer $customerId';
  }
  return 'Customer';
});

/// Provider that exposes the current logged-in customer's business / company name.
final currentCustomerBusinessProvider = FutureProvider<String>((ref) async {
  final profile = ref.watch(customerProfileProvider).asData?.value;
  if (profile != null && profile.companyName.isNotEmpty) {
    final comp = profile.companyName.trim();
    if (comp.toLowerCase() != profile.personFullName.trim().toLowerCase()) {
      return comp;
    }
  }

  final prefs = await SharedPreferences.getInstance();
  final savedBiz =
      prefs.getString('customer_business_name') ??
      prefs.getString('company_name');
  if (savedBiz != null && savedBiz.trim().isNotEmpty) {
    return savedBiz.trim();
  }
  return '';
});

class CustomerCalendarSelectedDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void setDate(DateTime date) {
    state = DateTime(date.year, date.month, date.day);
  }
}

/// Selected date provider for customer calendar
final customerCalendarSelectedDateProvider =
    NotifierProvider<CustomerCalendarSelectedDateNotifier, DateTime>(
      CustomerCalendarSelectedDateNotifier.new,
    );

/// Provider that exposes strictly isolated CompanyAdminState for current customer.
final currentCustomerStateProvider = Provider<CompanyAdminState>((ref) {
  final fullState = ref.watch(companyAdminProvider);
  final customerIdAsync = ref.watch(currentCustomerIdProvider);
  final customerId =
      customerIdAsync.asData?.value ?? customerIdAsync.value ?? '';

  final baseState = fullState.forCustomer(customerId);
  return baseState;
});

class CustomerSelectedWorkFilterNotifier extends Notifier<String> {
  @override
  String build() => 'All';

  void setFilter(String filter) {
    state = filter;
  }
}

/// Selected work type filter for customer calendar & activities:
/// All, Reels Shoot, Video Editing, Post Design, Story Design, Uploading
final customerSelectedWorkFilterProvider =
    NotifierProvider<CustomerSelectedWorkFilterNotifier, String>(
      CustomerSelectedWorkFilterNotifier.new,
    );

/// Model representing the effective/purchased plan for the authenticated customer
class CustomerEffectivePlan {
  final int id;
  final String name;
  final String code;
  final String billingCycle;
  final double price;
  final DateTime? startDate;
  final DateTime? expiryDate;
  final bool isActive;
  final bool isExpired;
  final int remainingDays;
  final int usedDays;
  final int totalDays;
  final List<String> features;
  final Map<String, dynamic> quotas;

  const CustomerEffectivePlan({
    required this.id,
    required this.name,
    required this.code,
    required this.billingCycle,
    required this.price,
    this.startDate,
    this.expiryDate,
    required this.isActive,
    required this.isExpired,
    required this.remainingDays,
    required this.usedDays,
    required this.totalDays,
    this.features = const [],
    this.quotas = const {},
  });

  factory CustomerEffectivePlan.fromJson(Map<String, dynamic> json) {
    return CustomerEffectivePlan(
      id: json['id'] is int
          ? json['id']
          : (int.tryParse(json['id']?.toString() ?? '0') ?? 0),
      name: json['name']?.toString() ?? 'Active Plan',
      code: json['code']?.toString() ?? 'STANDARD',
      billingCycle: json['billingCycle']?.toString() ?? 'MONTHLY',
      price: json['price'] is num
          ? (json['price'] as num).toDouble()
          : (double.tryParse(json['price']?.toString() ?? '0') ?? 0.0),
      startDate: json['startDate'] != null
          ? DateTime.tryParse(json['startDate'].toString())
          : null,
      expiryDate: json['expiryDate'] != null
          ? DateTime.tryParse(json['expiryDate'].toString())
          : null,
      isActive: json['isActive'] == true,
      isExpired: json['isExpired'] == true,
      remainingDays: json['remainingDays'] is int
          ? json['remainingDays']
          : (int.tryParse(json['remainingDays']?.toString() ?? '0') ?? 0),
      usedDays: json['usedDays'] is int
          ? json['usedDays']
          : (int.tryParse(json['usedDays']?.toString() ?? '0') ?? 0),
      totalDays: json['totalDays'] is int
          ? json['totalDays']
          : (int.tryParse(json['totalDays']?.toString() ?? '30') ?? 30),
      features:
          (json['features'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      quotas: json['quotas'] is Map
          ? Map<String, dynamic>.from(json['quotas'] as Map)
          : const {},
    );
  }
}

/// Provider for fetching the current effective plan from the backend API
final customerEffectivePlanProvider = FutureProvider<CustomerEffectivePlan?>((
  ref,
) async {
  final apiClient = ref.watch(apiClientProvider);
  if (apiClient.token == null || apiClient.token!.isEmpty) {
    return null;
  }

  try {
    final response = await apiClient.get(AppUrl.effectivePlan);
    if (response.statusCode == 200 && response.data != null) {
      dynamic data = response.data;
      if (data is Map && data['data'] != null) {
        data = data['data'];
      }
      if (data is Map<String, dynamic>) {
        return CustomerEffectivePlan.fromJson(data);
      }
    }
  } catch (e) {
    debugPrint('[PLAN_API_ERROR] Failed fetching effective plan: $e');
  }
  return null;
});

/// Model representing a single calendar schedule item linked to a customer purchase
class CustomerCalendarSchedule {
  final String id;
  final String purchaseId;
  final String productName;
  final String serviceName;
  final String title;
  final DateTime scheduleDate;
  final String startTime;
  final String endTime;
  final String status;
  final String notes;

  const CustomerCalendarSchedule({
    required this.id,
    required this.purchaseId,
    required this.productName,
    required this.serviceName,
    required this.title,
    required this.scheduleDate,
    required this.startTime,
    required this.endTime,
    required this.status,
    this.notes = '',
  });

  factory CustomerCalendarSchedule.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    if (json['scheduleDate'] != null) {
      parsedDate =
          DateTime.tryParse(json['scheduleDate'].toString()) ?? DateTime.now();
    } else if (json['date'] != null) {
      parsedDate = DateTime.tryParse(json['date'].toString()) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    return CustomerCalendarSchedule(
      id: json['id']?.toString() ?? '',
      // No hardcoded fallback — purchaseId must come from the API or remain empty.
      // The backend always returns purchaseId as PUR-XXX via subscription reference.
      purchaseId: json['purchaseId']?.toString() ?? '',
      productName:
          json['productName']?.toString() ??
          json['serviceName']?.toString() ??
          json['title']?.toString() ??
          'Service',
      serviceName:
          json['serviceName']?.toString() ??
          json['productName']?.toString() ??
          'Service',
      title:
          json['title']?.toString() ??
          json['productName']?.toString() ??
          'Schedule',
      scheduleDate: parsedDate,
      // No hardcoded time fallbacks — times must come from the API or remain empty.
      startTime:
          json['startTime']?.toString() ?? json['time']?.toString() ?? '',
      endTime: json['endTime']?.toString() ?? '',
      status: json['status']?.toString() ?? 'SCHEDULED',
      notes: json['notes']?.toString() ?? '',
    );
  }
}

/// Provider that exposes calendar schedules for a specific date from local state
final customerCalendarSchedulesProvider =
    Provider.family<List<CustomerCalendarSchedule>, String>((ref, dateStr) {
      final customerState = ref.watch(currentCustomerStateProvider);
      final targetDate = DateTime.tryParse(dateStr);
      if (targetDate == null) return const [];

      final matchedActivities = customerState.allCustomerActivities.where((a) {
        return a.date.year == targetDate.year &&
            a.date.month == targetDate.month &&
            a.date.day == targetDate.day;
      }).toList();

      final seenIds = <String>{};
      final schedules = <CustomerCalendarSchedule>[];
      for (final a in matchedActivities) {
        if (seenIds.add(a.id)) {
          schedules.add(
            CustomerCalendarSchedule(
              id: a.id,
              purchaseId: a.purchaseId ?? '',
              productName: a.activityType.label,
              serviceName: a.activityType.label,
              title: a.activityType.label,
              scheduleDate: a.date,
              startTime: a.time,
              endTime: a.endTime ?? '',
              status: a.status,
              notes: a.notes ?? '',
            ),
          );
        }
      }
      return schedules;
    });

/// Provider for fetching authenticated customer calendar activities for a given date (YYYY-MM-DD)
final customerCalendarActivitiesForDateProvider =
    FutureProvider.family<List<CustomerCalendarActivity>, String>((
      ref,
      dateStr,
    ) async {
      final apiClient = ref.watch(apiClientProvider);
      final customerIdFuture = ref.watch(currentCustomerIdProvider.future);
      await apiClient.ensureAuthLoaded();
      if (apiClient.token == null || apiClient.token!.isEmpty) {
        throw StateError('Sign in to view your customer calendar.');
      }
      final customerId = await customerIdFuture;
      if (customerId.isEmpty) {
        throw StateError('Customer account could not be resolved.');
      }

      final currentSubAsync = ref.watch(currentSubscriptionProvider);
      final sub = currentSubAsync.asData?.value;
      final loginState = ref.watch(loginStateProvider);
      final userId =
          loginState.userEmail ?? (loginState.customerId ?? 'UNKNOWN');
      final customerCode = customerId.startsWith('QB-')
          ? customerId
          : 'QB-CUST-${customerId.padLeft(3, '0')}';

      debugPrint('[CALENDAR]');
      debugPrint('authenticatedUserId: $userId');
      debugPrint('customerId: $customerId');
      debugPrint('customerCode: $customerCode');
      debugPrint('selectedDate: $dateStr');
      debugPrint('dateFrom: $dateStr');
      debugPrint('dateTo: $dateStr');
      debugPrint('[Calendar] subscriptionId: ${sub?.id ?? "NONE"}');
      debugPrint('[Calendar] planId: ${sub?.planId ?? "NONE"}');
      debugPrint('[Calendar] Fetching activities...');

      try {
        final response = await apiClient.get(
          AppUrl.worksCalendar,
          queryParameters: {
            'date': dateStr,
            'dateFrom': dateStr,
            'dateTo': dateStr,
          },
        );

        debugPrint('[Calendar] status: ${response.statusCode}');

        if (response.statusCode == 200 && response.data != null) {
          dynamic rawList;
          if (response.data is List) {
            rawList = response.data;
          } else if (response.data is Map) {
            final d = response.data['data'];
            if (d is List) {
              rawList = d;
            } else if (d is Map && d['schedules'] is List) {
              rawList = d['schedules'];
            } else if (d is Map && d['items'] is List) {
              rawList = d['items'];
            }
          }

          if (rawList is List) {
            final activities = <CustomerCalendarActivity>[];
            for (final item in rawList) {
              if (item is Map) {
                final mapItem = Map<String, dynamic>.from(item);

                // Ignore raw entitlement quota summaries if they lack actual schedule dates
                if (mapItem.containsKey('totalQty') &&
                    mapItem.containsKey('remainingQty') &&
                    mapItem['scheduledDate'] == null &&
                    mapItem['scheduledAt'] == null &&
                    mapItem['date'] == null &&
                    mapItem['scheduleDate'] == null) {
                  continue;
                }

                final activity = CustomerCalendarActivity.fromJson(mapItem);

                // 1. Activity Type Filtering: Exclude payment reminders and pure billing entries
                if (!activity.isValidCustomerFacingSchedule) {
                  continue;
                }

                final actDateKey = getScheduledDateString(activity);
                final isMatch = actDateKey == dateStr;

                if (!isMatch) {
                  continue;
                }

                activities.add(activity);
              }
            }

            // Deduplicate activities by unique id (with fallback key)
            final uniqueActivities = <CustomerCalendarActivity>[];
            final seenIds = <String>{};
            for (final act in activities) {
              final key = act.id.isNotEmpty
                  ? act.id
                  : '${getScheduledDateString(act)}_${act.title}_${act.time}';
              if (seenIds.add(key)) {
                uniqueActivities.add(act);
              }
            }

            debugPrint(
              '[Calendar] activities count: ${uniqueActivities.length}',
            );
            return uniqueActivities;
          }
        }
        debugPrint('[Calendar] activities count: 0');
        return const [];
      } catch (e, st) {
        debugPrint(
          '[Calendar] Error fetching activities for $dateStr: $e\n$st',
        );
        rethrow;
      }
    });

/// Provider for fetching authenticated customer calendar activities for a given month ('YYYY-MM')
final customerCalendarActivitiesForMonthProvider =
    FutureProvider.family<List<CustomerCalendarActivity>, String>((
      ref,
      monthStr,
    ) async {
      final apiClient = ref.watch(apiClientProvider);
      final customerIdFuture = ref.watch(currentCustomerIdProvider.future);
      await apiClient.ensureAuthLoaded();
      if (apiClient.token == null || apiClient.token!.isEmpty) {
        throw StateError('Sign in to view your customer calendar.');
      }
      final customerId = await customerIdFuture;
      if (customerId.isEmpty) {
        throw StateError('Customer account could not be resolved.');
      }

      final parts = monthStr.split('-');
      final year = int.tryParse(parts[0]);
      final month = parts.length > 1 ? int.tryParse(parts[1]) : null;

      try {
        final queryParams = <String, dynamic>{};
        if (year != null) queryParams['year'] = year.toString();
        if (month != null) queryParams['month'] = month.toString();

        final response = await apiClient.get(
          AppUrl.worksCalendar,
          queryParameters: queryParams,
        );

        if (response.statusCode == 200 && response.data != null) {
          dynamic rawList;
          if (response.data is List) {
            rawList = response.data;
          } else if (response.data is Map) {
            final d = response.data['data'];
            if (d is List) {
              rawList = d;
            } else if (d is Map && d['schedules'] is List) {
              rawList = d['schedules'];
            } else if (d is Map && d['items'] is List) {
              rawList = d['items'];
            }
          }

          if (rawList is List) {
            final activities = <CustomerCalendarActivity>[];
            for (final item in rawList) {
              if (item is Map) {
                final mapItem = Map<String, dynamic>.from(item);

                // Ignore raw entitlement quota summaries if they lack actual schedule dates
                if (mapItem.containsKey('totalQty') &&
                    mapItem.containsKey('remainingQty') &&
                    mapItem['scheduledDate'] == null &&
                    mapItem['scheduledAt'] == null &&
                    mapItem['date'] == null &&
                    mapItem['scheduleDate'] == null) {
                  continue;
                }

                final activity = CustomerCalendarActivity.fromJson(mapItem);

                // Exclude internal tasks and payment items
                if (!activity.isValidCustomerFacingSchedule) {
                  continue;
                }

                // NOTE: Customer ownership is NOT re-checked here.
                // The backend enforces isolation via JWT. Re-checking with an incompatible
                // ID system (DB integer vs auth-system external ID) silently drops all activities.

                activities.add(activity);
              }
            }
            // Deduplicate monthly activities by unique id
            final uniqueActivities = <CustomerCalendarActivity>[];
            final seenIds = <String>{};
            for (final act in activities) {
              final key = act.id.isNotEmpty
                  ? act.id
                  : '${getScheduledDateString(act)}_${act.title}_${act.time}';
              if (seenIds.add(key)) {
                uniqueActivities.add(act);
              }
            }
            return uniqueActivities;
          }
        }
      } catch (e) {
        debugPrint(
          '[CALENDAR_ERROR] Failed fetching month activities for $monthStr: $e',
        );
        rethrow;
      }

      return const [];
    });

/// Provider for computing monthly customer-facing plan schedule summary
final customerCalendarPlanSummaryProvider =
    Provider.family<({int total, int completed, int remaining}), String>((
      ref,
      monthStr,
    ) {
      final monthActivitiesAsync = ref.watch(
        customerCalendarActivitiesForMonthProvider(monthStr),
      );
      final activities =
          monthActivitiesAsync.asData?.value ??
          const <CustomerCalendarActivity>[];

      final validSchedules = activities
          .where((a) => a.isValidCustomerFacingSchedule)
          .toList();
      final total = validSchedules.length;
      final completed = validSchedules.where((a) {
        final s = a.status.toUpperCase();
        return s == 'COMPLETED' || s == 'APPROVED';
      }).length;
      final remaining = total > completed ? total - completed : 0;

      return (total: total, completed: completed, remaining: remaining);
    });

/// Provider that extracts and returns `Set<DateTime>` normalized to (year, month, day) for a given month ('YYYY-MM')
final customerCalendarScheduledDatesForMonthProvider =
    Provider.family<Set<DateTime>, String>((ref, monthStr) {
      final activitiesAsync = ref.watch(
        customerCalendarActivitiesForMonthProvider(monthStr),
      );
      final activities =
          activitiesAsync.asData?.value ?? const <CustomerCalendarActivity>[];

      final scheduledDates = <DateTime>{};
      for (final activity in activities) {
        if (activity.isValidCustomerFacingSchedule) {
          final normalized = DateTime(
            activity.date.year,
            activity.date.month,
            activity.date.day,
          );
          scheduledDates.add(normalized);
        }
      }
      return scheduledDates;
    });

/// Canonical Provider for active customer calendar activities on selected date
final customerCalendarActivitiesProvider =
    FutureProvider.autoDispose<List<CustomerCalendarActivity>>((ref) async {
      final selectedDate = ref.watch(customerCalendarSelectedDateProvider);
      final dateStr =
          '${selectedDate.year.toString().padLeft(4, '0')}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
      debugPrint('[CALENDAR_REQUEST] customerId: AUTH_USER, date: $dateStr');
      return await ref.watch(
        customerCalendarActivitiesForDateProvider(dateStr).future,
      );
    });

final customerCalendarActivitiesFor7DayWindowProvider =
    FutureProvider.family<List<CustomerCalendarActivity>, String>((
      ref,
      startDateStr,
    ) async {
      final apiClient = ref.watch(apiClientProvider);
      final customerIdFuture = ref.watch(currentCustomerIdProvider.future);
      await apiClient.ensureAuthLoaded();
      if (apiClient.token == null || apiClient.token!.isEmpty) {
        throw StateError('Sign in to view your customer calendar.');
      }
      final customerId = await customerIdFuture;
      if (customerId.isEmpty) {
        throw StateError('Customer account could not be resolved.');
      }

      final startDate = DateTime.tryParse(startDateStr) ?? DateTime.now();
      final startNormalized = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
      );
      final endInclusive = startNormalized.add(const Duration(days: 6));
      final windowEndExclusive = startNormalized.add(const Duration(days: 7));

      final dateFromStr =
          '${startNormalized.year.toString().padLeft(4, '0')}-${startNormalized.month.toString().padLeft(2, '0')}-${startNormalized.day.toString().padLeft(2, '0')}';
      final dateToStr =
          '${endInclusive.year.toString().padLeft(4, '0')}-${endInclusive.month.toString().padLeft(2, '0')}-${endInclusive.day.toString().padLeft(2, '0')}';

      final currentSubAsync = ref.watch(currentSubscriptionProvider);
      final sub = currentSubAsync.asData?.value;
      final selectedDate = ref.watch(customerCalendarSelectedDateProvider);
      final selectedDateStr = normalizeDate(selectedDate);
      final loginState = ref.watch(loginStateProvider);
      final userId =
          loginState.userEmail ?? (loginState.customerId ?? 'UNKNOWN');
      final customerCode = customerId.startsWith('QB-')
          ? customerId
          : 'QB-CUST-${customerId.padLeft(3, '0')}';

      debugPrint('[CALENDAR]');
      debugPrint('authenticatedUserId: $userId');
      debugPrint('customerId: $customerId');
      debugPrint('customerCode: $customerCode');
      debugPrint('selectedDate: $selectedDateStr');
      debugPrint('dateFrom: $dateFromStr');
      debugPrint('dateTo: $dateToStr');
      debugPrint('[Calendar] subscriptionId: ${sub?.id ?? "NONE"}');

      try {
        final response = await apiClient.get(
          AppUrl.worksCalendar,
          queryParameters: {'dateFrom': dateFromStr, 'dateTo': dateToStr},
        );

        debugPrint('[Calendar] status: ${response.statusCode}');

        if (response.statusCode == 200 && response.data != null) {
          dynamic rawList;
          if (response.data is List) {
            rawList = response.data;
          } else if (response.data is Map) {
            final d = response.data['data'];
            if (d is List) {
              rawList = d;
            } else if (d is Map && d['schedules'] is List) {
              rawList = d['schedules'];
            } else if (d is Map && d['items'] is List) {
              rawList = d['items'];
            }
          }

          if (rawList is List) {
            final activities = <CustomerCalendarActivity>[];
            for (final item in rawList) {
              if (item is Map) {
                final mapItem = Map<String, dynamic>.from(item);

                // Ignore raw entitlement quota summaries if they lack actual schedule dates
                if (mapItem.containsKey('totalQty') &&
                    mapItem.containsKey('remainingQty') &&
                    mapItem['scheduledDate'] == null &&
                    mapItem['scheduledAt'] == null &&
                    mapItem['date'] == null &&
                    mapItem['scheduleDate'] == null) {
                  continue;
                }

                final activity = CustomerCalendarActivity.fromJson(mapItem);

                if (!activity.isValidCustomerFacingSchedule) {
                  continue;
                }

                final actDateKey = getScheduledDateString(activity);
                final actDateParts = actDateKey
                    .split('-')
                    .map(int.tryParse)
                    .toList();
                if (actDateParts.length == 3 &&
                    actDateParts[0] != null &&
                    actDateParts[1] != null &&
                    actDateParts[2] != null) {
                  final actDateNormalized = DateTime(
                    actDateParts[0]!,
                    actDateParts[1]!,
                    actDateParts[2]!,
                  );
                  if (actDateNormalized.isBefore(startNormalized) ||
                      !actDateNormalized.isBefore(windowEndExclusive)) {
                    continue;
                  }
                }

                activities.add(activity);
              }
            }
            // Deduplicate 7-day window activities by unique id
            final uniqueActivities = <CustomerCalendarActivity>[];
            final seenIds = <String>{};
            for (final act in activities) {
              final key = act.id.isNotEmpty
                  ? act.id
                  : '${getScheduledDateString(act)}_${act.title}_${act.time}';
              if (seenIds.add(key)) {
                uniqueActivities.add(act);
              }
            }
            debugPrint('[Calendar] activityCount: ${uniqueActivities.length}');
            return uniqueActivities;
          }
        }
        debugPrint('[Calendar] activityCount: 0');
        return const [];
      } catch (e, st) {
        debugPrint(
          '[Calendar] Error fetching 7-day activities for $startDateStr: $e\n$st',
        );
        rethrow;
      }
    });
