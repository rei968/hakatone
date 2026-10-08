/// Налаштування збірки.
///
/// Єдине джерело значень — `config/app.json`. Dart отримує їх через
/// `flutter run --dart-define-from-file=config/app.json`, а Gradle читає
/// той самий файл. Тут значення не дублюються.
abstract final class AppConfig {
  static const _appName = String.fromEnvironment('APP_NAME');
  static const applicationId = String.fromEnvironment('APPLICATION_ID');

  /// Адреса бекенду команди (`docs/openapi.yaml`).
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Мета й герої з `assets/mocks` замість бекенду. Профіль гравця
  /// завжди береться з OpenDota.
  static const useMocks = bool.fromEnvironment('USE_MOCKS', defaultValue: true);

  /// Якщо запустили без `--dart-define-from-file`, назва це покаже прямо
  /// на екрані, але запуск не зламається.
  static String get appName => _appName.isEmpty ? 'APP_NAME не задано' : _appName;
}
