import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Centralized Development & Debug Logging Utility using `dart:developer`.
///
/// Features:
/// - Categorized logging ([API_REQUEST], [API_RESPONSE], [API_ERROR], [AUTH], [CALENDAR], [PLAN], [SCHEDULE], [MODEL_MAPPING], [UI_RENDER], [STATE])
/// - Automatic redaction of sensitive credentials, tokens, OTPs, and secrets
/// - Enabled strictly during development mode (kDebugMode)
class AppLogger {
  AppLogger._();

  static const _sensitiveKeys = [
    'password',
    'passwordhash',
    'token',
    'accesstoken',
    'refreshtoken',
    'otp',
    'secret',
    'authorization',
    'apikey',
    'paymentsecret',
  ];

  static Map<String, dynamic> redactMap(Map<dynamic, dynamic>? map) {
    if (map == null) return {};
    final result = <String, dynamic>{};
    for (final entry in map.entries) {
      final key = entry.key.toString();
      final keyLower = key.toLowerCase();
      if (_sensitiveKeys.any((s) => keyLower.contains(s))) {
        result[key] = '***REDACTED***';
      } else if (entry.value is Map) {
        result[key] = redactMap(entry.value as Map);
      } else if (entry.value is List) {
        result[key] = (entry.value as List).map((item) {
          if (item is Map) return redactMap(item);
          return item;
        }).toList();
      } else {
        result[key] = entry.value;
      }
    }
    return result;
  }

  static String _prettyJson(dynamic data) {
    if (data == null) return '';
    try {
      if (data is Map) {
        return const JsonEncoder.withIndent('  ').convert(redactMap(data));
      }
      if (data is List) {
        return const JsonEncoder.withIndent('  ').convert(
          data.map((item) => item is Map ? redactMap(item) : item).toList(),
        );
      }
      return data.toString();
    } catch (_) {
      return data.toString();
    }
  }

  /// Log Outgoing API Request
  static void apiRequest({
    required String method,
    required String url,
    Map<String, dynamic>? queryParameters,
    dynamic body,
    Map<String, dynamic>? headers,
    String? customerId,
  }) {
    if (!kDebugMode) return;

    final buffer = StringBuffer();
    buffer.writeln('$method $url');
    if (customerId != null && customerId.isNotEmpty) {
      buffer.writeln('Customer ID: $customerId');
    }
    if (queryParameters != null && queryParameters.isNotEmpty) {
      buffer.writeln('Query: ${_prettyJson(queryParameters)}');
    }
    if (body != null) {
      buffer.writeln('Body: ${_prettyJson(body)}');
    }
    if (headers != null && headers.isNotEmpty) {
      buffer.writeln('Headers: ${_prettyJson(redactMap(headers))}');
    }

    developer.log(buffer.toString().trim(), name: 'API_REQUEST');
  }

  /// Log Successful API Response
  static void apiResponse({
    required String method,
    required String url,
    required int statusCode,
    required int durationMs,
    dynamic data,
    int? recordsCount,
  }) {
    if (!kDebugMode) return;

    final buffer = StringBuffer();
    buffer.writeln('$method $url → Status: $statusCode (${durationMs}ms)');
    if (recordsCount != null) {
      buffer.writeln('Records: $recordsCount');
    }
    if (data != null) {
      buffer.writeln('Response: ${_prettyJson(data)}');
    }

    developer.log(buffer.toString().trim(), name: 'API_RESPONSE');
  }

  /// Log API Error with Full Context
  static void apiError({
    required String method,
    required String url,
    required int? statusCode,
    required String message,
    dynamic responseData,
    dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic>? queryParameters,
  }) {
    if (!kDebugMode) return;

    final buffer = StringBuffer();
    buffer.writeln('$method $url → Status: ${statusCode ?? 'NETWORK_ERROR'}');
    buffer.writeln('Message: $message');
    if (queryParameters != null && queryParameters.isNotEmpty) {
      buffer.writeln('Query: ${_prettyJson(queryParameters)}');
    }
    if (responseData != null) {
      buffer.writeln('Response: ${_prettyJson(responseData)}');
    }
    if (error != null) {
      buffer.writeln('Exception: $error');
    }

    developer.log(
      buffer.toString().trim(),
      name: 'API_ERROR',
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Log Authentication Flow
  static void auth(
    String message, {
    String? customerId,
    bool hasToken = false,
  }) {
    if (!kDebugMode) return;
    final details = [
      message,
      if (customerId != null) 'Customer ID: $customerId',
      'Token: ${hasToken ? 'PRESENT' : 'NONE'}',
    ].join(' | ');

    developer.log(details, name: 'AUTH');
  }

  /// Log Calendar Events & Operations
  static void calendar(String message, {dynamic details}) {
    if (!kDebugMode) return;
    final text = details != null
        ? '$message\n${_prettyJson(details)}'
        : message;
    developer.log(text, name: 'CALENDAR');
  }

  /// Log Calendar Data Records Count
  static void calendarData(String message, {int? count, dynamic data}) {
    if (!kDebugMode) return;
    final text = [
      message,
      if (count != null) 'Count: $count',
      if (data != null) 'Data: ${_prettyJson(data)}',
    ].join('\n');
    developer.log(text, name: 'CALENDAR_DATA');
  }

  /// Log Plan & Subscription Data
  static void plan(String message, {dynamic details}) {
    if (!kDebugMode) return;
    final text = details != null
        ? '$message\n${_prettyJson(details)}'
        : message;
    developer.log(text, name: 'PLAN');
  }

  /// Log Schedule Data & Actions
  static void schedule(String message, {dynamic details}) {
    if (!kDebugMode) return;
    final text = details != null
        ? '$message\n${_prettyJson(details)}'
        : message;
    developer.log(text, name: 'SCHEDULE');
  }

  /// Log Model & Data Mapping
  static void modelMapping(
    String modelName, {
    required String id,
    dynamic details,
  }) {
    if (!kDebugMode) return;
    final text = 'Mapping $modelName (ID: $id)\n${_prettyJson(details)}';
    developer.log(text, name: 'MODEL_MAPPING');
  }

  /// Log UI State Changes
  static void state(String stateName, {dynamic details}) {
    if (!kDebugMode) return;
    final text = '$stateName: ${_prettyJson(details)}';
    developer.log(text, name: 'STATE');
  }

  /// Log UI Component Rendering
  static void uiRender(String component, {dynamic details}) {
    if (!kDebugMode) return;
    final text = 'Rendering $component: ${_prettyJson(details)}';
    developer.log(text, name: 'UI_RENDER');
  }
}
