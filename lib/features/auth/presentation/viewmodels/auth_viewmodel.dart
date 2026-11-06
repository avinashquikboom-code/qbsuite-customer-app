import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/storage/session_store.dart';
import '../../domain/session.dart';
import '../providers/auth_providers.dart';

final authViewModelProvider = AsyncNotifierProvider<AuthViewModel, Session?>(
  AuthViewModel.new,
);

class AuthViewModel extends AsyncNotifier<Session?> {
  bool _busy = false;
  @override
  Future<Session?> build() async {
    final store = ref.watch(sessionStoreProvider);
    final subscription = store.changes.listen((session) {
      if (ref.mounted) state = AsyncData(session);
    });
    ref.onDispose(subscription.cancel);
    return ref.watch(authRepositoryProvider).restore();
  }

  Future<void> signIn(String email, String password) async {
    if (_busy || state.isLoading) return;
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email.trim()) ||
        password.isEmpty) {
      state = AsyncError(
        const AppFailure('Enter a valid email and password.'),
        StackTrace.current,
      );
      return;
    }
    _busy = true;
    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).signIn(email, password),
    );
    if (ref.mounted) state = result;
    _busy = false;
  }

  Future<void> signOut() async {
    if (_busy) return;
    _busy = true;
    state = const AsyncLoading();
    final result = await AsyncValue.guard<Session?>(() async {
      await ref.read(authRepositoryProvider).signOut();
      return null;
    });
    if (ref.mounted) state = result;
    _busy = false;
  }
}
