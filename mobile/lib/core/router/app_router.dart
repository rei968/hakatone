import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/presentation/auth_screen.dart';
import '../../features/hero/presentation/hero_screen.dart';
import '../../features/meta/presentation/meta_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../widgets/not_found_screen.dart';
import 'app_routes.dart';

/// Кореневий навігатор: через нього діалоги (наприклад, оновлення застосунку)
/// показуються поверх будь-якого екрана.
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Потік екранів (docs/design/02-auth.html, «Потік екранів»): поки сесія
/// невідома — splash, без сесії — вхід або реєстрація, із сесією — мета.
final appRouterProvider = Provider<GoRouter>((ref) {
  final authStatus = ValueNotifier<AuthStatus>(ref.read(authControllerProvider).status);
  ref.listen(authControllerProvider, (_, next) => authStatus.value = next.status);

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    refreshListenable: authStatus,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final onSplash = location == AppRoutes.splash;
      final onAuth = location == AppRoutes.login || location == AppRoutes.register;
      return switch (authStatus.value) {
        AuthStatus.unknown => onSplash ? null : AppRoutes.splash,
        AuthStatus.signedOut => onAuth ? null : AppRoutes.login,
        AuthStatus.signedIn => (onSplash || onAuth) ? AppRoutes.meta : null,
      };
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => AuthScreen(mode: AuthMode.login, draft: _draft(state)),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => AuthScreen(mode: AuthMode.register, draft: _draft(state)),
      ),
      GoRoute(
        path: AppRoutes.meta,
        builder: (context, state) => const MetaScreen(),
      ),
      GoRoute(
        path: AppRoutes.heroPattern,
        builder: (context, state) {
          final heroId = int.tryParse(state.pathParameters['heroId'] ?? '');
          return heroId == null ? const NotFoundScreen() : HeroScreen(heroId: heroId);
        },
      ),
    ],
    errorBuilder: (context, state) => const NotFoundScreen(),
  );

  ref.onDispose(() {
    authStatus.dispose();
    router.dispose();
  });
  return router;
});

/// Email і пароль переносяться між входом і реєстрацією, щоб не вводити знову.
AuthDraft? _draft(GoRouterState state) {
  final extra = state.extra;
  return extra is AuthDraft ? extra : null;
}
