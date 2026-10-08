import 'dart:convert';
import 'dart:io';

import 'package:dota_builds/core/dota/rank.dart';
import 'package:dota_builds/core/network/api_client.dart';
import 'package:dota_builds/core/storage/app_storage.dart';
import 'package:dota_builds/features/auth/application/auth_controller.dart';
import 'package:dota_builds/features/auth/data/session_store.dart';
import 'package:dota_builds/features/auth/domain/steam_session.dart';
import 'package:dota_builds/features/profile/application/profile_providers.dart';
import 'package:dota_builds/features/hero/application/hero_providers.dart';
import 'package:dota_builds/features/hero/data/hero_repository.dart';
import 'package:dota_builds/features/hero/domain/hero_details.dart';
import 'package:dota_builds/features/meta/application/meta_controller.dart';
import 'package:dota_builds/features/meta/data/meta_repository.dart';
import 'package:dota_builds/features/meta/domain/meta_report.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import 'test_app.dart';

MetaReport seedMeta() =>
    MetaReport.fromJson(jsonDecode(File('assets/mocks/meta.json').readAsStringSync()) as Map<String, dynamic>);

/// Мета, яку можна «вимкнути»: [failure] != null — запит падає з цією помилкою.
class SwitchableMeta implements MetaRepository {
  Object? failure;
  int calls = 0;

  @override
  Future<MetaReport> fetchMeta({Rank rank = Rank.all}) async {
    calls++;
    if (failure != null) throw failure!;
    return seedMeta();
  }
}

class SwitchableHeroes implements HeroRepository {
  final _inner = MockHeroRepository(bundle: FileAssetBundle(), latency: Duration.zero);
  Object? failure;

  @override
  Future<HeroDetails> fetchHero(int id, {Rank rank = Rank.all}) async {
    if (failure != null) throw failure!;
    return _inner.fetchHero(id);
  }
}

const offline = ApiException(ApiFailure.network);

/// Чекає, поки фонове оновлення мети завершиться.
Future<MetaFeed> settled(ProviderContainer container) async {
  var feed = await container.read(metaControllerProvider.future);
  for (var i = 0; i < 50 && container.read(metaControllerProvider).value!.refreshing; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  feed = container.read(metaControllerProvider).value!;
  return feed;
}

void main() {
  group('сховище', () {
    test('JsonCache: запис, читання, пошкоджений запис — як відсутній', () async {
      final store = MemoryKeyValueStore();
      final cache = JsonCache(store);
      final at = DateTime.utc(2026, 10, 8, 9, 12);

      await cache.write('meta', {'patch': '7.37d'}, at);
      expect(cache.read('meta')?.data['patch'], '7.37d');
      expect(cache.read('meta')?.savedAt, at);

      await store.write('broken', '{not json');
      expect(cache.read('broken'), isNull);
      expect(cache.read('missing'), isNull);
    });

    test('сесія переживає збереження, пошкоджена — стирається', () async {
      final store = MemoryKeyValueStore();
      final sessions = KeyValueSessionStore(store);
      const session = SteamSession(steamId64: '76561198047011640', personaName: 'dima');

      await sessions.write(session);
      expect((await sessions.read())?.accountId, 86745912);

      await store.write('steam_session', 'oops');
      expect(await sessions.read(), isNull);
      expect(store.read('steam_session'), isNull);
    });

    test('HiveKeyValueStore працює на справжньому Hive', () async {
      final dir = Directory.systemTemp.createTempSync('mangodota_hive');
      addTearDown(() async {
        await Hive.close();
        dir.deleteSync(recursive: true);
      });
      Hive.init(dir.path);
      final store = HiveKeyValueStore(await Hive.openBox<String>('api_cache'));

      await store.write('meta', 'value');
      expect(store.read('meta'), 'value');
      await store.delete('meta');
      expect(store.read('meta'), isNull);
    });
  });

  group('мета з кешем', () {
    late SwitchableMeta repo;
    late AppStorage storage;

    ProviderContainer newContainer() {
      final container = ProviderContainer(
        retry: (retryCount, error) => null,
        overrides: [
          appStorageProvider.overrideWithValue(storage),
          metaRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    setUp(() {
      repo = SwitchableMeta();
      storage = AppStorage.memory();
    });

    test('перший запуск: дані з мережі зберігаються в кеш', () async {
      final feed = await settled(newContainer());
      expect(feed.fromCache, isFalse);
      expect(feed.error, isNull);
      expect(JsonCache(storage.cache).read(MetaController.cacheKey), isNotNull);
    });

    test('є кеш, немає мережі: показуємо кеш і позначку офлайн', () async {
      await settled(newContainer());
      repo.failure = offline;

      final container = newContainer();
      final first = await container.read(metaControllerProvider.future);
      expect(first.fromCache, isTrue, reason: 'кеш одразу, без скелетона');
      expect(first.refreshing, isTrue);

      final feed = await settled(container);
      expect(feed.offline, isTrue);
      expect(feed.report.heroes, hasLength(3));
    });

    test('є кеш, мережа є: кеш змінюється свіжими даними', () async {
      await settled(newContainer());
      final feed = await settled(newContainer());
      expect(feed.fromCache, isFalse);
      expect(repo.calls, 2);
    });

    test('ні кешу, ні мережі — помилка', () async {
      repo.failure = offline;
      final container = newContainer();
      await expectLater(container.read(metaControllerProvider.future), throwsA(offline));
    });

    test('оновлення без мережі лишає дані й додає помилку', () async {
      final container = newContainer();
      await settled(container);
      repo.failure = offline;
      await container.read(metaControllerProvider.notifier).refresh();
      final feed = container.read(metaControllerProvider).value!;
      expect(feed.offline, isTrue);
      expect(feed.refreshing, isFalse);
    });
  });

  test('картка героя без мережі береться з кешу', () async {
    final heroes = SwitchableHeroes();
    final container = ProviderContainer(
      retry: (retryCount, error) => null,
      overrides: [
        appStorageProvider.overrideWithValue(AppStorage.memory()),
        heroRepositoryProvider.overrideWithValue(heroes),
      ],
    );
    addTearDown(container.dispose);
    final keepAlive = container.listen(heroCardProvider(14), (previous, next) {});
    addTearDown(keepAlive.close);

    final fresh = await container.read(heroCardProvider(14).future);
    expect(fresh.fromCache, isFalse);

    heroes.failure = offline;
    container.invalidate(heroCardProvider(14));
    final cached = await container.read(heroCardProvider(14).future);
    expect(cached.fromCache, isTrue);
    expect(cached.details.hero.name, 'Pudge');

    await expectLater(container.read(heroCardProvider(8).future), throwsA(offline), reason: 'Juggernaut ще не кешувався');
  });

  test('сесія відновлюється після перезапуску', () async {
    final storage = AppStorage.memory();
    ProviderContainer start() {
      final c = ProviderContainer(overrides: [
        appStorageProvider.overrideWithValue(storage),
        profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    await start().read(authControllerProvider.notifier).signIn('76561198047011640');

    final relaunched = start();
    relaunched.read(authControllerProvider);
    await Future<void>.delayed(Duration.zero);
    expect(relaunched.read(authControllerProvider).status, AuthStatus.signedIn);
  });
}
