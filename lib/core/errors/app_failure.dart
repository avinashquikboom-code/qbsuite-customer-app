import 'package:dio/dio.dart';

class AppFailure implements Exception {
  const AppFailure(this.message);
  final String message;
  factory AppFailure.fromDio(DioException error) {
    if (error.response?.statusCode == 401) return const AppFailure('Your session expired. Please sign in again.');
    if (error.response?.statusCode == 403) return const AppFailure('You do not have access to this resource.');
    if (error.type == DioExceptionType.connectionTimeout || error.type == DioExceptionType.receiveTimeout || error.type == DioExceptionType.sendTimeout) {
      return const AppFailure('The request timed out. Please try again.');
    }
    if (error.type == DioExceptionType.cancel) return const AppFailure('Request cancelled.');
    return const AppFailure('Unable to complete the request. Check your connection and try again.');
  }
  @override
  String toString() => message;
}
