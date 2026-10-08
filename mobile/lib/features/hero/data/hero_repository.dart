import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/hero_details.dart';

/// `GET /api/dota/heroes/{id}` з `docs/openapi.yaml`.
abstract interface class HeroRepository {
  /// Кидає [HeroNotFoundException], якщо героя немає.
  Future<HeroDetails> fetchHero(int id);
}

/// Збирає `HeroWithBuild` з моків: мета (`meta.json`), лор, характеристики
/// й здібності (`dota2.json`) і тимчасові AI-білди (`ai_builds.json`).
class MockHeroRepository implements HeroRepository {
  MockHeroRepository({AssetBundle? bundle, this.latency = const Duration(milliseconds: 500)})
      : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  final Duration latency;

  @override
  Future<HeroDetails> fetchHero(int id) async {
    await Future<void>.delayed(latency);
    final meta = await _json('assets/mocks/meta.json');
    final seeds = await _json('assets/mocks/dota2.json');
    final builds = await _json('assets/mocks/ai_builds.json');

    Map<String, dynamic>? find(Object? list) => (list as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .where((h) => h['id'] == id)
        .firstOrNull;

    final metaHero = find(meta['meta_heroes']);
    final seedHero = find(seeds['heroes']);
    if (metaHero == null && seedHero == null) throw HeroNotFoundException(id);

    return HeroDetails.fromJson({
      ...?seedHero,
      ...?metaHero,
      'ai_build': (builds['builds'] as Map<String, dynamic>?)?['$id'],
    });
  }

  Future<Map<String, dynamic>> _json(String key) async =>
      jsonDecode(await _bundle.loadString(key)) as Map<String, dynamic>;
}
