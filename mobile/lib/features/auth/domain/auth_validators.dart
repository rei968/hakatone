/// Перевірки полів форми входу (docs/design/02-auth.html, «Валідація і тексти помилок»).
/// Повертають текст помилки або `null`, якщо все гаразд.
abstract final class AuthValidators {
  /// Межі пароля, як на бекенді (`password_too_short` / `password_too_long`).
  static const minPasswordLength = 6;
  static const maxPasswordLength = 128;

  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static String? email(String value) {
    final email = value.trim();
    if (email.isEmpty) return 'Введіть email.';
    if (!_emailPattern.hasMatch(email)) return 'Email має виглядати як name@example.com.';
    return null;
  }

  /// Довжину перевіряємо лише під час реєстрації: на вході це справа сервера.
  static String? password(String value, {required bool forRegistration}) {
    if (value.isEmpty) return 'Введіть пароль.';
    if (forRegistration && value.length < minPasswordLength) {
      return 'Пароль має містити щонайменше $minPasswordLength символів.';
    }
    if (forRegistration && value.length > maxPasswordLength) {
      return 'Пароль має бути не довшим за $maxPasswordLength символів.';
    }
    return null;
  }
}
