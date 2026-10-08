import 'dart:convert';

import 'package:flutter/services.dart';

import '../../../core/dota/rank.dart';
import '../domain/hero_details.dart';

/// `GET /api/dota/heroes/{id}` з `docs/openapi.yaml`.
abstract interface class HeroRepository {
  /// Кидає [HeroNotFoundException], якщо героя немає.
  Future<HeroDetails> fetchHero(int id, {Rank rank = Rank.all});
}

/// Віддає героя з `assets/mocks/dota2.json` — копії
/// `backend/database/seeds/dota2.json`, де кожен герой уже має повну
/// форму `HeroWithBuild`: мета, здібності, характеристики й `ai_build`.
class MockHeroRepository implements HeroRepository {
  MockHeroRepository({AssetBundle? bundle, this.latency = const Duration(milliseconds: 500)})
      : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  final Duration latency;

  @override
  Future<HeroDetails> fetchHero(int id, {Rank rank = Rank.all}) async {
    await Future<void>.delayed(latency);
    final seeds = jsonDecode(await _bundle.loadString('assets/mocks/dota2.json')) as Map<String, dynamic>;
    final hero = (seeds['heroes'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .where((h) => h['id'] == id)
        .firstOrNull;
    if (hero == null) throw HeroNotFoundException(id);
    return HeroDetails.fromJson(hero);
  }
}
