import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/config/app_config.dart';
import '../../../core/storage/app_storage.dart';
import '../data/update_repository.dart';
import '../domain/app_release.dart';

/// Нова версія для показу гравцю разом із поточною.
typedef AvailableUpdate = ({AppRelease release, String currentVersion});

/// Перевіряє GitHub Releases не частіше [interval] і віддає реліз, новіший за встановлену версію.
/// Будь-яка помилка (немає мережі, GitHub недоступний) — просто «оновлень немає».
class UpdateChecker {
  UpdateChecker({
    required this.repository,
    required this.store,
    required this.currentVersion,
    required this.enabled,
    DateTime Function()? clock,
    this.interval = const Duration(days: 1),
  }) : _clock = clock ?? DateTime.now;

  static const lastCheckKey = 'update_last_check';

  final UpdateRepository repository;
  final KeyValueStore store;
  final Future<String> Function() currentVersion;

  /// Лише релізна збірка на Android: у debug і на web оновлення через APK не мають сенсу.
  final bool enabled;
  final Duration interval;
  final DateTime Function() _clock;

  Future<AvailableUpdate?> check({bool force = false}) async {
    if (!enabled) return null;
    final now = _clock();
    if (!force && !_isDue(now)) return null;
    try {
      await store.write(lastCheckKey, now.toUtc().toIso8601String());
      final (release, current) = await (repository.latestRelease(), currentVersion()).wait;
      if (release == null || !isNewerVersion(release.version, current)) return null;
      return (release: release, currentVersion: current);
    } catch (_) {
      return null;
    }
  }

  bool _isDue(DateTime now) {
    final last = DateTime.tryParse(store.read(lastCheckKey) ?? '');
    return last == null || now.difference(last) >= interval;
  }
}

final updateRepositoryProvider = Provider<UpdateRepository>(
  (ref) => GitHubUpdateRepository(repo: AppConfig.updateRepo),
);

final updateCheckerProvider = Provider<UpdateChecker>(
  (ref) => UpdateChecker(
    repository: ref.watch(updateRepositoryProvider),
    store: ref.watch(appStorageProvider).cache,
    currentVersion: () async => (await PackageInfo.fromPlatform()).version,
    enabled: kReleaseMode && !kIsWeb && Platform.isAndroid && AppConfig.updateRepo.isNotEmpty,
  ),
);
