import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickboom_crm_customer/core/network/api_client.dart';
import 'package:quickboom_crm_customer/core/network/app_url.dart';
import 'package:quickboom_crm_customer/roles/employee/models/employee_ssm_work_model.dart';
import 'package:quickboom_company_admin/roles/company_admin/models/team_model.dart';
import 'package:quickboom_company_admin/roles/company_admin/models/company_admin_models.dart';

final employeeSSMServiceProvider = Provider<EmployeeSSMService>((ref) {
  return EmployeeSSMService(ref.read(apiClientProvider));
});

class EmployeeSSMService {
  final ApiClient? _apiClient;

  EmployeeSSMService([this._apiClient]);

  /// Generate default day-wise task breakdown based on Work Type and Start Date
  static List<SSMTaskStage> generateDailyTasks({
    required SSMWorkType workType,
    required DateTime startDate,
    required int durationDays,
  }) {
    final tasks = <SSMTaskStage>[];

    if (workType == SSMWorkType.reel) {
      final defaultTitles = [
        'Shoot / Content Capture',
        'Editing / Production',
        'Final Review / Submission',
      ];
      final defaultDescs = [
        'On-site video recording, angle capture, and b-roll footage.',
        'Color grading, audio sync, effects, and typography overlays.',
        'Client review, revisions, caption writing, and upload preparation.',
      ];

      for (int i = 0; i < durationDays; i++) {
        final taskDate = startDate.add(Duration(days: i));
        final title = i < defaultTitles.length
            ? defaultTitles[i]
            : 'Reel Deliverable ${i + 1}';
        final desc = i < defaultDescs.length
            ? defaultDescs[i]
            : 'Continued production and staging.';
        tasks.add(
          SSMTaskStage(
            dayNumber: i + 1,
            title: title,
            description: desc,
            date: taskDate,
          ),
        );
      }
    } else if (workType == SSMWorkType.shoot) {
      final defaultTitles = [
        'Location / Preparation',
        'Shooting',
        'Remaining Shots / Backup',
      ];
      final defaultDescs = [
        'Equipment setup, lighting check, venue staging, and talent briefing.',
        'Full schedule shoot execution, interview takes, and product captures.',
        'B-roll pickups, RAW data backup, and handoff to editor.',
      ];

      for (int i = 0; i < durationDays; i++) {
        final taskDate = startDate.add(Duration(days: i));
        final title = i < defaultTitles.length
            ? defaultTitles[i]
            : 'Shoot Stage ${i + 1}';
        final desc = i < defaultDescs.length
            ? defaultDescs[i]
            : 'Continued shooting activities.';
        tasks.add(
          SSMTaskStage(
            dayNumber: i + 1,
            title: title,
            description: desc,
            date: taskDate,
          ),
        );
      }
    } else {
      // Post (normally 1 day)
      for (int i = 0; i < durationDays; i++) {
        final taskDate = startDate.add(Duration(days: i));
        tasks.add(
          SSMTaskStage(
            dayNumber: i + 1,
            title: 'Post Creation / Publishing',
            description:
                'Design creative banner, write engaging hashtags, and publish.',
            date: taskDate,
          ),
        );
      }
    }

    return tasks;
  }

  /// Initial empty schedules for clean startup - no hardcoded mock data
  static List<SSMWorkSchedule> getInitialSchedules() {
    return const [];
  }

  /// Initial empty activity events
  static List<EmployeeActivityEvent> getInitialActivityEvents() {
    return const [];
  }

  /// Fetch live work schedules assigned to authenticated employee from backend API
  Future<List<SSMWorkSchedule>> fetchEmployeeWorks({
    String? status,
    String? date,
    String? month,
    String? year,
  }) async {
    final client = _apiClient;
    if (client == null || client.token == null || client.token!.isEmpty) {
      debugPrint(
        '[EMPLOYEE_SSM_SERVICE] No auth token available; returning empty work list',
      );
      return const [];
    }

    try {
      final queryParams = <String, dynamic>{};
      if (status != null && status.isNotEmpty && status != 'ALL') {
        queryParams['status'] = status.replaceAll(' ', '_');
      }
      if (date != null && date.isNotEmpty) queryParams['date'] = date;
      if (month != null && month.isNotEmpty) queryParams['month'] = month;
      if (year != null && year.isNotEmpty) queryParams['year'] = year;

      final response = await client.get(
        AppUrl.employeeCalendar,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response.statusCode == 200 && response.data != null) {
        dynamic rawList;
        if (response.data is List) {
          rawList = response.data;
        } else if (response.data is Map) {
          final d = response.data['data'];
          if (d is List) {
            rawList = d;
          } else if (d is Map && d['items'] is List) {
            rawList = d['items'];
          } else if (response.data['items'] is List) {
            rawList = response.data['items'];
          }
        }

        if (rawList is List) {
          final schedules = <SSMWorkSchedule>[];
          for (final item in rawList) {
            if (item is Map) {
              try {
                final schedule = SSMWorkSchedule.fromJson(
                  Map<String, dynamic>.from(item),
                );
                schedules.add(schedule);
              } catch (e) {
                debugPrint(
                  '[EMPLOYEE_SSM_SERVICE] Error parsing schedule item: $e',
                );
              }
            }
          }
          return schedules;
        }
      }
      return const [];
    } on DioException catch (dioErr) {
      final msg = _extractErrorMessage(dioErr);
      debugPrint(
        '[EMPLOYEE_SSM_SERVICE] fetchEmployeeWorks DioException: $msg',
      );
      throw Exception(msg);
    } catch (e) {
      debugPrint('[EMPLOYEE_SSM_SERVICE] fetchEmployeeWorks error: $e');
      throw Exception('Unable to load your work.');
    }
  }

  /// Start work on a scheduled activity using live API
  Future<bool> startWork(String workId) async {
    final client = _apiClient;
    if (client == null) throw Exception('API client not configured');
    try {
      final response = await client.patch(
        '/works/$workId',
        data: {'status': 'IN_PROGRESS'},
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } on DioException catch (dioErr) {
      final msg = _extractErrorMessage(dioErr);
      debugPrint('[EMPLOYEE_SSM_SERVICE] startWork DioException: $msg');
      throw Exception(msg);
    } catch (e) {
      debugPrint('[EMPLOYEE_SSM_SERVICE] startWork error: $e');
      throw Exception('Failed to start work. Please try again.');
    }
  }

  /// Complete work deliverable using live API
  Future<bool> completeWork(String workId) async {
    final client = _apiClient;
    if (client == null) throw Exception('API client not configured');
    try {
      final response = await client.patch(
        '/works/$workId',
        data: {'status': 'COMPLETED'},
      );
      return response.statusCode == 200 || response.statusCode == 204;
    } on DioException catch (dioErr) {
      final msg = _extractErrorMessage(dioErr);
      debugPrint('[EMPLOYEE_SSM_SERVICE] completeWork DioException: $msg');
      throw Exception(msg);
    } catch (e) {
      debugPrint('[EMPLOYEE_SSM_SERVICE] completeWork error: $e');
      throw Exception('Failed to complete work. Please try again.');
    }
  }

  /// Fetch list of teams the authenticated employee belongs to
  Future<List<TeamItem>> fetchEmployeeTeams() async {
    final client = _apiClient;
    if (client == null || client.token == null || client.token!.isEmpty) {
      debugPrint(
        '[EMPLOYEE_SSM_SERVICE] No auth token; returning empty teams list',
      );
      return const [];
    }

    try {
      final response = await client.get(AppUrl.myTeams);
      if (response.statusCode == 200 && response.data != null) {
        dynamic rawList;
        if (response.data is List) {
          rawList = response.data;
        } else if (response.data is Map) {
          final d = response.data['data'] ?? response.data['items'];
          if (d is List) rawList = d;
        }

        if (rawList is List) {
          final teams = <TeamItem>[];
          for (final item in rawList) {
            if (item is Map) {
              try {
                teams.add(TeamItem.fromJson(Map<String, dynamic>.from(item)));
              } catch (e) {
                debugPrint('[EMPLOYEE_SSM_SERVICE] Error parsing team: $e');
              }
            }
          }
          return teams;
        }
      }
      return const [];
    } catch (e) {
      debugPrint('[EMPLOYEE_SSM_SERVICE] fetchEmployeeTeams error: $e');
      return const [];
    }
  }

  /// Fetch activities for a team across all members for a month / date range
  Future<List<CustomerCalendarActivity>> fetchTeamCalendar({
    required int teamId,
    String? startDate,
    String? endDate,
    String? date,
    String? status,
  }) async {
    final client = _apiClient;
    if (client == null || client.token == null || client.token!.isEmpty) {
      debugPrint(
        '[EMPLOYEE_SSM_SERVICE] No auth token; returning empty team calendar',
      );
      return const [];
    }

    final queryParams = <String, dynamic>{};
    if (startDate != null && startDate.isNotEmpty) {
      queryParams['startDate'] = startDate;
    }
    if (endDate != null && endDate.isNotEmpty) queryParams['endDate'] = endDate;
    if (date != null && date.isNotEmpty) queryParams['date'] = date;
    if (status != null && status.isNotEmpty && status != 'ALL') {
      queryParams['status'] = status.replaceAll(' ', '_');
    }

    try {
      final url = AppUrl.teamCalendar(teamId);
      final response = await client.get(
        url,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      if (response.statusCode == 200 && response.data != null) {
        dynamic rawList;
        if (response.data is List) {
          rawList = response.data;
        } else if (response.data is Map) {
          final d = response.data['data'] ?? response.data['items'];
          if (d is List) rawList = d;
        }

        if (rawList is List) {
          final activities = <CustomerCalendarActivity>[];
          for (final item in rawList) {
            if (item is Map) {
              try {
                activities.add(
                  CustomerCalendarActivity.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                );
              } catch (e) {
                debugPrint(
                  '[EMPLOYEE_SSM_SERVICE] Error parsing team calendar item: $e',
                );
              }
            }
          }
          return activities;
        }
      }
      return const [];
    } on DioException catch (dioErr) {
      final msg = _extractErrorMessage(dioErr);
      debugPrint('[EMPLOYEE_SSM_SERVICE] fetchTeamCalendar DioException: $msg');
      throw Exception(msg);
    } catch (e) {
      debugPrint('[EMPLOYEE_SSM_SERVICE] fetchTeamCalendar error: $e');
      throw Exception('Unable to load team calendar.');
    }
  }

  String _extractErrorMessage(DioException err) {
    if (err.response?.data is Map) {
      final data = err.response!.data as Map;
      if (data['message'] != null) {
        if (data['message'] is List) {
          return (data['message'] as List).join(', ');
        }
        return data['message'].toString();
      }
      if (data['error'] != null) return data['error'].toString();
    }
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timeout. Please check your internet connection.';
      case DioExceptionType.connectionError:
        return 'Cannot connect to server. Please check your network.';
      default:
        return 'Unable to load your work.';
    }
  }
}
