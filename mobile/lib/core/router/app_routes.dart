/// Шляхи застосунку. Рядки маршрутів пишуться лише тут.
abstract final class AppRoutes {
  static const splash = '/splash';

  /// «Увійти через Steam»: першим екраном для нового гравця і з профілю.
  static const login = '/login';

  // Вкладки нижнього меню.
  static const home = '/';
  static const meta = '/meta';
  static const profile = '/profile';

  static const heroPattern = '/hero/:heroId';
  static String hero(int heroId) => '/hero/$heroId';
}
