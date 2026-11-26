import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickboom_crm_customer/core/network/api_client.dart';
import 'package:quickboom_crm_customer/core/network/app_url.dart';
import 'package:quickboom_crm_customer/core/services/secure_storage_service.dart';

class _ResponseAdapter implements HttpClientAdapter {
  final FutureOr<ResponseBody> Function(RequestOptions) handle;

  _ResponseAdapter(this.handle);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => handle(options);

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body, int status) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

String _jwt({required int expiresAtSeconds}) {
  final payload = base64Url
      .encode(
        utf8.encode(
          jsonEncode({'sub': 1, 'customerId': 7, 'exp': expiresAtSeconds}),
        ),
      )
      .replaceAll('=', '');
  return 'header.$payload.signature';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const oldRefresh = 'old-refresh';
  const nextRefresh = 'next-refresh';
  final futureExp = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;

  setUp(() {
    SecureStorageService.setMockInitialValues({
      'access_token': _jwt(expiresAtSeconds: futureExp),
      'refresh_token': oldRefresh,
      'customer_id': '7',
      'user_role': 'CUSTOMER',
    });
  });

  tearDown(() {
    SecureStorageService.clearMockValues();
    ApiClient.onSessionExpired = null;
  });

  Dio makeDio(HttpClientAdapter adapter) {
    final dio = Dio(BaseOptions(baseUrl: AppUrl.baseUrl));
    dio.httpClientAdapter = adapter;
    return dio;
  }

  ApiClient makeClient({
    required HttpClientAdapter apiAdapter,
    required HttpClientAdapter refreshAdapter,
  }) => ApiClient.forTesting(
    dio: makeDio(apiAdapter),
    refreshDio: makeDio(refreshAdapter),
  );

  test(
    '401 refreshes once, rotates tokens, and retries original request',
    () async {
      var protectedCalls = 0;
      var refreshCalls = 0;
      final newAccess = _jwt(expiresAtSeconds: futureExp + 3600);
      final client = makeClient(
        apiAdapter: _ResponseAdapter((options) {
          protectedCalls++;
          if (options.headers['Authorization'] ==
              'Bearer ${_jwt(expiresAtSeconds: futureExp)}') {
            return _json({'message': 'expired'}, 401);
          }
          return _json({'ok': true}, 200);
        }),
        refreshAdapter: _ResponseAdapter((options) {
          refreshCalls++;
          return _json({
            'tokens': {'accessToken': newAccess, 'refreshToken': nextRefresh},
          }, 200);
        }),
      );

      final response = await client.dio.get('/protected');

      expect(response.statusCode, 200);
      expect(protectedCalls, 2);
      expect(refreshCalls, 1);
      expect(await SecureStorageService.getAccessToken(), newAccess);
      expect(await SecureStorageService.getRefreshToken(), nextRefresh);
    },
  );

  test('concurrent 401 responses share one refresh operation', () async {
    var refreshCalls = 0;
    final oldAccess = _jwt(expiresAtSeconds: futureExp);
    final newAccess = _jwt(expiresAtSeconds: futureExp + 3600);
    SecureStorageService.setMockInitialValues({
      'access_token': oldAccess,
      'refresh_token': oldRefresh,
      'customer_id': '7',
      'user_role': 'CUSTOMER',
    });
    final client = makeClient(
      apiAdapter: _ResponseAdapter((options) {
        if (options.headers['Authorization'] == 'Bearer $oldAccess') {
          return _json({'message': 'expired'}, 401);
        }
        return _json({'ok': true}, 200);
      }),
      refreshAdapter: _ResponseAdapter((_) async {
        refreshCalls++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return _json({
          'tokens': {'accessToken': newAccess, 'refreshToken': nextRefresh},
        }, 200);
      }),
    );

    final results = await Future.wait([
      client.dio.get('/protected/a'),
      client.dio.get('/protected/b'),
    ]);

    expect(results.map((response) => response.statusCode), everyElement(200));
    expect(refreshCalls, 1);
  });

  test('server failure during refresh preserves saved credentials', () async {
    final oldAccess = _jwt(expiresAtSeconds: 1);
    SecureStorageService.setMockInitialValues({
      'access_token': oldAccess,
      'refresh_token': oldRefresh,
      'customer_id': '7',
      'user_role': 'CUSTOMER',
    });
    final client = makeClient(
      apiAdapter: _ResponseAdapter((_) => _json({'ok': true}, 200)),
      refreshAdapter: _ResponseAdapter(
        (_) => _json({'error': 'unavailable'}, 503),
      ),
    );

    await expectLater(
      client.dio.get('/protected'),
      throwsA(isA<DioException>()),
    );
    expect(await SecureStorageService.getAccessToken(), oldAccess);
    expect(await SecureStorageService.getRefreshToken(), oldRefresh);
  });

  test('rejected refresh clears the session and reports expiration', () async {
    final oldAccess = _jwt(expiresAtSeconds: 1);
    SecureStorageService.setMockInitialValues({
      'access_token': oldAccess,
      'refresh_token': oldRefresh,
      'customer_id': '7',
      'user_role': 'CUSTOMER',
    });
    var expiredCalls = 0;
    ApiClient.onSessionExpired = (_) => expiredCalls++;
    final client = makeClient(
      apiAdapter: _ResponseAdapter((_) => _json({'ok': true}, 200)),
      refreshAdapter: _ResponseAdapter(
        (_) => _json({'message': 'invalid'}, 401),
      ),
    );

    await expectLater(
      client.dio.get('/protected'),
      throwsA(isA<DioException>()),
    );
    expect(await SecureStorageService.getAccessToken(), isNull);
    expect(await SecureStorageService.getRefreshToken(), isNull);
    expect(expiredCalls, 1);
  });

  test(
    'a second endpoint 401 after refresh does not erase the session',
    () async {
      final oldAccess = _jwt(expiresAtSeconds: futureExp);
      SecureStorageService.setMockInitialValues({
        'access_token': oldAccess,
        'refresh_token': oldRefresh,
        'customer_id': '7',
        'user_role': 'CUSTOMER',
      });
      final newAccess = _jwt(expiresAtSeconds: futureExp + 3600);
      var expiredCalls = 0;
      ApiClient.onSessionExpired = (_) => expiredCalls++;
      final client = makeClient(
        apiAdapter: _ResponseAdapter((_) => _json({'message': 'denied'}, 401)),
        refreshAdapter: _ResponseAdapter(
          (_) => _json({
            'tokens': {'accessToken': newAccess, 'refreshToken': nextRefresh},
          }, 200),
        ),
      );

      await expectLater(
        client.dio.get('/protected'),
        throwsA(isA<DioException>()),
      );
      expect(await SecureStorageService.getAccessToken(), newAccess);
      expect(await SecureStorageService.getRefreshToken(), nextRefresh);
      expect(expiredCalls, 0);
    },
  );

  test('permission-only 403 does not log out the customer', () async {
    final oldAccess = _jwt(expiresAtSeconds: futureExp);
    SecureStorageService.setMockInitialValues({
      'access_token': oldAccess,
      'refresh_token': oldRefresh,
      'customer_id': '7',
      'user_role': 'CUSTOMER',
    });
    var expiredCalls = 0;
    ApiClient.onSessionExpired = (_) => expiredCalls++;
    final client = makeClient(
      apiAdapter: _ResponseAdapter(
        (_) => _json({'statusCode': 403, 'message': 'Permission denied'}, 403),
      ),
      refreshAdapter: _ResponseAdapter((_) => _json({}, 500)),
    );

    await expectLater(
      client.dio.get('/restricted'),
      throwsA(isA<DioException>()),
    );
    expect(await SecureStorageService.getAccessToken(), oldAccess);
    expect(await SecureStorageService.getRefreshToken(), oldRefresh);
    expect(expiredCalls, 0);
  });

  test('an unauthenticated device-token request cannot trigger logout', () async {
    SecureStorageService.setMockInitialValues({});
    var expiredCalls = 0;
    var refreshCalls = 0;
    ApiClient.onSessionExpired = (_) => expiredCalls++;
    final client = makeClient(
      apiAdapter: _ResponseAdapter((_) => _json({'message': 'unauthorized'}, 401)),
      refreshAdapter: _ResponseAdapter((_) { refreshCalls++; return _json({}, 401); }),
    );
    await expectLater(client.dio.delete('/notifications/device-token'), throwsA(isA<DioException>()));
    expect(refreshCalls, 0);
    expect(expiredCalls, 0);
  });

  test('missing refresh token does not clear an existing session', () async {
    final oldAccess = _jwt(expiresAtSeconds: futureExp);
    SecureStorageService.setMockInitialValues({'access_token': oldAccess, 'customer_id': '7', 'user_role': 'CUSTOMER'});
    var expiredCalls = 0;
    ApiClient.onSessionExpired = (_) => expiredCalls++;
    final client = makeClient(
      apiAdapter: _ResponseAdapter((_) => _json({'message': 'unauthorized'}, 401)),
      refreshAdapter: _ResponseAdapter((_) => _json({}, 401)),
    );
    await expectLater(client.dio.get('/protected'), throwsA(isA<DioException>()));
    expect(await SecureStorageService.getAccessToken(), oldAccess);
    expect(expiredCalls, 0);
  });
}
