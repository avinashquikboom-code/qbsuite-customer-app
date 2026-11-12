import 'package:dio/dio.dart';

/// Centralized API Exception class that converts backend error payloads and Dio exceptions
/// into clean, user-friendly messages without exposing raw Dio internals or stack traces.
class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final List<String> errors;
  final String? errorDetails;
  final String? path;
  final bool isInsufficientCredits;
  final int? requiredCredits;
  final int? availableCredits;

  const ApiException({
    this.statusCode,
    required this.message,
    this.errors = const [],
    this.errorDetails,
    this.path,
    this.isInsufficientCredits = false,
    this.requiredCredits,
    this.availableCredits,
  });

  /// User-friendly message suitable for direct display in UI/Toasts
  String get userMessage => message;

  /// Factory constructor to parse DioException or general errors
  factory ApiException.fromDioException(DioException dioError) {
    final response = dioError.response;
    final statusCode = response?.statusCode;
    final path = dioError.requestOptions.path;
    String? extractedMessage;
    List<String> extractedErrors = [];
    String? extractedDetails;

    // 1. Try reading response.data
    final data = response?.data;
    if (data is Map) {
      // Check message field (String or List<String>)
      if (data['message'] != null) {
        if (data['message'] is List && (data['message'] as List).isNotEmpty) {
          extractedMessage = (data['message'] as List).first.toString();
          extractedErrors = (data['message'] as List)
              .map((e) => e.toString())
              .toList();
        } else if (data['message'] is String &&
            (data['message'] as String).trim().isNotEmpty) {
          extractedMessage = (data['message'] as String).trim();
        }
      }

      // Check errors array fallback
      if (extractedMessage == null && data['errors'] != null) {
        if (data['errors'] is List && (data['errors'] as List).isNotEmpty) {
          extractedMessage = (data['errors'] as List).first.toString();
          extractedErrors = (data['errors'] as List)
              .map((e) => e.toString())
              .toList();
        }
      }

      // Check errorDetails or error
      if (data['errorDetails'] != null && data['errorDetails'] is String) {
        extractedDetails = data['errorDetails'] as String;
      } else if (data['error'] != null && data['error'] is String) {
        extractedDetails = data['error'] as String;
      }
      extractedMessage ??= extractedDetails;
    } else if (data is String &&
        data.trim().isNotEmpty &&
        !data.contains('<!DOCTYPE') &&
        !data.contains('<html')) {
      extractedMessage = data.trim();
    }

    // 2. Fallback to status-code based user-friendly messages if no valid message returned
    if (extractedMessage == null || extractedMessage.isEmpty) {
      extractedMessage = _defaultMessageForStatusCode(
        statusCode,
        dioError.type,
      );
    }

    // 3. Clean up any accidental technical artifacts (strip raw JSON or stack trace strings)
    extractedMessage = _sanitizeMessage(extractedMessage);

    // 4. Detect Insufficient AI credits specifically
    bool isCreditErr = false;
    int? reqCredits;
    int? availCredits;

    final lowerMsg = extractedMessage.toLowerCase();
    if (lowerMsg.contains('insufficient') && lowerMsg.contains('credit')) {
      isCreditErr = true;
      // Extract numbers: "requires X credits, but your balance is Y" or "need X credits"
      final match =
          RegExp(
            r'(\d+)\s*credits?.*?(\d+)\s*credits?',
            caseSensitive: false,
          ).firstMatch(extractedMessage) ??
          RegExp(
            r'requires\s*(\d+).*?balance\s*(?:is\s*)?(\d+)',
            caseSensitive: false,
          ).firstMatch(extractedMessage);
      if (match != null) {
        reqCredits = int.tryParse(match.group(1) ?? '');
        availCredits = int.tryParse(match.group(2) ?? '');
      } else {
        final reqMatch = RegExp(
          r'(?:requires|need)\s*(\d+)',
          caseSensitive: false,
        ).firstMatch(extractedMessage);
        final balMatch = RegExp(
          r'(?:balance|have)\s*(?:is\s*)?(\d+)',
          caseSensitive: false,
        ).firstMatch(extractedMessage);
        if (reqMatch != null) {
          reqCredits = int.tryParse(reqMatch.group(1) ?? '');
        }
        if (balMatch != null) {
          availCredits = int.tryParse(balMatch.group(1) ?? '');
        }
      }

      if (reqCredits != null && availCredits != null) {
        extractedMessage =
            'Insufficient AI credits. You need $reqCredits credits, but you have $availCredits. Please top up your wallet.';
      }
    }

    return ApiException(
      statusCode: statusCode,
      message: extractedMessage,
      errors: extractedErrors,
      errorDetails: extractedDetails,
      path: path,
      isInsufficientCredits: isCreditErr,
      requiredCredits: reqCredits,
      availableCredits: availCredits,
    );
  }

  static String _defaultMessageForStatusCode(
    int? statusCode,
    DioExceptionType type,
  ) {
    if (type == DioExceptionType.connectionTimeout ||
        type == DioExceptionType.sendTimeout ||
        type == DioExceptionType.receiveTimeout ||
        type == DioExceptionType.connectionError) {
      return 'Network connection failed. Please check your internet connection and try again.';
    }

    switch (statusCode) {
      case 400:
        return 'Invalid request. Please check your inputs.';
      case 401:
        return 'Your session has expired. Please sign in again.';
      case 403:
        return 'You do not have permission to perform this action.';
      case 404:
        return 'The requested resource could not be found.';
      case 409:
        return 'A conflict occurred. Please refresh and try again.';
      case 422:
        return 'Validation failed. Please verify your data.';
      case 429:
        return 'Too many requests. Please wait a moment and try again.';
      case 500:
        return 'An internal server error occurred. Please try again later.';
      case 502:
      case 503:
      case 504:
        return 'Service is temporarily unavailable. Please try again in a few moments.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  static String _sanitizeMessage(String raw) {
    // If message contains internal technical phrases or stack traces, simplify it
    if (raw.contains('DioException') ||
        raw.contains('validateStatus') ||
        raw.contains('dio_mixin') ||
        raw.contains('at ') ||
        (raw.startsWith('{') && raw.endsWith('}'))) {
      return 'An unexpected error occurred. Please try again.';
    }
    return raw;
  }

  @override
  String toString() => message;
}
