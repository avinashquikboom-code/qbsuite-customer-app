import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/user_role.dart';
import '../network/app_url.dart';
import 'secure_storage_service.dart';

class MobileAuthService {
  final Dio _dio;

  MobileAuthService({required Dio dio}) : _dio = dio;

  // ✅ CUSTOMER LOGIN
  Future<Map<String, dynamic>> loginCustomer({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('[MOBILE] Logging in as CUSTOMER: $email');

      final response = await _dio.post(
        AppUrl.loginCustomer,
        data: {'email': email.trim(), 'password': password},
      );

      return await _processResponse(response, 'CUSTOMER');
    } on DioException catch (e) {
      debugPrint('[MOBILE] CUSTOMER login error: ${e.message}');
      final msg = e.response?.data?['message'] ?? e.message ?? 'Login failed';
      throw Exception(msg);
    }
  }

  // ✅ EMPLOYEE LOGIN
  Future<Map<String, dynamic>> loginEmployee({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('[MOBILE] Logging in as EMPLOYEE: $email');

      final response = await _dio.post(
        AppUrl.loginEmployee,
        data: {'email': email.trim(), 'password': password},
      );

      return await _processResponse(response, 'EMPLOYEE');
    } on DioException catch (e) {
      debugPrint('[MOBILE] EMPLOYEE login error: ${e.message}');
      final msg = e.response?.data?['message'] ?? e.message ?? 'Login failed';
      throw Exception(msg);
    }
  }

  // ✅ COMPANY ADMIN LOGIN
  Future<Map<String, dynamic>> loginCompanyAdmin({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('[MOBILE] Logging in as COMPANY_ADMIN: $email');

      final response = await _dio.post(
        AppUrl.loginCompanyAdmin,
        data: {'email': email.trim(), 'password': password},
      );

      return await _processResponse(response, 'COMPANY_ADMIN');
    } on DioException catch (e) {
      debugPrint('[MOBILE] COMPANY_ADMIN login error: ${e.message}');
      final msg = e.response?.data?['message'] ?? e.message ?? 'Login failed';
      throw Exception(msg);
    }
  }

  Future<Map<String, dynamic>> _processResponse(
    Response response,
    String targetRole,
  ) async {
    if (response.statusCode == 200 && response.data != null) {
      dynamic payload = response.data;
      if (payload is Map && payload['data'] != null) {
        payload = payload['data'];
      }

      final tokens = payload['tokens'] as Map<String, dynamic>?;
      final user = payload['user'] as Map<String, dynamic>?;

      final accessToken =
          tokens?['accessToken']?.toString() ??
          payload['accessToken']?.toString() ??
          '';
      final refreshToken =
          tokens?['refreshToken']?.toString() ??
          payload['refreshToken']?.toString() ??
          '';

      if (accessToken.isNotEmpty) {
        await SecureStorageService.saveTokens(
          accessToken: accessToken,
          refreshToken: refreshToken,
        );
      }

      if (user != null) {
        final rawRole = user['role']?.toString() ?? targetRole;
        final parsedRole = UserRole.fromString(rawRole);
        final normalizedRoleStr = parsedRole.toDisplayString();

        final isEmp = parsedRole == UserRole.employee;

        await SecureStorageService.saveUserData(
          userId:
              int.tryParse(
                user['userId']?.toString() ?? user['id']?.toString() ?? '0',
              ) ??
              0,
          role: normalizedRoleStr,
          email: user['email']?.toString() ?? '',
          customerId: user['customerId']?.toString() ?? '',
          employeeId: isEmp ? user['employeeId']?.toString() : null,
          employeeCode: isEmp ? user['employeeCode']?.toString() : null,
        );
      }

      debugPrint('[MOBILE] $targetRole login successful');
      return Map<String, dynamic>.from(response.data);
    }

    throw Exception('Login failed: Invalid server response');
  }
}
