import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/app_storage.dart';
import '../data/api_meta_repository.dart';
import '../data/meta_repository.dart';
import '../domain/meta_report.dart';

final metaRepositoryProvider = Provider<MetaRepository>(
  (ref) => AppConfig.useMocks ? MockMetaRepository() : ApiMetaRepository(ref.watch(dioProvider)),
);

/// Мета разом із тим, звідки вона і наскільки свіжа.
@immutable
class MetaFeed {
  const MetaFeed({
    required this.report,
    required this.savedAt,
    this.fromCache = false,
    this.refreshing = false,
    this.error,
  });

  final MetaReport report;

  /// Коли ці дані потрапили на пристрій.
  final DateTime savedAt;

  /// Показуємо кеш з Hive, свіжої відповіді ще не було.
  final bool fromCache;

  /// Фоном іде запит до сервера.
  final bool refreshing;

  /// Чому останнє оновлення не вдалося. Дані на екрані — попередні.
  final Object? error;

  /// Мережі немає: банер «Немає інтернету», сіра крапка.
  bool get offline => error is ApiException && (error! as ApiException).failure == ApiFailure.network;

  MetaFeed _with({bool? refreshing, Object? error, bool clearError = false}) => MetaFeed(
        report: report,
        savedAt: savedAt,
        fromCache: fromCache,
        refreshing: refreshing ?? this.refreshing,
        error: clearError ? null : (error ?? this.error),
      );
}

/// Stale-while-revalidate (специфікація головного меню, «Стани екрана»):
/// кеш з Hive показуємо одразу, мережевий запит іде у фоні. Скелетон бачить
/// лише той, у кого кешу ще немає; помилку — той, у кого немає ні кешу, ні мережі.
class MetaController extends AsyncNotifier<MetaFeed> {
  static const cacheKey = 'meta';

  @override
  Future<MetaFeed> build() async {
    final cached = ref.read(jsonCacheProvider).read(cacheKey);
    if (cached != null) {
      try {
        final feed = MetaFeed(
          report: MetaReport.fromJson(cached.data),
          savedAt: cached.savedAt,
          fromCache: true,
          refreshing: true,
        );
        Future(_revalidate);
        return feed;
      } catch (_) {
        // Пошкоджений кеш — просто йдемо в мережу.
      }
    }
    return _fetch();
  }

  Future<MetaFeed> _fetch() async {
    final report = await ref.read(metaRepositoryProvider).fetchMeta();
    final now = DateTime.now();
    await ref.read(jsonCacheProvider).write(cacheKey, report.toJson(), now);
    return MetaFeed(report: report, savedAt: now);
  }

  Future<void> _revalidate() async {
    try {
      await future;
    } catch (_) {
      return;
    }
    if (!ref.mounted) return;
    final previous = state.value;
    try {
      final fresh = await _fetch();
      if (ref.mounted) state = AsyncData(fresh);
    } catch (error) {
      if (ref.mounted && previous != null) {
        state = AsyncData(previous._with(refreshing: false, error: error));
      }
    }
  }

  /// Pull-to-refresh і «Спробувати ще раз».
  Future<void> refresh() async {
    final previous = state.value;
    if (previous == null) {
      ref.invalidateSelf();
      try {
        await future;
      } catch (_) {
        // Помилка вже в state — екран покаже її з кнопкою повтору.
      }
      return;
    }
    state = AsyncData(previous._with(refreshing: true, clearError: true));
    await _revalidate();
  }
}

final metaControllerProvider = AsyncNotifierProvider<MetaController, MetaFeed>(MetaController.new);
