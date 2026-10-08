import 'package:dota_builds/features/auth/application/auth_controller.dart';
import 'package:dota_builds/features/auth/domain/auth_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthValidators.email', () {
    test('порожній', () => expect(AuthValidators.email('  '), 'Введіть email.'));
    test('без домену', () => expect(AuthValidators.email('player@'), isNotNull));
    test('з пробілами по краях — норм', () => expect(AuthValidators.email(' a@b.co '), isNull));
  });

  group('AuthValidators.password', () {
    test('порожній', () => expect(AuthValidators.password('', forRegistration: false), 'Введіть пароль.'));
    test('короткий на вході не перевіряється',
        () => expect(AuthValidators.password('123', forRegistration: false), isNull));
    test('короткий у реєстрації', () => expect(AuthValidators.password('123', forRegistration: true), isNotNull));
    test('6 символів у реєстрації — норм', () => expect(AuthValidators.password('123456', forRegistration: true), isNull));
  });

  test('email нормалізується перед надсиланням', () {
    expect(AuthController.normalizeEmail('  Player@Example.COM '), 'player@example.com');
  });
}
