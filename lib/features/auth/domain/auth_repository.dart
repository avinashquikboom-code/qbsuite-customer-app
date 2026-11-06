import 'session.dart';

abstract interface class AuthRepository {
  Future<Session?> restore();
  Future<Session> signIn(String email, String password);
  Future<void> signOut();
}
