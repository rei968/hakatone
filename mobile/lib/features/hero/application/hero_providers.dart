import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/hero_repository.dart';
import '../domain/hero_details.dart';

final heroRepositoryProvider = Provider<HeroRepository>((ref) => MockHeroRepository());

/// Картка героя за `id`. Звільняється, щойно екран закрито.
final heroDetailsProvider = FutureProvider.autoDispose.family<HeroDetails, int>(
  (ref, id) => ref.read(heroRepositoryProvider).fetchHero(id),
);
