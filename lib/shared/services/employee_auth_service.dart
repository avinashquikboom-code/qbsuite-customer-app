import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:quickboom_crm_customer/core/network/api_client.dart';
import 'package:quickboom_crm_customer/core/network/app_url.dart';
import 'package:quickboom_crm_customer/core/services/secure_storage_service.dart';
import 'package:quickboom_crm_customer/core/services/notification_service.dart';

final employeeAuthServiceProvider = Provider<EmployeeAuthService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return EmployeeAuthService(apiClient);
});

class RegisteredEmployeeResult {
  final String userId;
  final String email;
  final String fullName;
  final String employeeType;
  final String city;
  final String mobile;
  final String customerId;
  final String? employeeId;
  final String? employeeCode;
  final String? accessToken;

  const RegisteredEmployeeResult({
    required this.userId,
    required this.email,
    required this.fullName,
    required this.employeeType,
    required this.city,
    required this.mobile,
    required this.customerId,
    this.employeeId,
    this.employeeCode,
    this.accessToken,
  });

  factory RegisteredEmployeeResult.fromJson(Map<String, dynamic> json) {
    return RegisteredEmployeeResult(
      userId: json['userId']?.toString() ?? json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      fullName:
          json['fullName']?.toString() ??
          '${json['firstName'] ?? ''} ${json['lastName'] ?? ''}'.trim(),
      employeeType: json['employeeType']?.toString() ?? 'COMPANY',
      city: json['city']?.toString() ?? '',
      mobile: json['mobile']?.toString() ?? json['phone']?.toString() ?? '',
      customerId: json['customerId']?.toString() ?? '',
      employeeId: json['employeeId']?.toString(),
      employeeCode: json['employeeCode']?.toString(),
      accessToken: json['accessToken']?.toString(),
    );
  }
}

class EmployeeAuthService {
  final ApiClient _apiClient;

  EmployeeAuthService(this._apiClient);

  Future<RegisteredEmployeeResult> registerEmployee({
    required String fullName,
    required String city,
    required String mobile,
    required String email,
    required String password,
    required String confirmPassword,
    required String employeeType,
    String? referralCode,
    String? companyName,
    int? planId,
    String? paymentMethod,
  }) async {
    final cleanFullName = fullName.trim();
    final cleanCity = city.trim();
    final cleanMobile = mobile.trim();
    final cleanEmail = email.trim().toLowerCase();
    final cleanEmployeeType = employeeType.trim().toUpperCase();

    try {
      final response = await _apiClient.post(
        AppUrl.registerEmployee,
        data: {
          'fullName': cleanFullName,
          'city': cleanCity,
          'mobile': cleanMobile,
          'email': cleanEmail,
          'password': password,
          'confirmPassword': confirmPassword,
          'employeeType': cleanEmployeeType,
          if (referralCode != null && referralCode.trim().isNotEmpty)
            'referralCode': referralCode.trim(),
          if (companyName != null && companyName.trim().isNotEmpty)
            'companyName': companyName.trim(),
          'planId': ?planId,
          'paymentMethod': ?paymentMethod,
        },
      );

      final rawData = response.data;
      final Map<String, dynamic> data = rawData is Map<String, dynamic>
          ? (rawData['data'] is Map<String, dynamic>
                ? Map<String, dynamic>.from(rawData['data'] as Map)
                : Map<String, dynamic>.from(rawData))
          : <String, dynamic>{};

      final Map<String, dynamic> user = data['user'] is Map
          ? Map<String, dynamic>.from(data['user'] as Map)
          : <String, dynamic>{};
      final Map<String, dynamic> tokens = data['tokens'] is Map
          ? Map<String, dynamic>.from(data['tokens'] as Map)
          : <String, dynamic>{};

      final accessToken =
          tokens['accessToken']?.toString() ??
          data['accessToken']?.toString() ??
          '';
      final refreshToken =
          tokens['refreshToken']?.toString() ??
          data['refreshToken']?.toString();
      final customerId =
          user['customerId']?.toString() ??
          data['customerId']?.toString() ??
          '';
      final userId = user['id']?.toString() ?? data['userId']?.toString() ?? '';
      final employeeId =
          user['employeeId']?.toString() ?? data['employeeId']?.toString();
      final employeeCode =
          user['employeeCode']?.toString() ?? data['employeeCode']?.toString();

      final result = RegisteredEmployeeResult(
        userId: userId,
        email: cleanEmail,
        fullName: cleanFullName,
        employeeType: cleanEmployeeType,
        city: cleanCity,
        mobile: cleanMobile,
        customerId: customerId,
        employeeId: employeeId,
        employeeCode: employeeCode,
        accessToken: accessToken,
      );

      if (accessToken.isNotEmpty) {
        _apiClient.setAuth(accessToken, customerId, refreshToken: refreshToken);
        await _saveLocalSession(result, refreshToken: refreshToken ?? '');
        NotificationService.instance.registerTokenForAuthenticatedUser();
      }

      return result;
    } on DioException catch (dioErr) {
      final resData = dioErr.response?.data;
      String? serverMsg;
      if (resData is Map) {
        if (resData['message'] is String) {
          serverMsg = resData['message'];
        } else if (resData['message'] is List &&
            (resData['message'] as List).isNotEmpty) {
          serverMsg = (resData['message'] as List).join(', ');
        } else if (resData['error'] is String) {
          serverMsg = resData['error'];
        }
      }
      final statusCode = dioErr.response?.statusCode;
      if (statusCode == 409) {
        throw Exception(
          serverMsg ??
              'Email or phone number is already registered. Please login instead.',
        );
      } else if (statusCode == 400 || statusCode == 422) {
        throw Exception(serverMsg ?? 'Please check your registration details.');
      }
      throw Exception(serverMsg ?? 'Registration failed. Please try again.');
    } catch (e) {
      debugPrint('[EmployeeAuthService] Registration error: $e');
      rethrow;
    }
  }

  Future<void> _saveLocalSession(
    RegisteredEmployeeResult result, {
    String refreshToken = '',
  }) async {
    try {
      if (result.accessToken != null && result.accessToken!.isNotEmpty) {
        await SecureStorageService.saveTokens(
          accessToken: result.accessToken!,
          refreshToken: refreshToken,
        );
      }
    } catch (e) {
      debugPrint('[EmployeeAuthService] _saveLocalSession failed: $e');
    }
  }
}
