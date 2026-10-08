import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/app_storage.dart';
import '../../profile/application/profile_providers.dart';
import '../data/session_store.dart';
import '../data/steam_openid.dart';
import '../domain/steam_session.dart';

final sessionStoreProvider = Provider<SessionStore>(
  (ref) => KeyValueSessionStore(ref.watch(appStorageProvider).session),
);

final steamOpenIdProvider = Provider<SteamOpenId>((ref) => SteamOpenId(ref.watch(externalDioProvider)));

enum AuthStatus {
  /// Ще читаємо збережену сесію — показується splash.
  unknown,

  /// Гість: мета й герої доступні, профіль пропонує увійти через Steam.
  guest,
  signedIn,
}

@immutable
class AuthState {
  const AuthState._(this.status, this.session, {this.welcomed = true});

  const AuthState.unknown() : this._(AuthStatus.unknown, null);
  const AuthState.guest({bool welcomed = true}) : this._(AuthStatus.guest, null, welcomed: welcomed);
  const AuthState.signedIn(SteamSession session) : this._(AuthStatus.signedIn, session);

  final AuthStatus status;
  final SteamSession? session;

  /// Екран «Увійти через Steam / Продовжити без входу» вже бачили (показується раз).
  final bool welcomed;
}

/// Сесія гравця. Вхід необов’язковий: без нього не працює лише профіль.
class AuthController extends Notifier<AuthState> {
  static const _welcomedKey = 'welcomed';

  @override
  AuthState build() {
    _restore();
    return const AuthState.unknown();
  }

  Future<void> _restore() async {
    final session = await ref.read(sessionStoreProvider).read();
    final welcomed = ref.read(appStorageProvider).session.read(_welcomedKey) != null;
    state = session == null ? AuthState.guest(welcomed: welcomed) : AuthState.signedIn(session);
  }

  /// Steam ID уже підтверджено (Steam OpenID) або введено вручну. Ім’я й аватар
  /// підтягуються з OpenDota; без мережі вхід однаково відбувається.
  Future<void> signIn(String steamId64) async {
    var session = SteamSession(steamId64: steamId64);
    try {
      final profile = await ref
          .read(profileRepositoryProvider)
          .fetchProfile(session.accountId)
          .timeout(const Duration(seconds: 8));
      session = session.copyWith(personaName: profile.name, avatarUrl: profile.avatarUrl);
    } catch (_) {
      // Профіль підтягнеться пізніше на екрані профілю.
    }
    await ref.read(sessionStoreProvider).write(session);
    await _markWelcomed();
    state = AuthState.signedIn(session);
  }

  /// «Продовжити без входу» на першому екрані.
  Future<void> continueAsGuest() async {
    await _markWelcomed();
    state = const AuthState.guest();
  }

  Future<void> signOut() async {
    await ref.read(sessionStoreProvider).clear();
    state = const AuthState.guest();
  }

  Future<void> _markWelcomed() => ref.read(appStorageProvider).session.write(_welcomedKey, '1');
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);
