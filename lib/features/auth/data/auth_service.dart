import 'package:dio/dio.dart';
import '../../../core/config/app_config.dart';
import '../../../core/errors/app_failure.dart';
import '../domain/session.dart';

class AuthService {
  AuthService(this._dio);
  final Dio _dio;
  Future<Session> signIn(String email, String password) async {
    try {
      final response = await _dio.post<Object?>(AppConfig.loginEndpoint,
        data: {'email': email.trim(), 'password': password}, options: Options(extra: {'public': true}));
      final body = response.data;
      if (body is! Map) throw const AppFailure('Invalid sign-in response.');
      final payload = body['data'] is Map ? body['data'] as Map : body;
      final tokens = payload['tokens'];
      final user = payload['user'];
      final token = tokens is Map ? tokens['accessToken'] : payload['accessToken'];
      if (user is! Map || token is! String || token.trim().isEmpty) throw const AppFailure('Invalid sign-in response.');
      final role = user['role']?.toString().toUpperCase();
      if (!AppConfig.allowedRoles.contains(role)) throw const AppFailure('This account cannot access this application.');
      return Session(accessToken: token, email: user['email']?.toString() ?? email.trim(), role: role!);
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) throw const AppFailure('Email or password is incorrect.');
      throw error.error is AppFailure ? error.error! : AppFailure.fromDio(error);
    }
  }
}
