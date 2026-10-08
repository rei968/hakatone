import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/app_storage.dart';

/// Ранг для мети й картки героя (`?rank=` у `docs/openapi.yaml`).
/// Окремого Immortal немає: в OpenDota ця дужка порожня, тож Divine означає Divine і вище.
enum Rank {
  all('all', 'Усі ранги', 'Усі'),
  herald('herald', 'Herald', 'Herald'),
  guardian('guardian', 'Guardian', 'Guardian'),
  crusader('crusader', 'Crusader', 'Crusader'),
  archon('archon', 'Archon', 'Archon'),
  legend('legend', 'Legend', 'Legend'),
  ancient('ancient', 'Ancient', 'Ancient'),
  divine('divine', 'Divine і вище', 'Divine+');

  const Rank(this.apiValue, this.label, this.short);

  final String apiValue;
  final String label;

  /// Для чипа в шапці.
  final String short;

  static Rank fromApi(String? value) {
    for (final rank in values) {
      if (rank.apiValue == value) return rank;
    }
    return all;
  }
}

/// Обраний ранг спільний для головної, мети й картки героя і переживає перезапуск.
class RankController extends Notifier<Rank> {
  static const _key = 'rank';

  @override
  Rank build() => Rank.fromApi(ref.read(appStorageProvider).session.read(_key));

  void select(Rank rank) {
    if (rank == state) return;
    state = rank;
    ref.read(appStorageProvider).session.write(_key, rank.apiValue);
  }
}

final rankProvider = NotifierProvider<RankController, Rank>(RankController.new);
