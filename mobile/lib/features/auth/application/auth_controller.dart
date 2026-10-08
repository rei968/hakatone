import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../data/api_auth_repository.dart';
import '../data/auth_repository.dart';
import '../data/session_store.dart';
import '../domain/auth_session.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AppConfig.mockAuth ? MockAuthRepository() : ApiAuthRepository(ref.watch(dioProvider)),
);

final sessionStoreProvider = Provider<SessionStore>((ref) => InMemorySessionStore());

enum AuthStatus {
  /// Ще читаємо збережену сесію — показується splash.
  unknown,
  signedOut,
  signedIn,
}

@immutable
class AuthState {
  const AuthState._(this.status, this.session);

  const AuthState.unknown() : this._(AuthStatus.unknown, null);
  const AuthState.signedOut() : this._(AuthStatus.signedOut, null);
  const AuthState.signedIn(AuthSession session) : this._(AuthStatus.signedIn, session);

  final AuthStatus status;
  final AuthSession? session;
}

/// Сесія гравця. Стан форми (надсилання, помилки) тримає сам екран входу,
/// а тут лише результат: увійшов чи ні.
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    _restore();
    return const AuthState.unknown();
  }

  Future<void> _restore() async {
    final session = await ref.read(sessionStoreProvider).read();
    state = session == null ? const AuthState.signedOut() : AuthState.signedIn(session);
  }

  /// Кидає [AuthException].
  Future<void> signIn({required String email, required String password}) async {
    final session = await ref
        .read(authRepositoryProvider)
        .login(email: normalizeEmail(email), password: password);
    await _start(session);
  }

  /// Кидає [AuthException].
  Future<void> signUp({required String email, required String password}) async {
    final session = await ref
        .read(authRepositoryProvider)
        .register(email: normalizeEmail(email), password: password);
    await _start(session);
  }

  Future<void> signOut() async {
    await ref.read(sessionStoreProvider).clear();
    state = const AuthState.signedOut();
  }

  Future<void> _start(AuthSession session) async {
    await ref.read(sessionStoreProvider).write(session);
    state = AuthState.signedIn(session);
  }

  /// Email без пробілів по краях і в нижньому регістрі; пароль не чіпаємо.
  static String normalizeEmail(String email) => email.trim().toLowerCase();
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);
