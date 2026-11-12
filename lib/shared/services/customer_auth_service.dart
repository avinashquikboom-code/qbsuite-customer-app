import 'dart:io';
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quickboom_crm_customer/core/network/api_client.dart';
import 'package:quickboom_crm_customer/core/network/app_url.dart';
import 'package:quickboom_crm_customer/core/services/secure_storage_service.dart';
import 'package:quickboom_crm_customer/core/services/notification_service.dart';

final customerAuthServiceProvider = Provider<CustomerAuthService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return CustomerAuthService(apiClient);
});

class RegisteredCustomerResult {
  final String userId;
  final String email;
  final String fullName;
  final String companyName;
  final String city;
  final String mobile;
  final String customerId;
  final String? accessToken;

  const RegisteredCustomerResult({
    required this.userId,
    required this.email,
    required this.fullName,
    required this.companyName,
    required this.city,
    required this.mobile,
    required this.customerId,
    this.accessToken,
  });

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'email': email,
    'fullName': fullName,
    'companyName': companyName,
    'city': city,
    'mobile': mobile,
    'customerId': customerId,
    'accessToken': accessToken,
  };

  factory RegisteredCustomerResult.fromJson(Map<String, dynamic> json) {
    return RegisteredCustomerResult(
      userId: json['userId'] ?? '',
      email: json['email'] ?? '',
      fullName: json['fullName'] ?? '',
      companyName: json['companyName'] ?? '',
      city: json['city'] ?? '',
      mobile: json['mobile'] ?? '',
      customerId: json['customerId'] ?? '',
      accessToken: json['accessToken'],
    );
  }
}

class CustomerAuthService {
  final ApiClient _apiClient;

  static const String _savedCustomerKey = 'quikboom_active_customer_session_v1';

  CustomerAuthService(this._apiClient);

  /// Register a new Customer + Customer Admin User
  Future<RegisteredCustomerResult> registerCustomer({
    required String fullName,
    required String companyName,
    required String mobile,
    required String email,
    required String city,
    String? password,
  }) async {
    final cleanFullName = fullName.trim();
    final cleanCompanyName = companyName.trim();
    final cleanMobile = mobile.trim();
    final cleanEmail = email.trim().toLowerCase();
    final cleanCity = city.trim();

    try {
      String? fcmToken = NotificationService.instance.cachedFcmToken;
      if (fcmToken == null || fcmToken.trim().isEmpty) {
        try {
          fcmToken = await FirebaseMessaging.instance.getToken();
        } catch (e) {
          debugPrint(
            '⚠️ [FCM] Could not fetch FCM token before registration: $e',
          );
        }
      }

      final response = await _apiClient.post(
        AppUrl.register,
        data: {
          'companyName': cleanCompanyName.isNotEmpty
              ? cleanCompanyName
              : cleanFullName,
          'fullName': cleanFullName,
          'email': cleanEmail,
          'phone': cleanMobile.isNotEmpty ? cleanMobile : null,
          'city': cleanCity.isNotEmpty ? cleanCity : null,
          'password': password ?? '123456',
          if (fcmToken != null && fcmToken.trim().isNotEmpty)
            'fcmToken': fcmToken.trim(),
          'platform': Platform.isIOS ? 'IOS' : 'ANDROID',
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

      final result = RegisteredCustomerResult(
        userId: userId,
        email: cleanEmail,
        fullName: cleanFullName,
        companyName: cleanCompanyName.isNotEmpty
            ? cleanCompanyName
            : cleanFullName,
        city: cleanCity,
        mobile: cleanMobile,
        customerId: customerId,
        accessToken: accessToken,
      );

      if (accessToken.isNotEmpty) {
        _apiClient.setAuth(accessToken, customerId, refreshToken: refreshToken);
      }
      await _saveLocalSession(result, refreshToken: refreshToken);
      if (accessToken.isNotEmpty) {
        await NotificationService.instance.registerTokenForAuthenticatedUser(
          force: true,
        );
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
      debugPrint('[CustomerAuthService] Registration error: $e');
      rethrow;
    }
  }

  Future<void> _saveLocalSession(
    RegisteredCustomerResult result, {
    String? refreshToken,
  }) async {
    // Persist via SecureStorageService (canonical store read by ApiClient interceptor)
    try {
      if (result.accessToken != null && result.accessToken!.isNotEmpty) {
        await SecureStorageService.saveTokens(
          accessToken: result.accessToken!,
          refreshToken: refreshToken ?? '',
        );
      }
      await SecureStorageService.saveUserData(
        userId: int.tryParse(result.userId) ?? 0,
        role: 'CUSTOMER',
        email: result.email,
        customerId: result.customerId,
        customerName: result.companyName.isNotEmpty ? result.companyName : null,
      );
    } catch (e) {
      debugPrint('[CustomerAuthService] SecureStorage save error: $e');
    }

    // Also sync SharedPreferences for legacy compatibility
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_savedCustomerKey, result.email);
      await prefs.setString('user_email', result.email);
      await prefs.setString('customer_name', result.companyName);
      await prefs.setString('customer_id', result.customerId);
      await prefs.setString('customer_city', result.city);
      await prefs.setString('auth_user_role', 'CUSTOMER');
      if (result.accessToken != null && result.accessToken!.isNotEmpty) {
        await prefs.setString('access_token', result.accessToken!);
      }
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await prefs.setString('refresh_token', refreshToken);
      }
      // NOTE: Do NOT store a fabricated/fake refresh token if none was returned.
      // A fake token causes 401 when the real access token expires and the interceptor
      // attempts to use it. Without a refresh token, the user will be asked to log in again.
    } catch (e) {
      debugPrint('[CustomerAuthService] Error saving local session: $e');
    }
  }

  static Future<String?> getSavedCustomerId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? id = prefs.getString('customer_id');
      if (id == null) {
        id = prefs.getString('tenant_id');
        if (id != null) {
          await prefs.setString('customer_id', id);
        }
      }
      return id;
    } catch (e) {
      return null;
    }
  }
}
