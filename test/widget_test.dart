import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qb_customer/app/app.dart';
import 'package:qb_customer/core/config/app_config.dart';
import 'package:qb_customer/core/network/dio_client.dart';
import 'package:qb_customer/core/storage/session_store.dart';
import 'package:qb_customer/core/utils/paginated_viewmodel.dart';
import 'package:qb_customer/features/auth/data/auth_service.dart';
import 'package:qb_customer/features/auth/domain/auth_repository.dart';
import 'package:qb_customer/features/auth/domain/session.dart';
import 'package:qb_customer/features/auth/presentation/providers/auth_providers.dart';
import 'package:qb_customer/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:qb_customer/routes/app_router.dart';

class FakeAuthRepository implements AuthRepository {
  Session? session;
  int calls = 0;
  Completer<Session>? pending;
  @override
  Future<Session?> restore() async => session;
  @override
  Future<Session> signIn(String email, String password) async {
    calls++;
    final result =
        await (pending?.future ??
            Future.value(
              Session(
                accessToken: 'test-token',
                email: email,
                role: AppConfig.allowedRoles.first,
              ),
            ));
    session = result;
    return result;
  }

  @override
  Future<void> signOut() async {
    session = null;
  }
}

class StubAdapter implements HttpClientAdapter {
  StubAdapter(this.body, {this.status = 200});
  final int status;
  final Object body;
  RequestOptions? request;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class TestPages extends PaginatedViewModel<int> {
  int calls = 0;
  Completer<PageResult<int>>? pending;
  @override
  Future<PageResult<int>> fetchPage(
    String? cursor,
    CancelToken cancelToken,
  ) async {
    calls++;
    if (cursor == null) return PageResult(items: [1], nextCursor: 'next');
    return pending!.future;
  }
}

final pagesProvider =
    AsyncNotifierProvider.autoDispose<TestPages, PagedState<int>>(
      TestPages.new,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('session is persisted securely and cleared on logout', () async {
    final store = SessionStore(const FlutterSecureStorage());
    addTearDown(store.dispose);
    final session = Session(
      accessToken: 'test-token',
      email: 'sales@example.com',
      role: AppConfig.allowedRoles.first,
    );
    await store.save(session);
    final second = SessionStore(const FlutterSecureStorage());
    addTearDown(second.dispose);
    expect((await second.restore())?.email, session.email);
    await second.clear();
    expect(await store.restore(), isNull);
  });

  test('HTTP credentials stay on the API origin and 401 clears the session', () async {
    final store = SessionStore(const FlutterSecureStorage());
    addTearDown(store.dispose);
    await store.save(Session(accessToken: 'test-token', email: 'test@example.com', role: AppConfig.allowedRoles.first));
    final dio = createApiDio(store: store, baseUrl: 'https://api.example/api/v1');
    addTearDown(() => dio.close(force: true));
    final adapter = StubAdapter({'ok': true});
    dio.httpClientAdapter = adapter;
    await dio.get<Object?>('/profile');
    expect(adapter.request?.headers['Authorization'], 'Bearer test-token');
    await dio.post<Object?>('/login', options: Options(extra: {'public': true}));
    expect(adapter.request?.headers['Authorization'], isNull);
    await expectLater(dio.get<Object?>('https://other.example/profile'), throwsA(isA<DioException>()));
    expect(store.current, isNotNull);
    dio.httpClientAdapter = StubAdapter({}, status: 401);
    await expectLater(dio.get<Object?>('/profile'), throwsA(isA<DioException>()));
    expect(store.current, isNull);
    expect(await store.restore(), isNull);
  });

  test('login validates and deduplicates concurrent submissions', () async {
    final repo = FakeAuthRepository();
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    await container.read(authViewModelProvider.future);
    final model = container.read(authViewModelProvider.notifier);
    await model.signIn('invalid', '');
    expect(container.read(authViewModelProvider).hasError, isTrue);
    expect(repo.calls, 0);
    repo.pending = Completer<Session>();
    final first = model.signIn('sales@example.com', 'password');
    await model.signIn('sales@example.com', 'password');
    expect(repo.calls, 1);
    repo.pending!.complete(
      Session(
        accessToken: 'token',
        email: 'sales@example.com',
        role: AppConfig.allowedRoles.first,
      ),
    );
    await first;
    expect(
      container.read(authViewModelProvider).requireValue?.email,
      'sales@example.com',
    );
    await model.signOut();
    expect(container.read(authViewModelProvider).requireValue, isNull);
  });

  test(
    'auth service uses existing endpoint and parses wrapped tokens',
    () async {
      final adapter = StubAdapter({
        'data': {
          'tokens': {'accessToken': 'token'},
          'user': {
            'email': 'test@example.com',
            'role': AppConfig.allowedRoles.first,
          },
        },
      });
      final dio = Dio()..httpClientAdapter = adapter;
      addTearDown(() => dio.close(force: true));
      final result = await AuthService(dio)
          .signIn(' test@example.com ', 'secret');
      expect(adapter.request?.path, AppConfig.loginEndpoint);
      expect(adapter.request?.data, {
        'email': 'test@example.com',
        'password': 'secret',
      });
      expect(result.accessToken, 'token');
    },
  );

  test('auth service rejects invalid tokens and unauthorized roles', () async {
    final dio = Dio()
      ..httpClientAdapter = StubAdapter({
        'accessToken': 'token',
        'user': {'role': 'SUPER_ADMIN'},
      });
    addTearDown(() => dio.close(force: true));
    await expectLater(
      AuthService(dio).signIn('a@b.com', 'secret'),
      throwsA(isA<Exception>()),
    );
    dio.httpClientAdapter = StubAdapter({
      'user': {'role': AppConfig.allowedRoles.first},
    });
    await expectLater(
      AuthService(dio).signIn('a@b.com', 'secret'),
      throwsA(isA<Exception>()),
    );
  });

  test(
    'pagination deduplicates load more and retains items on failure',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final subscription = container.listen(pagesProvider, (_, next) {});
      addTearDown(subscription.close);
      await container.read(pagesProvider.future);
      final model = container.read(pagesProvider.notifier);
      model.pending = Completer<PageResult<int>>();
      final first = model.loadMore();
      await model.loadMore();
      expect(model.calls, 2);
      model.pending!.completeError(Exception('offline'));
      await first;
      expect(container.read(pagesProvider).requireValue.items, [1]);
      expect(container.read(pagesProvider).requireValue.moreError, isNotNull);
      model.pending = Completer<PageResult<int>>();
      final retry = model.loadMore();
      model.pending!.complete(PageResult(items: [2]));
      await retry;
      expect(container.read(pagesProvider).requireValue.items, [1, 2]);
      await model.loadMore();
      expect(model.calls, 3);
    },
  );

  testWidgets('protected deep link survives sign in and logout blocks access', (
    tester,
  ) async {
    final repo = FakeAuthRepository();
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);
    final target = '/features/orders';
    router.go(target);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const App()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sign in to continue'), findsOneWidget);
    expect(
      router.routeInformationProvider.value.uri.queryParameters['from'],
      target,
    );
    await container
        .read(authViewModelProvider.notifier)
        .signIn('test@example.com', 'secret');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, target);
    expect(find.text('This feature is not connected yet.'), findsOneWidget);
    await container.read(authViewModelProvider.notifier).signOut();
    await tester.pumpAndSettle();
    expect(find.text('Sign in to continue'), findsOneWidget);
    expect(find.text('This feature is not connected yet.'), findsNothing);
  });

  testWidgets('dashboard adapts to small phones, tablets and large text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final repo = FakeAuthRepository()
      ..session = Session(
        accessToken: 'token',
        email: 'test@example.com',
        role: AppConfig.allowedRoles.first,
      );
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    for (final size in [const Size(320, 568), const Size(1024, 768)]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const App()),
      );
      await tester.pumpAndSettle();
      expect(find.text(AppConfig.title), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
