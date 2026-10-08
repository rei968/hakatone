import '../domain/auth_session.dart';

/// `POST /api/auth/login` і `POST /api/auth/register` з `docs/openapi.yaml`.
abstract interface class AuthRepository {
  /// Кидає [AuthException].
  Future<AuthSession> login({required String email, required String password});

  /// Кидає [AuthException]. Після успіху гравець одразу увійшов (201 + токен).
  Future<AuthSession> register({required String email, required String password});
}

/// Відповідає так само, як макет у docs/design/02-auth.html: демо-акаунт
/// з `openapi.yaml` входить, інший пароль дає 401, повторна реєстрація — 400.
class MockAuthRepository implements AuthRepository {
  MockAuthRepository({this.latency = const Duration(milliseconds: 700)});

  static const demoEmail = 'player@example.com';
  static const demoPassword = 'secret123';

  final Duration latency;
  final Map<String, String> _accounts = {demoEmail: demoPassword};

  @override
  Future<AuthSession> login({required String email, required String password}) async {
    await Future<void>.delayed(latency);
    if (_accounts[email] != password) {
      throw const AuthException(AuthFailure.invalidCredentials);
    }
    return _session(email);
  }

  @override
  Future<AuthSession> register({required String email, required String password}) async {
    await Future<void>.delayed(latency);
    if (_accounts.containsKey(email)) {
      throw const AuthException(AuthFailure.emailTaken);
    }
    _accounts[email] = password;
    return _session(email);
  }

  AuthSession _session(String email) => AuthSession(
        token: 'mock-token-${email.hashCode.abs()}',
        user: AuthUser(id: 'usr_${email.hashCode.abs()}', email: email),
      );
}
