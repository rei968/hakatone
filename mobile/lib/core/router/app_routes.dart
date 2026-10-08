/// Шляхи застосунку (docs/design/02-auth.html, «Потік екранів»).
/// Рядки маршрутів пишуться лише тут.
abstract final class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const register = '/register';

  /// Головний екран — мета героїв.
  static const meta = '/';

  static const heroPattern = '/hero/:heroId';
  static String hero(int heroId) => '/hero/$heroId';
}
