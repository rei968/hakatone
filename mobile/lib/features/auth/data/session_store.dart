import 'dart:convert';

import '../../../core/storage/app_storage.dart';
import '../domain/auth_session.dart';

/// Де лежить збережена сесія.
abstract interface class SessionStore {
  Future<AuthSession?> read();
  Future<void> write(AuthSession session);
  Future<void> clear();
}

/// Сесія в окремому сховищі (бокс Hive `session`): переживає перезапуск,
/// тож гравець із токеном одразу потрапляє на мету, навіть без мережі.
class KeyValueSessionStore implements SessionStore {
  const KeyValueSessionStore(this._store);

  static const _key = 'session';

  final KeyValueStore _store;

  @override
  Future<AuthSession?> read() async {
    final raw = _store.read(_key);
    if (raw == null) return null;
    try {
      return AuthSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(AuthSession session) => _store.write(_key, jsonEncode(session.toJson()));

  @override
  Future<void> clear() => _store.delete(_key);
}
