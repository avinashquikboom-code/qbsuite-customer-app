import '../../../core/storage/session_store.dart';
import '../domain/auth_repository.dart';
import '../domain/session.dart';
import 'auth_service.dart';

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._service, this._store);
  final AuthService _service;
  final SessionStore _store;
  @override
  Future<Session?> restore() => _store.restore();
  @override
  Future<Session> signIn(String email, String password) async {
    final session = await _service.signIn(email, password);
    await _store.save(session);
    return session;
  }
  @override
  Future<void> signOut() => _store.clear();
}
