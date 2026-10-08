import 'dart:convert';
import 'dart:io';

import 'package:dota_builds/core/network/api_client.dart';
import 'package:dota_builds/core/dota/rank.dart';
import 'package:dota_builds/core/storage/app_storage.dart';
import 'package:dota_builds/features/meta/application/meta_controller.dart';
import 'package:dota_builds/features/meta/data/meta_repository.dart';
import 'package:dota_builds/features/meta/domain/meta_report.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

class _OfflineMeta implements MetaRepository {
  @override
  Future<MetaReport> fetchMeta({Rank rank = Rank.all}) async => throw const ApiException(ApiFailure.network);
}

Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('перший запуск: Steam або гість → головна → мета → картка героя', (tester) async {
    await tester.pumpWidget(testApp());
    await tester.pumpAndSettle();
    expect(find.text('Увійти через Steam'), findsOneWidget);

    await tester.tap(find.byKey(const Key('continue-as-guest')));
    await tester.pumpAndSettle();
    expect(find.text('Тиждень у меті'), findsOneWidget);
    expect(find.text('Найкращий герой'), findsOneWidget);
    expect(find.text('Найпопулярніші цього тижня'), findsOneWidget);

    await openTab(tester, 'Мета');
    expect(find.text('Мета героїв'), findsOneWidget);
    expect(find.text('53,4%'), findsOneWidget);
    expect(find.text('Герой · 3'), findsOneWidget);

    await tester.tap(find.text('Pudge'));
    await tester.pumpAndSettle();
    expect(find.text('AI-білд від Gemini'), findsOneWidget);
    expect(find.text('Скілбілд · 1–18 рівень'), findsOneWidget);
    expect(find.text('Таланти'), findsOneWidget);
    expect(find.text('Ключові предмети · середній таймінг'), findsOneWidget);
    expect(find.text('9:35'), findsOneWidget, reason: 'Phase Boots, 575 с');
    expect(find.text('Ситуативні предмети'), findsOneWidget);
    expect(find.text('Force Staff'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Мета героїв'), findsOneWidget);
  });

  testWidgets('пошук і фільтр у меті', (tester) async {
    await tester.pumpWidget(testApp(storage: welcomedStorage()));
    await tester.pumpAndSettle();
    await openTab(tester, 'Мета');

    await tester.enterText(find.byKey(const Key('meta-search')), 'jugg');
    await tester.pumpAndSettle();
    expect(find.text('Juggernaut'), findsOneWidget);
    expect(find.text('Pudge'), findsNothing);

    await tester.enterText(find.byKey(const Key('meta-search')), '');
    await tester.tap(find.text('Універсал'));
    await tester.pumpAndSettle();
    expect(find.text('Invoker'), findsOneWidget);
    expect(find.text('Juggernaut'), findsNothing);
  });

  testWidgets('картки героїв на 320 dp без переповнень (TEST_PLAN)', (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(testApp(storage: welcomedStorage()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'головна');
    await openTab(tester, 'Мета');
    expect(tester.takeException(), isNull, reason: 'мета');

    for (final name in ['Pudge', 'Juggernaut', 'Invoker']) {
      await tester.ensureVisible(find.text(name));
      await tester.pumpAndSettle();
      await tester.tap(find.text(name));
      await tester.pumpAndSettle();
      expect(find.text('AI-білд від Gemini'), findsOneWidget);
      await tester.dragUntilVisible(find.text('Історія'), find.byType(ListView).first, const Offset(0, -300));
      expect(tester.takeException(), isNull, reason: name);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }

    await openTab(tester, 'Профіль');
    expect(tester.takeException(), isNull, reason: 'профіль гостя');
  });

  testWidgets('офлайн: мета з кешу з банером, а не помилка', (tester) async {
    final storage = welcomedStorage();
    final report = MetaReport.fromJson(
      jsonDecode(File('assets/mocks/meta.json').readAsStringSync()) as Map<String, dynamic>,
    );
    await JsonCache(storage.cache).write(MetaController.cacheKey, report.toJson(), DateTime(2026, 10, 8, 9, 12));

    await tester.pumpWidget(testApp(meta: _OfflineMeta(), storage: storage));
    await tester.pumpAndSettle();

    expect(find.text('Тиждень у меті'), findsOneWidget);
    expect(find.textContaining('Немає інтернету'), findsOneWidget);
    expect(find.textContaining('8 жов, 09:12'), findsWidgets);
  });

  testWidgets('профіль: гість входить за Steam ID і бачить пул героїв та історію', (tester) async {
    await tester.pumpWidget(testApp(storage: welcomedStorage()));
    await tester.pumpAndSettle();
    await openTab(tester, 'Профіль');
    expect(find.text('Увійти через Steam'), findsOneWidget);

    await tester.tap(find.byKey(const Key('steam-id-sign-in')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('steam-id-field')), 'https://www.opendota.com/players/86745912');
    await tester.tap(find.byKey(const Key('steam-id-submit')));
    await tester.pumpAndSettle();

    expect(find.text('dima_kakatone'), findsOneWidget);
    expect(find.text('Divine 3'), findsOneWidget);
    expect(find.textContaining('Пул героїв'), findsOneWidget);
    expect(find.text('67%'), findsOneWidget, reason: 'вінрейт 2–1');
    expect(find.text('KDA'), findsOneWidget);

    await tester.dragUntilVisible(find.byKey(const Key('match-history')), find.byType(ListView).first, const Offset(0, -200));
    await tester.tap(find.byKey(const Key('match-history')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Перемога'), findsWidgets);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Вийти'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sign-out')));
    await tester.pumpAndSettle();
    expect(find.text('Увійти через Steam'), findsOneWidget);
  });

  test('сховище для тестів без першого екрана', () {
    expect(welcomedStorage().session.read('welcomed'), '1');
    expect(AppStorage.memory().session.read('welcomed'), isNull);
  });
}
