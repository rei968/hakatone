import 'dart:async';

import 'package:backend/ai/ai_client.dart';
import 'package:backend/db/app_database.dart';
import 'package:backend/opendota/opendota_client.dart';

const _system = 'Ти аналітик Dota 2. На основі статистики публічних матчів з OpenDota пишеш '
    'короткий практичний гайд українською мовою. Назви здібностей і предметів пиши англійською, '
    'точно як у грі. Спирайся на надані цифри, нічого не вигадуй про патчі.';

const _schema = <String, Object?>{
  'type': 'object',
  'properties': {
    'ai_summary': {
      'type': 'string',
      'description': '1-2 речення: роль героя і чим він сильний зараз, з опорою на цифри.',
    },
    'skill_order': {
      'type': 'array',
      'items': {'type': 'string'},
      'description': 'Прокачка здібностей на рівнях 1-6: рівно 6 назв, ультимейт на 6 рівні.',
    },
    'core_items': {
      'type': 'array',
      'items': {'type': 'string'},
      'description': '4-6 ключових повних предметів (не компонентів) у порядку покупки.',
    },
    'tactics': {
      'type': 'string',
      'description': '2-4 речення: як грати героєм і проти кого бути обережним.',
    },
  },
  'required': ['ai_summary', 'skill_order', 'core_items', 'tactics'],
};

typedef HeroAnalysis = ({String summary, List<String> skillOrder, List<String> coreItems, String tactics});

/// Builds an AI analysis (summary + build) from OpenDota numbers and caches it in the DB.
class HeroAnalyzer {
  HeroAnalyzer(this._db, this._openDota, this._ai);

  static const _minMatchupGames = 50;

  final AppDatabase _db;
  final OpenDotaClient _openDota;
  final AiClient _ai;
  final _inFlight = <int, Future<void>>{};

  /// Generates and stores the analysis. Throws on failure; the cached build stays as it was.
  /// Concurrent calls for the same hero share one request.
  Future<void> analyze(int heroId) => _inFlight[heroId] ??= _analyze(heroId).whenComplete(() {
        // Block body on purpose: `=> _inFlight.remove(...)` would return this very future,
        // and whenComplete would wait for it forever.
        _inFlight.remove(heroId);
      });

  Future<void> _analyze(int heroId) async {
    final hero = _db.heroWithBuild(heroId);
    if (hero == null) throw ArgumentError.value(heroId, 'heroId', 'hero is not in the DB');

    // Three OpenDota requests in parallel, like Task.WhenAll.
    final (popularity, matchups, items) =
        await (_openDota.itemPopularity(heroId), _openDota.matchups(heroId), _openDota.items()).wait;

    final result = await _ai.generateJson(
      system: _system,
      prompt: _prompt(hero, popularity, matchups, items, _db.heroNames()),
      schema: _schema,
    );
    final analysis = _parse(result);

    _db.saveAnalysis(
      heroId,
      summary: analysis.summary,
      skillOrder: analysis.skillOrder,
      coreItems: analysis.coreItems,
      tactics: analysis.tactics,
    );
  }
}

String _prompt(
  Map<String, Object?> hero,
  Map<String, Map<String, int>> popularity,
  List<Map<String, dynamic>> matchups,
  Map<int, ({String name, int cost})> items,
  Map<int, String> heroNames,
) {
  final abilities = (hero['abilities'] as List).map((a) => (a as Map)['name']).toList();

  String topItems(String phase) {
    final counts = (popularity[phase] ?? const {}).entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return counts.take(8).map((e) {
      final item = items[int.tryParse(e.key)];
      return item == null ? null : '${item.name} (${item.cost} золота, ${e.value} покупок)';
    }).nonNulls.join(', ');
  }

  final rated = [
    for (final m in matchups)
      if ((m['games_played'] as num) >= HeroAnalyzer._minMatchupGames)
        (
          name: heroNames[m['hero_id']] ?? 'герой #${m['hero_id']}',
          winRate: (m['wins'] as num) / (m['games_played'] as num) * 100,
          games: m['games_played'] as num,
        ),
  ]..sort((a, b) => b.winRate.compareTo(a.winRate));
  String describe(Iterable<({String name, double winRate, num games})> list) =>
      list.map((m) => '${m.name} ${m.winRate.toStringAsFixed(1)}% (${m.games} ігор)').join(', ');

  return '''
Герой: ${hero['name']}
Основний атрибут: ${hero['primary_attr']}, тип атаки: ${hero['attack_type']}, ролі: ${(hero['roles'] as List?)?.join(', ')}
Публічні матчі: win rate ${hero['win_rate']}%, pick rate ${hero['pick_rate']}%, тір ${hero['tier']}
Здібності: ${abilities.isEmpty ? 'не надано, використай реальні назви здібностей героя з гри' : abilities.join(', ')}

Найпопулярніші предмети за фазами гри:
- старт: ${topItems('start_game_items')}
- рання гра: ${topItems('early_game_items')}
- середина: ${topItems('mid_game_items')}
- пізня гра: ${topItems('late_game_items')}

Win rate героя проти інших (мінімум ${HeroAnalyzer._minMatchupGames} ігор):
- найкращі: ${describe(rated.take(3))}
- найгірші: ${describe(rated.reversed.take(3))}
''';
}

HeroAnalysis _parse(Map<String, dynamic> json) {
  List<String> strings(String key) => [for (final s in json[key] as List) s as String];

  final analysis = (
    summary: json['ai_summary'] as String,
    skillOrder: strings('skill_order'),
    coreItems: strings('core_items'),
    tactics: json['tactics'] as String,
  );
  if (analysis.summary.isEmpty || analysis.skillOrder.isEmpty || analysis.coreItems.isEmpty) {
    throw AiException('AI returned an empty analysis: $json');
  }
  return analysis;
}
