import 'dart:convert';

import '../../../core/storage/app_storage.dart';
import '../domain/steam_session.dart';

/// Де лежить збережена сесія.
abstract interface class SessionStore {
  Future<SteamSession?> read();
  Future<void> write(SteamSession session);
  Future<void> clear();
}

/// Сесія в окремому сховищі (бокс Hive `session`): переживає перезапуск,
/// тож профіль відкривається одразу, навіть без мережі.
class KeyValueSessionStore implements SessionStore {
  const KeyValueSessionStore(this._store);

  static const _key = 'steam_session';

  final KeyValueStore _store;

  @override
  Future<SteamSession?> read() async {
    final raw = _store.read(_key);
    if (raw == null) return null;
    try {
      return SteamSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      await clear();
      return null;
    }
  }

  @override
  Future<void> write(SteamSession session) => _store.write(_key, jsonEncode(session.toJson()));

  @override
  Future<void> clear() => _store.delete(_key);
}
