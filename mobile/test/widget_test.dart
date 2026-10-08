import 'package:dota_builds/features/auth/data/auth_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

Future<void> signIn(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('auth-email')), ' Player@Example.com ');
  await tester.enterText(find.byKey(const Key('auth-password')), MockAuthRepository.demoPassword);
  await tester.tap(find.byKey(const Key('auth-submit')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('splash → вхід → мета → картка героя → вихід', (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();
    expect(find.text('Вхід'), findsOneWidget);

    await signIn(tester);
    expect(find.text('Мета героїв'), findsOneWidget);
    expect(find.text('S-тір'), findsOneWidget);
    expect(find.text('A-тір'), findsOneWidget);
    expect(find.text('53,4%'), findsOneWidget);
    expect(find.text('3 герої'), findsOneWidget);

    await tester.tap(find.text('Pudge'));
    await tester.pumpAndSettle();
    expect(find.text('AI-білд від Claude'), findsOneWidget);
    expect(find.text('Порядок прокачки'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Профіль: ${MockAuthRepository.demoEmail}'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Вийти'));
    await tester.pumpAndSettle();
    expect(find.text('Вхід'), findsOneWidget);
  });

  testWidgets('картка героя на 320 dp без переповнень (TEST_PLAN)', (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'екран входу');
    await signIn(tester);
    expect(tester.takeException(), isNull, reason: 'екран мети');

    for (final name in ['Pudge', 'Juggernaut', 'Invoker']) {
      await tester.scrollUntilVisible(find.text(name), 200);
      await tester.tap(find.text(name));
      await tester.pumpAndSettle();
      expect(find.text('AI-білд від Claude'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Історія'), 300);
      expect(find.text('Характеристики'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('у тірі A герої йдуть за вінрейтом', (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();
    await signIn(tester);

    final jugg = tester.getTopLeft(find.text('Juggernaut')).dy;
    final invoker = tester.getTopLeft(find.text('Invoker')).dy;
    expect(jugg, lessThan(invoker));
  });

  testWidgets('невірний пароль показує банер і лишає на вході', (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('auth-email')), MockAuthRepository.demoEmail);
    await tester.enterText(find.byKey(const Key('auth-password')), 'wrong-pass');
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Невірний email або пароль'), findsOneWidget);
    expect(find.text('Вхід'), findsOneWidget);
  });

  testWidgets('порожня форма показує помилки полів', (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pump();

    expect(find.text('Введіть email.'), findsOneWidget);
    expect(find.text('Введіть пароль.'), findsOneWidget);
  });

  testWidgets('реєстрація з зайнятим email пропонує увійти, email переноситься', (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Зареєструватися'));
    await tester.pumpAndSettle();
    expect(find.text('Реєстрація'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('auth-email')), MockAuthRepository.demoEmail);
    await tester.enterText(find.byKey(const Key('auth-password')), 'qwerty123');
    await tester.tap(find.byKey(const Key('auth-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Акаунт з цим email уже існує.'), findsOneWidget);

    await tester.tap(find.text('Увійти з цим email'));
    await tester.pumpAndSettle();
    expect(find.text('Вхід'), findsOneWidget);
    final email = tester.widget<TextField>(find.byKey(const Key('auth-email')));
    expect(email.controller!.text, MockAuthRepository.demoEmail);
  });
}
