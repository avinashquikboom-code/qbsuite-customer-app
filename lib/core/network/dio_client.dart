import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/environment.dart';
import '../errors/app_failure.dart';
import '../storage/session_store.dart';

final dioProvider = Provider<Dio>((ref) {
  final store = ref.watch(sessionStoreProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: Environment.apiBaseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {'Accept': 'application/json'},
    ),
  );
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        try {
          Environment.validate(requireUrl: true);
        } catch (_) {
          handler.reject(
            DioException(
              requestOptions: options,
              error: const AppFailure(
                'Configure API_BASE_URL before signing in.',
              ),
            ),
          );
          return;
        }
        final token = store.current?.accessToken;
        if (options.extra['public'] != true && token != null)
          options.headers['Authorization'] = 'Bearer $token';
        // Do not log URLs, bodies, credentials, user data, or headers.
        if (kDebugMode) debugPrint('[HTTP] ${options.method} request');
        handler.next(options);
      },
      onResponse: (response, handler) {
        if (kDebugMode) debugPrint('[HTTP] response ${response.statusCode}');
        handler.next(response);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401 &&
            error.requestOptions.extra['public'] != true &&
            error.requestOptions.headers['Authorization'] ==
                'Bearer ${store.current?.accessToken}') {
          try {
            await store.clear();
          } catch (_) {
            /* Memory session is already cleared. */
          }
        }
        handler.next(
          error.copyWith(
            error: error.error is AppFailure
                ? error.error
                : AppFailure.fromDio(error),
          ),
        );
      },
    ),
  );
  ref.onDispose(() => dio.close(force: true));
  return dio;
});
