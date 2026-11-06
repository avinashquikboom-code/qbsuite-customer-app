import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../features/auth/domain/session.dart';

final sessionStoreProvider = Provider<SessionStore>((ref) {
  final store = SessionStore(const FlutterSecureStorage());
  ref.onDispose(store.dispose);
  return store;
});

class SessionStore {
  SessionStore(this._storage);
  final FlutterSecureStorage _storage;
  final _events = StreamController<Session?>.broadcast();
  static const _key = 'qb_session_v1';
  Stream<Session?> get changes => _events.stream;
  Session? current;
  Future<Session?> restore() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    try {
      return current = Session.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
    } on FormatException { await clear(); return null; }
      on TypeError { await clear(); return null; }
  }
  Future<void> save(Session session) async {
    await _storage.write(key: _key, value: jsonEncode(session.toJson()));
    current = session;
    _events.add(session);
  }
  Future<void> clear() async {
    // Clear memory even if the keychain fails; surface persistence failures.
    current = null;
    _events.add(null);
    await _storage.delete(key: _key);
  }
  void dispose() { unawaited(_events.close()); }
}
