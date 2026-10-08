/// Перевірки полів форми входу (docs/design/02-auth.html, «Валідація і тексти помилок»).
/// Повертають текст помилки або `null`, якщо все гаразд.
abstract final class AuthValidators {
  /// У контракті довжини немає, беремо 6 як у прикладі `secret123` (відкрите питання до бекенду).
  static const minPasswordLength = 6;

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
    return null;
  }
}
