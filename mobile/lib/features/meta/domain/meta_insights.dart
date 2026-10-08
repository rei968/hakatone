import 'package:flutter/foundation.dart';

import 'hero_attribute.dart';
import 'meta_report.dart';
import 'tier.dart';

/// Підсумок тижня для головної: усе рахується з `GET /api/meta/dota`.
@immutable
class MetaInsights {
  const MetaInsights._({
    required this.best,
    required this.worst,
    required this.risers,
    required this.fallers,
    required this.popular,
    required this.hasDeltas,
  });

  /// Герої з пікрейтом нижче цього не претендують на «найкращий/найгірший»:
  /// на малій вибірці вінрейт випадковий.
  static const minPickRate = 1.0;

  factory MetaInsights.of(MetaReport report) {
    final heroes = report.heroes;
    final reliable = heroes.where((h) => h.pickRate >= minPickRate).toList();
    final pool = reliable.isEmpty ? heroes : reliable;
    final byWinRate = [...pool]..sort((a, b) => b.winRate.compareTo(a.winRate));
    final withDelta = heroes.where((h) => h.winRateDelta != null).toList()
      ..sort((a, b) => b.winRateDelta!.compareTo(a.winRateDelta!));
    return MetaInsights._(
      best: byWinRate.firstOrNull,
      worst: byWinRate.length > 1 ? byWinRate.last : null,
      risers: withDelta.where((h) => h.winRateDelta! > 0).take(3).toList(),
      fallers: withDelta.reversed.where((h) => h.winRateDelta! < 0).take(3).toList(),
      popular: ([...heroes]..sort((a, b) => b.pickRate.compareTo(a.pickRate))).take(5).toList(),
      hasDeltas: withDelta.isNotEmpty,
    );
  }

  final MetaHero? best;
  final MetaHero? worst;

  /// Найбільший зліт вінрейту за тиждень першим.
  final List<MetaHero> risers;

  /// Найбільше падіння першим.
  final List<MetaHero> fallers;
  final List<MetaHero> popular;

  /// Бекенд віддає `win_rate_delta`. Старий бекенд — ні, тоді блок змін ховається.
  final bool hasDeltas;
}

enum MetaSort {
  tier('Тір'),
  winRate('Вінрейт'),
  pickRate('Пікрейт');

  const MetaSort(this.label);

  final String label;
}

/// Пошук, фільтр атрибута й сортування таблиці мети.
List<MetaHero> queryHeroes(List<MetaHero> heroes, {String search = '', HeroAttribute? attribute, MetaSort sort = MetaSort.tier}) {
  final needle = search.trim().toLowerCase();
  final result = heroes
      .where((h) => attribute == null || h.primaryAttribute == attribute)
      .where((h) => needle.isEmpty || h.name.toLowerCase().contains(needle))
      .toList();
  int byWinRate(MetaHero a, MetaHero b) => b.winRate.compareTo(a.winRate);
  result.sort(switch (sort) {
    MetaSort.tier => (a, b) {
        final tier = Tier.values.indexOf(a.tier).compareTo(Tier.values.indexOf(b.tier));
        return tier != 0 ? tier : byWinRate(a, b);
      },
    MetaSort.winRate => byWinRate,
    MetaSort.pickRate => (a, b) => b.pickRate.compareTo(a.pickRate),
  });
  return result;
}
