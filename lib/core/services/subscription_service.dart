import 'package:dio/dio.dart';

class SubscriptionService {
  final Dio _dio;

  SubscriptionService({required Dio dio}) : _dio = dio;

  Map<String, dynamic> _object(dynamic raw) {
    final value = raw is Map && raw['data'] is Map ? raw['data'] : raw;
    return Map<String, dynamic>.from(value as Map);
  }

  Future<List<Map<String, dynamic>>> getCustomers() async {
    final response = await _dio.get('/customers');
    final raw = response.data is Map ? response.data['data'] : response.data;
    return (raw as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<void> deleteCustomer(int id) async {
    await _dio.delete('/customers/$id');
  }

  Future<void> deleteCustomers(List<int> ids) async {
    await _dio.post('/customers/bulk-delete', data: {'ids': ids});
  }

  Future<List<Map<String, dynamic>>> getPlans() async {
    final response = await _dio.get('/plans');
    final raw = response.data is Map ? response.data['data'] : response.data;
    return (raw as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  /// Creates a pending gateway order. Only verified payment can activate it.
  Future<Map<String, dynamic>> purchaseSubscription(
    int planId, {
    required int customerId,
    required String billingCycle,
    required String idempotencyKey,
  }) async {
    final response = await _dio.post(
      '/payments/razorpay/order',
      data: {
        'planId': planId,
        'customerId': customerId,
        'billingCycle': billingCycle,
        'idempotencyKey': idempotencyKey,
      },
    );
    return _object(response.data);
  }

  Future<void> verifyPayment(Map<String, dynamic> payload) async {
    await _dio.post('/payments/razorpay/verify', data: payload);
  }

  /// Get scheduled activities for specific date
  Future<Map<String, dynamic>> getCalendarSchedule(
    String date, {
    String? customerId,
  }) async {
    try {
      final response = await _dio.get(
        '/works/calendar',
        queryParameters: {
          'date': date,
          if (customerId != null && customerId.isNotEmpty)
            'customerId': customerId,
        },
      );

      if (response.data is Map) {
        return Map<String, dynamic>.from(response.data as Map);
      } else if (response.data is List) {
        return {'date': date, 'activities': response.data};
      }
      return {'date': date, 'activities': []};
    } catch (e) {
      throw Exception('Failed to load calendar: $e');
    }
  }

  /// Mark activity schedule as completed
  Future<void> completeActivity(int activityScheduleId) async {
    try {
      await _dio.post(
        '/works/activity/complete',
        data: {'activityScheduleId': activityScheduleId},
      );
    } catch (e) {
      throw Exception('Failed to complete activity: $e');
    }
  }

  /// Skip an activity schedule
  Future<void> skipActivity(int activityScheduleId) async {
    try {
      await _dio.post(
        '/works/activity/skip',
        data: {'activityScheduleId': activityScheduleId},
      );
    } catch (e) {
      throw Exception('Failed to skip activity: $e');
    }
  }
}
