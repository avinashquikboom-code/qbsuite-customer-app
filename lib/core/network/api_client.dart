import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/secure_storage_service.dart';
import '../utils/app_logger.dart';
import 'app_url.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

enum RefreshResultStatus { success, authFailed, networkError }

/// Centralized Dio HTTP client for QuikBoom CRM with master debug logging and resilient session handling.
class ApiClient {
  static void Function(String reason)? onSessionExpired;

  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio _dio;
  late final Dio _refreshDio;
  String? _token;
  String? _refreshToken;
  String? _customerId;

  Dio get dio => _dio;
  String? get token => _token;
  String? get refreshToken => _refreshToken;
  String? get customerId => _customerId;

  Future<(RefreshResultStatus, String?)>? _refreshFuture;
  int _sessionGeneration = 0;
  int _credentialVersion = 0;
  bool _credentialsNeedPersistence = false;

  /// Isolated clients let tests exercise the real interceptors without network.
  @visibleForTesting
  ApiClient.forTesting({required Dio dio, required Dio refreshDio})
    : this._internal(dio: dio, refreshDio: refreshDio);

  Future<(RefreshResultStatus, String?)> _refreshSession() {
    if (_refreshFuture != null) return _refreshFuture!;
    late final Future<(RefreshResultStatus, String?)> pending;
    pending = _doRefreshToken().whenComplete(() {
      if (identical(_refreshFuture, pending)) _refreshFuture = null;
    });
    return _refreshFuture = pending;
  }

  static String? _cleanCredential(String? value) {
    final clean = value?.trim().replaceAll(RegExp(r'''^["']|["']$'''), '');
    if (clean == null ||
        clean.isEmpty ||
        ['null', 'undefined', '[object Object]'].contains(clean)) {
      return null;
    }
    return clean;
  }

  DioException _refreshFailure(
    RequestOptions options,
    RefreshResultStatus status,
  ) => DioException(
    requestOptions: options,
    type: status == RefreshResultStatus.authFailed
        ? DioExceptionType.badResponse
        : DioExceptionType.connectionError,
    response: status == RefreshResultStatus.authFailed
        ? Response(
            requestOptions: options,
            statusCode: 401,
            data: {'message': 'Session expired. Please log in again.'},
          )
        : null,
    message: status == RefreshResultStatus.authFailed
        ? 'Session expired. Please log in again.'
        : 'Unable to refresh session. Check your connection and try again.',
  );

  /// Single source of truth for base URL across all platforms and environments.
  static String get resolvedBaseUrl => AppUrl.baseUrl;

  /// Helper to normalize paths and avoid double-prefixing /api/v1
  static String normalizeEndpoint(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return trimmed;
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      final uri = Uri.tryParse(trimmed);
      if (uri != null && uri.host == Uri.parse(AppUrl.baseUrl).host) {
        String p = uri.path;
        if (p.startsWith('/api/v1')) {
          p = p.substring('/api/v1'.length);
        }
        return p.isEmpty ? '/' : p;
      }
      return trimmed;
    }
    if (trimmed.startsWith('/api/v1/')) {
      return trimmed.substring('/api/v1'.length);
    }
    if (trimmed == '/api/v1') {
      return '/';
    }
    return trimmed;
  }

  /// Single source of truth for recognizing unauthenticated auth endpoints.
  static bool isAuthPath(String path) {
    final lower = path.toLowerCase();
    return lower.contains('/login') ||
        lower.contains('/register') ||
        lower.contains('/refresh') ||
        lower.contains('otp') ||
        lower.contains('forgot-password') ||
        lower.contains('reset-password');
  }

  ApiClient._internal({Dio? dio, Dio? refreshDio}) {
    const buildMode = kReleaseMode
        ? 'RELEASE'
        : kProfileMode
        ? 'PROFILE'
        : 'DEBUG';
    const environment = kReleaseMode ? 'production' : 'development';
    const appVersion = '1.0.0+1';

    debugPrint('==================================================');
    debugPrint('[DEVICE DEBUG]');
    debugPrint('Build Mode: $buildMode');
    debugPrint('API Base URL: ${AppUrl.baseUrl}');
    debugPrint('Environment: $environment');
    debugPrint('App Version: $appVersion');
    debugPrint('==================================================');
    debugPrint('[API_CONFIG]');
    debugPrint('baseUrl=${AppUrl.baseUrl}');
    debugPrint('==================================================');
    final baseUri = Uri.tryParse(AppUrl.baseUrl);
    debugPrint('[NETWORK_DIAGNOSTIC]');
    debugPrint(
      'baseUrl=${baseUri != null ? "${baseUri.scheme}://${baseUri.host}" : AppUrl.baseUrl}',
    );
    debugPrint('host=${baseUri?.host ?? "api.qbapp.online"}');
    debugPrint('scheme=${baseUri?.scheme ?? "https"}');
    debugPrint('==================================================');
    debugPrint('[NETWORK_DEBUG]');
    debugPrint('baseUrl: ${AppUrl.baseUrl}');
    debugPrint('platform: ${defaultTargetPlatform.name}');
    debugPrint('connectTimeout: 30s');
    debugPrint('receiveTimeout: 30s');
    debugPrint('sendTimeout: 30s');
    debugPrint('==================================================');

    _dio =
        dio ??
        Dio(
          BaseOptions(
            baseUrl: AppUrl.baseUrl,
            connectTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 30),
            sendTimeout: const Duration(seconds: 30),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'x-client-type': 'mobile',
              'x-app': 'customer',
            },
          ),
        );

    if (dio == null) {
      _dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.connectionTimeout = const Duration(seconds: 30);
          return client;
        },
      );
    }

    _refreshDio =
        refreshDio ??
        Dio(
          BaseOptions(
            baseUrl: _dio.options.baseUrl,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 15),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              'x-client-type': 'mobile',
              'x-app': 'customer',
            },
          ),
        );

    // ── Interceptor: Auth & Master Debug Logging ──────────────────────────────
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          options.path = normalizeEndpoint(options.path);

          final isAuthEndpoint = isAuthPath(options.path);

          final requestGeneration = _sessionGeneration;
          if (_credentialsNeedPersistence && _token != null && _refreshToken != null) {
            try {
              await SecureStorageService.saveTokens(accessToken: _token!, refreshToken: _refreshToken!);
              _credentialsNeedPersistence = false;
            } catch (error) {
              return handler.reject(DioException(requestOptions: options, type: DioExceptionType.unknown, message: 'Unable to save the session. Please retry.', error: error));
            }
          }
          final credentialVersion = _credentialVersion;
          // Read the persisted credential set together; a missing value must clear
          // stale in-memory credentials after logout, rather than resurrect them.
          List<String?> credentials;
          try {
            credentials = await Future.wait([
              SecureStorageService.getAccessToken(),
              SecureStorageService.getRefreshToken(),
              SecureStorageService.getCustomerId(),
            ]);
          } catch (error) {
            return handler.reject(DioException(
              requestOptions: options,
              type: DioExceptionType.unknown,
              message: 'Unable to read the saved session. Please retry.',
              error: error,
            ));
          }
          if (requestGeneration != _sessionGeneration) {
            return handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.cancel,
                message: 'Authentication session changed. Please retry.',
              ),
            );
          }
          if (credentialVersion == _credentialVersion) {
            _token = _cleanCredential(credentials[0]);
            _refreshToken = _cleanCredential(credentials[1]);
            _customerId = _cleanCredential(credentials[2]);
          }

          // Proactive Token Expiration Check & Refresh before sending non-auth requests
          bool tokenExpired = false;
          int? tokenExpSec;
          int? jwtUserId;
          String? jwtCompanyId;

          if (_token != null && _token!.trim().isNotEmpty) {
            try {
              final parts = _token!.trim().split('.');
              if (parts.length == 3) {
                final normalized = base64Url.normalize(parts[1]);
                final decoded = utf8.decode(base64Url.decode(normalized));
                final map = jsonDecode(decoded);
                if (map is Map) {
                  if (map['exp'] is num) {
                    tokenExpSec = (map['exp'] as num).toInt();
                    final nowSec =
                        DateTime.now().millisecondsSinceEpoch ~/ 1000;
                    tokenExpired = tokenExpSec <= nowSec;
                  }
                  final rawUid = map['sub'] ?? map['id'] ?? map['userId'];
                  if (rawUid != null) {
                    jwtUserId = int.tryParse(rawUid.toString());
                  }
                  final rawCid =
                      map['customerId'] ?? map['companyId'] ?? map['tenantId'];
                  if (rawCid != null) jwtCompanyId = rawCid.toString();
                }
              }
            } catch (_) {}
          }

          final isExpiringSoon =
              tokenExpSec != null &&
              tokenExpSec <=
                  (DateTime.now().millisecondsSinceEpoch ~/ 1000 + 30);
          if (!isAuthEndpoint && tokenExpSec != null) {
            debugPrint(
              '[AUTH_TOKEN] endpoint=${options.path} expiresAt=${DateTime.fromMillisecondsSinceEpoch(tokenExpSec * 1000).toUtc().toIso8601String()}',
            );
          }

          if (!isAuthEndpoint &&
              (isExpiringSoon || tokenExpired || _token == null) &&
              _refreshToken != null &&
              options.extra['__retried'] != true) {
            debugPrint('[AUTH_ACCESS_TOKEN_EXPIRED] refresh_required=true');
            final (status, refreshed) = await _refreshSession();
            if (requestGeneration != _sessionGeneration) {
              return handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.cancel,
                  message: 'Authentication session changed. Please retry.',
                ),
              );
            }
            if (status != RefreshResultStatus.success || refreshed == null) {
              if (status == RefreshResultStatus.authFailed) {
                await clearAuth(reason: 'refresh_token_rejected');
              }
              return handler.reject(_refreshFailure(options, status));
            }
            _token = refreshed;
            tokenExpired = false;
          }

          // Never retain caller/default credentials after logout or on auth routes.
          options.headers.remove('Authorization');
          options.headers.remove('authorization');
          options.headers.remove('x-customer-id');
          options.extra['__sessionGeneration'] = _sessionGeneration;

          final hasValidToken =
              _token != null &&
              _token!.trim().isNotEmpty &&
              _token != 'null' &&
              _token != 'undefined' &&
              _token != '[object Object]';

          final authHeaderAttached = hasValidToken && !isAuthEndpoint;
          if (authHeaderAttached) {
            options.headers.remove('authorization');
            options.headers['Authorization'] = 'Bearer ${_token!.trim()}';
          }

          // The API rejects the request when this header does not match the
          // customer on the token. Prefer the token value so a stale stored id
          // cannot blank the customer's subscription.
          final tokenCustomerId = jwtCompanyId?.trim();
          final storedCustomerId = _customerId?.trim();
          final headerCustomerId =
              (tokenCustomerId != null &&
                  tokenCustomerId.isNotEmpty &&
                  tokenCustomerId != 'null' &&
                  tokenCustomerId != 'undefined')
              ? tokenCustomerId
              : (storedCustomerId != null &&
                    storedCustomerId.isNotEmpty &&
                    storedCustomerId != 'null' &&
                    storedCustomerId != 'undefined')
              ? storedCustomerId
              : null;
          if (headerCustomerId != null) {
            options.headers['x-customer-id'] = headerCustomerId;
          }
          options.extra['__startTime'] = DateTime.now().millisecondsSinceEpoch;

          final effectiveUserId =
              jwtUserId ?? (await SecureStorageService.getUserId());
          final effectiveEmployeeId =
              await SecureStorageService.getEmployeeId();
          final effectiveCompanyId =
              jwtCompanyId ??
              _customerId ??
              (await SecureStorageService.getCustomerId());

          debugPrint('''
[AUTH DEBUG]
endpoint: ${options.path}
hasAccessToken: $hasValidToken
tokenExpired: $tokenExpired
userId: ${effectiveUserId?.toString() ?? 'none'}
employeeId: ${effectiveEmployeeId ?? 'none'}
companyId: ${effectiveCompanyId ?? 'none'}''');
          debugPrint('[API_BASE_URL] ${options.baseUrl}');

          // Safe authentication diagnostics for customer endpoints
          if (options.path.contains('/customers/') ||
              options.path.endsWith('/customers')) {
            debugPrint('Customer API request:');
            debugPrint('${options.method} ${options.path}');
            debugPrint('Authorization header exists: $authHeaderAttached');
            debugPrint('Access token exists: $hasValidToken');
          }

          final safeFullUrl = '${options.baseUrl}${options.path}';
          debugPrint('[API_REQUEST]');
          debugPrint('method=${options.method}');
          debugPrint('url=$safeFullUrl');

          if (options.path.contains('/leads')) {
            debugPrint('[LEADS_REQUEST]');
            debugPrint('method=${options.method}');
            debugPrint('url=$safeFullUrl');
            debugPrint('authHeaderAttached=$authHeaderAttached');
            debugPrint('hasValidToken=$hasValidToken');
          }

          AppLogger.apiRequest(
            method: options.method,
            url: safeFullUrl,
            queryParameters: options.queryParameters,
            body: options.data,
            headers: options.headers,
            customerId: _customerId,
          );

          return handler.next(options);
        },
        onResponse: (response, handler) {
          final start = response.requestOptions.extra['__startTime'] as int?;
          final durationMs = start != null
              ? DateTime.now().millisecondsSinceEpoch - start
              : 0;

          int? recordsCount;
          if (response.data is List) {
            recordsCount = (response.data as List).length;
          } else if (response.data is Map && response.data['data'] is List) {
            recordsCount = (response.data['data'] as List).length;
          }

          AppLogger.apiResponse(
            method: response.requestOptions.method,
            url:
                '${response.requestOptions.baseUrl}${response.requestOptions.path}',
            statusCode: response.statusCode ?? 200,
            durationMs: durationMs,
            data: response.data,
            recordsCount: recordsCount,
          );

          if (response.requestOptions.path.contains('/leads')) {
            debugPrint('[NETWORK_RESULT]');
            debugPrint('dns=resolved');
            debugPrint('connection=success');
            debugPrint('httpStatus=${response.statusCode}');
          }

          return handler.next(response);
        },
        onError: (error, handler) async {
          final start = error.requestOptions.extra['__startTime'] as int?;
          final durationMs = start != null
              ? DateTime.now().millisecondsSinceEpoch - start
              : 0;

          final isAuthEndpoint = isAuthPath(error.requestOptions.path);
          AppLogger.apiError(
            method: error.requestOptions.method,
            url: '${error.requestOptions.baseUrl}${error.requestOptions.path}',
            statusCode: error.response?.statusCode,
            message: error.message ?? 'Unknown Dio error (${durationMs}ms)',
            responseData: error.response?.data,
            // Do not stringify Dio exceptions: their RequestOptions may carry
            // Authorization headers even for otherwise safe API failures.
            error: isAuthEndpoint ? null : 'DioExceptionType.${error.type.name}',
            stackTrace: error.stackTrace,
            queryParameters: error.requestOptions.queryParameters,
          );

          if (error.requestOptions.path.contains('/leads')) {
            final isConnectionOrDnsError =
                error.type == DioExceptionType.connectionError ||
                error.type == DioExceptionType.connectionTimeout ||
                error.error is SocketException ||
                (error.message != null &&
                    (error.message!.contains('Failed host lookup') ||
                        error.message!.contains('SocketException')));
            debugPrint('[NETWORK_RESULT]');
            debugPrint('dns=${isConnectionOrDnsError ? "failed" : "resolved"}');
            debugPrint(
              'connection=${isConnectionOrDnsError ? "failed" : "success"}',
            );
            debugPrint('httpStatus=${error.response?.statusCode ?? "none"}');
          }

          final alreadyRetried =
              error.requestOptions.extra['__retried'] == true;

          final responseCode = _responseCode(error.response?.data);
          final terminalAccountFailure = _isTerminalAccountFailure(
            error.response?.data,
          );
          final sentAuthorization = error.requestOptions.headers['Authorization']?.toString().trim();
          if (terminalAccountFailure && !isAuthEndpoint &&
              sentAuthorization != null && sentAuthorization.isNotEmpty &&
              error.requestOptions.extra['__sessionGeneration'] == _sessionGeneration) {
            debugPrint(
              '[SESSION_AUTH_FAILURE] endpoint=${error.requestOptions.path} status=${error.response?.statusCode} code=$responseCode',
            );
            await clearAuth(reason: responseCode ?? 'account_disabled');
            return handler.next(error);
          }

          if (error.response?.statusCode == 401 && !isAuthEndpoint) {
            final options = error.requestOptions;
            if (sentAuthorization == null || sentAuthorization.isEmpty) {
              debugPrint('[AUTH_UNAUTHENTICATED_REQUEST] endpoint=${options.path}');
              return handler.next(error);
            }
            debugPrint(
              '[SESSION_AUTH_FAILURE] endpoint=${options.path} status=401 retry=${alreadyRetried ? "yes" : "no"}',
            );
            if (options.extra['__sessionGeneration'] != _sessionGeneration) {
              return handler.next(error);
            }

            // A protected endpoint can still return 401 for endpoint-specific
            // reasons. Keep the session unless refresh itself was rejected.
            if (alreadyRetried) {
              return handler.next(error);
            }

            final sent = options.headers['Authorization']?.toString();
            final String? newToken;

            // Late 401: If another concurrent call already refreshed the token, reuse it
            if (_token != null &&
                _token!.trim().isNotEmpty &&
                sent != 'Bearer ${_token!.trim()}') {
              newToken = _token!.trim();
            } else {
              final generation = _sessionGeneration;
              final (status, refreshed) = await _refreshSession();
              if (generation != _sessionGeneration) return handler.next(error);
              if (status != RefreshResultStatus.success ||
                  refreshed == null ||
                  refreshed.trim().isEmpty) {
                if (status == RefreshResultStatus.authFailed) {
                  await clearAuth(reason: 'refresh_token_rejected');
                }
                return handler.next(
                  status == RefreshResultStatus.networkError
                      ? _refreshFailure(options, status)
                      : error,
                );
              }
              newToken = refreshed.trim();
            }

            options.headers['Authorization'] = 'Bearer $newToken';
            options.extra['__retried'] = true;

            try {
              final response = await _dio.fetch(options);
              return handler.resolve(response);
            } on DioException catch (retryError) {
              return handler.next(retryError);
            }
          }

          return handler.next(error);
        },
      ),
    );
  }

  Future<(RefreshResultStatus, String?)> _doRefreshToken() async {
    debugPrint('[AUTH_REFRESH_STARTED]');
    debugPrint('[TOKEN_REFRESH]');
    debugPrint('started');

    if (_refreshToken == null || _refreshToken!.trim().isEmpty) {
      _refreshToken = await SecureStorageService.getRefreshToken();
    }
    if (_refreshToken == null || _refreshToken!.trim().isEmpty) {
      debugPrint('[TOKEN_REFRESH]');
      debugPrint('failed');
      debugPrint('reason: no_refresh_token');
      return (RefreshResultStatus.networkError, null);
    }

    final generation = _sessionGeneration;
    final refreshCredential = _refreshToken!.trim();
    try {
      Response? resp;
      try {
        resp = await _refreshDio.post(
          AppUrl.refreshToken,
          data: {'refreshToken': refreshCredential},
        );
      } on DioException catch (dioE) {
        if (dioE.response?.statusCode == 404) {
          resp = await _refreshDio.post(
            '/auth/refresh-tokens',
            data: {'refreshToken': refreshCredential},
          );
        } else {
          rethrow;
        }
      }

      debugPrint(
        '[TOKEN_REFRESH] endpoint=${resp.requestOptions.path} status=${resp.statusCode ?? "none"}',
      );

      if (resp.statusCode != null &&
          resp.statusCode! >= 200 &&
          resp.statusCode! < 300 &&
          resp.data != null) {
        dynamic data = resp.data;
        if (data is Map && data['data'] != null && data['data'] is Map) {
          data = data['data'];
        }
        if (data is Map) {
          String? newAccessToken;
          String? newRefreshToken;

          if (data['tokens'] is Map) {
            newAccessToken = data['tokens']['accessToken'] as String?;
            newRefreshToken = data['tokens']['refreshToken'] as String?;
          }
          newAccessToken ??= data['accessToken'] as String?;
          newRefreshToken ??= data['refreshToken'] as String?;

          if (newAccessToken != null && newAccessToken.trim().isNotEmpty) {
            if (generation != _sessionGeneration ||
                _refreshToken != refreshCredential) {
              return (RefreshResultStatus.networkError, null);
            }
            final cleanAccess = newAccessToken.trim();
            _token = cleanAccess;
            if (newRefreshToken != null && newRefreshToken.trim().isNotEmpty) {
              _refreshToken = newRefreshToken.trim();
            }
            _credentialVersion++;
            _credentialsNeedPersistence = true;
            await SecureStorageService.saveTokens(
              accessToken: cleanAccess,
              refreshToken: _refreshToken ?? '',
            );
            _credentialsNeedPersistence = false;
            debugPrint('[TOKEN_REFRESH]');
            debugPrint('success');
            debugPrint('[AUTH_REFRESH_SUCCESS]');
            return (RefreshResultStatus.success, cleanAccess);
          }
        }
      }
    } on DioException catch (dioErr) {
      final status = dioErr.response?.statusCode;
      debugPrint('[AUTH_REFRESH_FAILED] status=${status ?? "none"} type=${dioErr.type.name}');
      if (status == 401 || status == 403) {
        debugPrint('[TOKEN_REFRESH]');
        debugPrint('failed');
        final terminalAccountFailure = _isTerminalAccountFailure(
          dioErr.response?.data,
        );
        if (status == 401 || terminalAccountFailure) {
          debugPrint('endpoint=${AppUrl.refreshToken} status=$status');
          debugPrint('reason: refresh_token_rejected');
          return (RefreshResultStatus.authFailed, null);
        }
        debugPrint('endpoint=${AppUrl.refreshToken} status=$status');
        debugPrint('reason: refresh_not_authorized_or_server_error');
        return (RefreshResultStatus.networkError, null);
      } else {
        debugPrint('[TOKEN_REFRESH]');
        debugPrint('failed');
        debugPrint(
          'endpoint=${AppUrl.refreshToken} status=${status ?? "none"} type=${dioErr.type.name}',
        );
        debugPrint('reason: temporary_refresh_failure');
        return (RefreshResultStatus.networkError, null);
      }
    } catch (e) {
      debugPrint('[TOKEN_REFRESH]');
      debugPrint('failed');
      debugPrint('reason: unexpected_error type=${e.runtimeType}');
      return (RefreshResultStatus.networkError, null);
    }

    debugPrint('[TOKEN_REFRESH]');
    debugPrint('failed');
    debugPrint('endpoint=${AppUrl.refreshToken} status=invalid_response');
    debugPrint('reason: malformed_refresh_response');
    return (RefreshResultStatus.networkError, null);
  }

  static String? _responseCode(dynamic responseData) {
    if (responseData is! Map) return null;
    final nested = responseData['data'];
    final data = nested is Map ? nested : responseData;
    final value = data['code'] ?? responseData['code'];
    return value?.toString().trim().toUpperCase();
  }

  static bool _isTerminalAccountFailure(dynamic responseData) {
    const terminalCodes = {
      'ACCOUNT_DISABLED',
      'ACCOUNT_DEACTIVATED',
      'ACCOUNT_BLOCKED',
      'WORKSPACE_SUSPENDED',
      'SESSION_REVOKED',
      'REFRESH_TOKEN_REVOKED',
    };
    return terminalCodes.contains(_responseCode(responseData));
  }

  void setAuth(String token, String customerId, {String? refreshToken}) {
    _sessionGeneration++;
    _credentialVersion++;
    _credentialsNeedPersistence = false;
    _token = token.trim();
    _customerId = customerId.trim();
    final normalizedRefreshToken = refreshToken?.trim();
    _refreshToken = normalizedRefreshToken?.isNotEmpty == true
        ? normalizedRefreshToken
        : null;
    debugPrint(
      '[API] Auth configured for customer: $customerId (token exists: ${token.isNotEmpty})',
    );
  }

  /// Explicitly ensure in-memory token and customerId are loaded from persistent secure storage.
  Future<bool> ensureAuthLoaded() async {
    try {
      if (_token == null || _token!.trim().isEmpty) {
        final storedToken = await SecureStorageService.getAccessToken();
        if (storedToken != null && storedToken.trim().isNotEmpty) {
          _token = storedToken.trim();
        }
      }
      if (_refreshToken == null || _refreshToken!.trim().isEmpty) {
        final storedRefresh = await SecureStorageService.getRefreshToken();
        if (storedRefresh != null && storedRefresh.trim().isNotEmpty) {
          _refreshToken = storedRefresh.trim();
        }
      }
      if (_customerId == null || _customerId!.trim().isEmpty) {
        final storedCustId = await SecureStorageService.getCustomerId();
        if (storedCustId != null && storedCustId.trim().isNotEmpty) {
          _customerId = storedCustId.trim();
        }
      }
      return _token != null && _token!.trim().isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> initAuthFromStorage() async {
    try {
      var token = await SecureStorageService.getAccessToken();
      var refresh = await SecureStorageService.getRefreshToken();
      var custId = await SecureStorageService.getCustomerId() ?? '';

      if (token != null && token.isNotEmpty) {
        setAuth(token, custId, refreshToken: refresh);
        return true;
      } else if (refresh != null && refresh.isNotEmpty) {
        _refreshToken = refresh;
        final (refreshStatus, newToken) = await _refreshSession();
        if (refreshStatus == RefreshResultStatus.success &&
            newToken != null &&
            newToken.isNotEmpty) {
          setAuth(newToken, custId, refreshToken: _refreshToken);
          return true;
        }
      }
    } catch (e) {
      debugPrint('[API] initAuthFromStorage errorType=${e.runtimeType}');
    }
    return false;
  }

  Future<String?> refreshAuthDirectly({
    String? refreshToken,
    String? customerId,
  }) async {
    if (refreshToken != null && refreshToken.trim().isNotEmpty) {
      _refreshToken = refreshToken.trim();
    }
    if (customerId != null) {
      _customerId = customerId;
    }
    try {
      final (status, token) = await _refreshSession();
      return token;
    } catch (e) {
      debugPrint('[API] Direct refresh errorType=${e.runtimeType}');
      return null;
    }
  }

  Future<(RefreshResultStatus, String?)> refreshAuthDirectlyWithStatus({
    String? refreshToken,
    String? customerId,
  }) async {
    if (refreshToken != null && refreshToken.trim().isNotEmpty) {
      _refreshToken = refreshToken.trim();
    }
    if (customerId != null) _customerId = customerId;
    try {
      return await _refreshSession();
    } catch (e) {
      debugPrint('[TOKEN_REFRESH] endpoint=${AppUrl.refreshToken} status=none');
      debugPrint('[TOKEN_REFRESH] result=network_error');
      return (RefreshResultStatus.networkError, null);
    }
  }

  Future<void> clearAuth({
    bool notifySessionExpired = true,
    String reason = 'unspecified',
  }) async {
    _sessionGeneration++;
    _credentialVersion++;
    _credentialsNeedPersistence = false;
    _refreshFuture = null;
    _token = null;
    _refreshToken = null;
    _customerId = null;
    try {
      await SecureStorageService.clearAll();
    } catch (e) {
      debugPrint('[API] Error clearing auth storageType=${e.runtimeType}');
    }
    debugPrint('[SESSION_LOGOUT] reason=$reason');
    debugPrint('[AUTH_LOGOUT_TRIGGERED] reason=$reason');
    if (notifySessionExpired) onSessionExpired?.call(reason);
  }

  // ── HTTP Methods ────────────────────────────────────────────────────────

  /// Test backend health endpoint to verify connectivity.
  Future<bool> testHealth() async {
    try {
      final startTime = DateTime.now();
      final response = await _dio
          .get('/health')
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => throw Exception('Health check timed out after 5s'),
          );
      final durationMs = DateTime.now().difference(startTime).inMilliseconds;
      debugPrint('[HEALTH_CHECK] SUCCESS after ${durationMs}ms');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[HEALTH_CHECK] FAILED type=${e.runtimeType}');
      return false;
    }
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    await ensureAuthLoaded();
    return _dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: options,
    );
  }

  Future<Response> post(String path, {dynamic data, Options? options}) async {
    await ensureAuthLoaded();
    return _dio.post(path, data: data, options: options);
  }

  Future<Response> patch(String path, {dynamic data, Options? options}) async {
    await ensureAuthLoaded();
    return _dio.patch(path, data: data, options: options);
  }

  Future<Response> put(String path, {dynamic data, Options? options}) async {
    await ensureAuthLoaded();
    return _dio.put(path, data: data, options: options);
  }

  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    await ensureAuthLoaded();
    return _dio.delete(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  /// Download binary file bytes (PDFs, images) with strict content-type and error handling.
  Future<Uint8List> downloadFileBytes(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
    required String documentType,
    required String documentId,
    String? orderId,
  }) async {
    await ensureAuthLoaded();

    if (documentType == 'AGREEMENT') {
      debugPrint('[AGREEMENT_DEBUG] method: GET');
      debugPrint('[AGREEMENT_DEBUG] url: ${_dio.options.baseUrl}$endpoint');
      debugPrint('[AGREEMENT_DEBUG] path: $endpoint');
      debugPrint('[AGREEMENT_DEBUG] orderId: ${orderId ?? ""}');
      debugPrint('[AGREEMENT_DEBUG] agreementId: $documentId');
      debugPrint('[AGREEMENT_DEBUG] customerId: ${_customerId ?? ""}');
    }

    try {
      final response = await _dio.get<List<int>>(
        endpoint,
        queryParameters: queryParameters,
        options: Options(
          responseType: ResponseType.bytes,
          headers: {'Accept': 'application/pdf, application/octet-stream'},
        ),
      );

      final statusCode = response.statusCode ?? 0;
      final contentType = response.headers.value('content-type') ?? '';
      final rawData = response.data;

      debugPrint('[DOCUMENT_DEBUG]');
      debugPrint('documentType: $documentType');
      debugPrint('documentId: $documentId');
      debugPrint('orderId: ${orderId ?? "N/A"}');
      debugPrint('customerId: ${_customerId ?? "N/A"}');
      debugPrint('endpoint: $endpoint');
      debugPrint('HTTP status: $statusCode');
      debugPrint('content-type: $contentType');
      debugPrint('response size: ${rawData?.length ?? 0} bytes');

      if (statusCode == 200 && rawData != null && rawData.isNotEmpty) {
        const signature = [0x25, 0x50, 0x44, 0x46, 0x2d]; // %PDF-
        final isPdf = rawData.length >= signature.length &&
            List.generate(signature.length, (i) => rawData[i] == signature[i])
                .every((matches) => matches);
        if (!isPdf) {
          throw const FormatException('The server did not return a valid PDF document.');
        }
        final tailStart = rawData.length > 1024 ? rawData.length - 1024 : 0;
        final tail = String.fromCharCodes(rawData.sublist(tailStart));
        if (!tail.contains('%%EOF')) {
          throw const FormatException('The PDF download is incomplete. Please try again.');
        }
        return Uint8List.fromList(rawData);
      }

      throw Exception('Failed to download $documentType (HTTP $statusCode)');
    } on DioException catch (dioErr) {
      final status = dioErr.response?.statusCode;
      final contentType = dioErr.response?.headers.value('content-type');
      debugPrint('[DOCUMENT_ERROR]');
      debugPrint('type: $documentType');
      debugPrint('endpoint: $endpoint');
      debugPrint('status: $status');
      debugPrint('contentType: $contentType');
      debugPrint('errorType: ${dioErr.type}');
      if (documentType == 'AGREEMENT') {
        debugPrint('[AGREEMENT_DEBUG] status: $status');
      }

      if (status == 401) {
        throw Exception('Session expired. Please log in again.');
      } else if (status == 403) {
        throw Exception("You don't have permission to access this document.");
      } else if (status == 404) {
        throw Exception('Document not found.');
      } else if (status != null && status >= 500) {
        throw Exception('Unable to download document right now.');
      }

      throw Exception('Unable to download the document. Please try again.');
    } catch (e) {
      debugPrint('[DOCUMENT_ERROR] Unexpected errorType=${e.runtimeType}');
      rethrow;
    }
  }

  /// Fire-and-forget multiple independent requests concurrently.
  Future<List<Response>> parallel(List<Future<Response> Function()> requests) =>
      Future.wait(requests.map((fn) => fn()));
}
