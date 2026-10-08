import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/presentation/steam_login_screen.dart';
import '../../features/hero/presentation/hero_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/meta/presentation/meta_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../widgets/app_shell.dart';
import '../widgets/not_found_screen.dart';
import 'app_routes.dart';

/// Кореневий навігатор: через нього діалоги (наприклад, оновлення застосунку)
/// показуються поверх будь-якого екрана, а картка героя — поверх нижнього меню.
final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Splash, поки сесія невідома. Новий гравець бачить «Увійти через Steam» один раз,
/// далі — три вкладки. Мета й герої відкриті й гостям, профіль просить увійти.
final appRouterProvider = Provider<GoRouter>((ref) {
  final auth = ValueNotifier<AuthState>(ref.read(authControllerProvider));
  ref.listen(authControllerProvider, (_, next) => auth.value = next);

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    refreshListenable: auth,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final onSplash = location == AppRoutes.splash;
      final onLogin = location == AppRoutes.login;
      final current = auth.value;
      return switch (current.status) {
        AuthStatus.unknown => onSplash ? null : AppRoutes.splash,
        AuthStatus.guest when onSplash => current.welcomed ? AppRoutes.home : AppRoutes.login,
        AuthStatus.signedIn when onSplash => AppRoutes.home,
        AuthStatus.signedIn when onLogin => AppRoutes.profile,
        _ => null,
      };
    },
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (context, state) => const SplashScreen()),
      GoRoute(
        path: AppRoutes.login,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SteamLoginScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.home, builder: (context, state) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.meta, builder: (context, state) => const MetaScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.profile, builder: (context, state) => const ProfileScreen()),
          ]),
        ],
      ),
      // Картка героя на весь екран, поверх нижнього меню.
      GoRoute(
        path: AppRoutes.heroPattern,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final heroId = int.tryParse(state.pathParameters['heroId'] ?? '');
          return heroId == null ? const NotFoundScreen() : HeroScreen(heroId: heroId);
        },
      ),
    ],
    errorBuilder: (context, state) => const NotFoundScreen(),
  );

  ref.onDispose(() {
    auth.dispose();
    router.dispose();
  });
  return router;
});
