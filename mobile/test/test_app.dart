import 'dart:io';

import 'package:dota_builds/core/dota/dota_assets.dart';
import 'package:dota_builds/core/router/app_router.dart';
import 'package:dota_builds/core/storage/app_storage.dart';
import 'package:dota_builds/core/theme/app_colors.dart';
import 'package:dota_builds/core/theme/app_metrics.dart';
import 'package:dota_builds/features/hero/application/hero_providers.dart';
import 'package:dota_builds/features/hero/data/hero_repository.dart';
import 'package:dota_builds/features/meta/application/meta_controller.dart';
import 'package:dota_builds/features/meta/data/meta_repository.dart';
import 'package:dota_builds/features/profile/application/profile_providers.dart';
import 'package:dota_builds/features/profile/data/profile_repository.dart';
import 'package:dota_builds/features/profile/domain/player.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Читає assets з диска синхронно. `rootBundle` у віджет-тестах робить
/// справжній ввід-вивід, який не встигає завершитись у фейковому часі.
class FileAssetBundle extends AssetBundle {
  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(File(key).readAsBytesSync());

  @override
  Future<T> loadStructuredData<T>(String key, Future<T> Function(String value) parser) async =>
      parser(await loadString(key));
}

/// OpenDota без мережі: гравець dima, Divine 3, три матчі.
class FakeProfileRepository implements ProfileRepository {
  @override
  Future<PlayerProfile> fetchProfile(int accountId) async =>
      PlayerProfile(accountId: accountId, name: 'dima_kakatone', rankTier: 73, wins: 2500, losses: 2312);

  @override
  Future<List<PlayerMatch>> fetchMatches(int accountId, ProfilePeriod period) async => [
        for (final (id, hero, won) in [(1, 42, true), (2, 42, true), (3, 8, false)])
          PlayerMatch(
            matchId: id,
            heroId: hero,
            won: won,
            kills: 10,
            deaths: 4,
            assists: 8,
            duration: const Duration(minutes: 38),
            startTime: DateTime.now().subtract(Duration(hours: id * 2)),
            gpm: 550,
            xpm: 620,
          ),
      ];
}

/// Сховище, у якому вже пройдено перший екран «Увійти через Steam».
AppStorage welcomedStorage() {
  final storage = AppStorage.memory();
  storage.session.write('welcomed', '1');
  return storage;
}

/// Застосунок для віджет-тестів. Тема спрощена, розширення теми ті самі.
Widget testApp({MetaRepository? meta, HeroRepository? heroes, AppStorage? storage}) {
  final bundle = FileAssetBundle();
  return ProviderScope(
    retry: (retryCount, error) => null,
    overrides: [
      appStorageProvider.overrideWithValue(storage ?? AppStorage.memory()),
      assetBundleProvider.overrideWithValue(bundle),
      profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
      metaRepositoryProvider.overrideWithValue(meta ?? MockMetaRepository(bundle: bundle, latency: Duration.zero)),
      heroRepositoryProvider.overrideWithValue(heroes ?? MockHeroRepository(bundle: bundle, latency: Duration.zero)),
    ],
    child: Consumer(
      builder: (context, ref, _) => MaterialApp.router(
        theme: ThemeData(
          colorScheme: const ColorScheme.dark(),
          extensions: const [AppColors.dark, AppMetrics()],
        ),
        routerConfig: ref.watch(appRouterProvider),
      ),
    ),
  );
}
