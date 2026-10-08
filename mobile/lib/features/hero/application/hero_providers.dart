import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../data/api_hero_repository.dart';
import '../data/hero_repository.dart';
import '../domain/hero_details.dart';

final heroRepositoryProvider = Provider<HeroRepository>(
  (ref) => AppConfig.useMocks ? MockHeroRepository() : ApiHeroRepository(ref.watch(dioProvider)),
);

/// Картка героя за `id`. Звільняється, щойно екран закрито.
final heroDetailsProvider = FutureProvider.autoDispose.family<HeroDetails, int>(
  (ref, id) => ref.read(heroRepositoryProvider).fetchHero(id),
);
