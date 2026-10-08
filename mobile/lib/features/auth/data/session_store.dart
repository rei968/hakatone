import '../domain/auth_session.dart';

/// Де лежить збережена сесія. Hive-версія з’явиться в пункті 8 (кеш у Hive).
abstract interface class SessionStore {
  Future<AuthSession?> read();
  Future<void> write(AuthSession session);
  Future<void> clear();
}

/// Сесія живе до закриття застосунку.
class InMemorySessionStore implements SessionStore {
  AuthSession? _session;

  @override
  Future<AuthSession?> read() async => _session;

  @override
  Future<void> write(AuthSession session) async => _session = session;

  @override
  Future<void> clear() async => _session = null;
}
