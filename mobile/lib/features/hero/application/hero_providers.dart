import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/app_storage.dart';
import '../data/api_hero_repository.dart';
import '../data/hero_repository.dart';
import '../domain/hero_details.dart';

final heroRepositoryProvider = Provider<HeroRepository>(
  (ref) => AppConfig.useMocks ? MockHeroRepository() : ApiHeroRepository(ref.watch(dioProvider)),
);

/// Картка героя і чи вона з кешу.
@immutable
class HeroCard {
  const HeroCard({required this.details, this.savedAt, this.staleError});

  final HeroDetails details;

  /// Коли збережено картку з кешу; `null` — свіжа відповідь сервера.
  final DateTime? savedAt;

  /// Чому не вдалося оновити (показуємо збережену картку).
  final Object? staleError;

  bool get fromCache => staleError != null;
}

/// Спершу мережа, без неї — збережена картка (офлайн-демо в режимі польоту).
/// 404 не кешується: героя справді немає.
final heroCardProvider = FutureProvider.autoDispose.family<HeroCard, int>((ref, id) async {
  final cache = ref.read(jsonCacheProvider);
  final key = 'hero:$id';
  try {
    final details = await ref.read(heroRepositoryProvider).fetchHero(id);
    await cache.write(key, details.toJson(), DateTime.now());
    return HeroCard(details: details);
  } on HeroNotFoundException {
    rethrow;
  } catch (error) {
    final cached = cache.read(key);
    if (cached == null) rethrow;
    return HeroCard(details: HeroDetails.fromJson(cached.data), savedAt: cached.savedAt, staleError: error);
  }
});
