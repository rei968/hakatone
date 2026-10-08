import 'dart:io';

import 'package:dota_builds/core/router/app_router.dart';
import 'package:dota_builds/core/storage/app_storage.dart';
import 'package:dota_builds/core/theme/app_colors.dart';
import 'package:dota_builds/core/theme/app_metrics.dart';
import 'package:dota_builds/features/auth/application/auth_controller.dart';
import 'package:dota_builds/features/auth/data/auth_repository.dart';
import 'package:dota_builds/features/hero/application/hero_providers.dart';
import 'package:dota_builds/features/hero/data/hero_repository.dart';
import 'package:dota_builds/features/meta/application/meta_controller.dart';
import 'package:dota_builds/features/meta/data/meta_repository.dart';
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

/// Застосунок для віджет-тестів. Тема спрощена: `AppTheme` тягне шрифти
/// з мережі, а в тестах мережі немає. Розширення теми ті самі.
/// Сховище — у пам’яті, якщо не передано інше.
Widget testApp({MetaRepository? meta, HeroRepository? heroes, AppStorage? storage}) {
  return ProviderScope(
    retry: (retryCount, error) => null,
    overrides: [
      appStorageProvider.overrideWithValue(storage ?? AppStorage.memory()),
      authRepositoryProvider.overrideWithValue(MockAuthRepository(latency: Duration.zero)),
      metaRepositoryProvider.overrideWithValue(
        meta ?? MockMetaRepository(bundle: FileAssetBundle(), latency: Duration.zero),
      ),
      heroRepositoryProvider.overrideWithValue(
        heroes ?? MockHeroRepository(bundle: FileAssetBundle(), latency: Duration.zero),
      ),
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
