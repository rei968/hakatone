import 'dart:async';

import 'package:backend/ai/ai_client.dart';
import 'package:backend/ai/build_rules.dart';
import 'package:backend/db/app_database.dart';
import 'package:backend/opendota/opendota_client.dart';

const _system = 'Ти аналітик Dota 2. На основі статистики публічних матчів з OpenDota пишеш '
    'короткий практичний гайд українською мовою. Назви здібностей, талантів і предметів пиши '
    'англійською, точно як у наданих списках. Спирайся на надані цифри, нічого не вигадуй про патчі.';

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
      'minItems': 18,
      'maxItems': 18,
      'description': 'Рівно 18 елементів, рівні 1-18 по порядку: назва здібності зі списку, '
          '"L" або "R" на рівні, де береться талант, "-" на рівні без очка прокачки (17).',
    },
    'talents': {
      'type': 'array',
      'minItems': 4,
      'maxItems': 4,
      'items': {
        'type': 'object',
        'properties': {
          'level': {'type': 'integer', 'enum': talentLevels},
          'side': {'type': 'string', 'enum': ['L', 'R']},
          'name': {'type': 'string'},
        },
        'required': ['level', 'side', 'name'],
      },
      'description': 'По одному таланту на рівнях 10, 15, 20, 25 з наданих пар L/R.',
    },
    'core_items': {
      'type': 'array',
      'items': {'type': 'string'},
      'description': '4-6 ключових повних предметів (не компонентів) у порядку покупки.',
    },
    'situational_items': {
      'type': 'array',
      'minItems': 3,
      'maxItems': 4,
      'items': {
        'type': 'object',
        'properties': {
          'name': {'type': 'string'},
          'reason': {'type': 'string', 'description': 'Українською, до 40 символів.'},
        },
        'required': ['name', 'reason'],
      },
    },
    'tactics': {
      'type': 'string',
      'description': '2-4 речення: як грати героєм і проти кого бути обережним.',
    },
  },
  'required': ['ai_summary', 'skill_order', 'talents', 'core_items', 'situational_items', 'tactics'],
};

typedef HeroBuild = ({
  String summary,
  List<String> skillOrder,
  List<Map<String, Object>> talents,
  List<String> coreItems,
  List<Map<String, String>> situationalItems,
  String tactics,
});

/// Builds an AI analysis (summary + build v2) from OpenDota numbers and caches it in the DB.
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

    // OpenDota requests in parallel, like Task.WhenAll; the constants are cached after the first call.
    final (popularity, matchups, items, itemKeys, heroAbilities, abilities, npcNames, timings) = await (
      _openDota.itemPopularity(heroId),
      _openDota.matchups(heroId),
      _openDota.items(),
      _openDota.itemNamesByKey(),
      _openDota.heroAbilities(),
      _openDota.abilities(),
      _openDota.heroNpcNames(),
      _openDota.itemTimings(heroId),
    ).wait;

    final kitData = heroAbilities[npcNames[heroId]] as Map<String, dynamic>?;
    if (kitData == null) throw AiException('no ability data for hero $heroId');
    final kit = heroKitFromConstants(kitData, abilities);
    if (kit.abilities.isEmpty) throw AiException('empty ability list for hero $heroId');

    final result = await _ai.generateJson(
      system: _system,
      prompt: _prompt(hero, kit, popularity, matchups, items, _db.heroNames()),
      schema: _schema,
    );
    final build = parseBuild(result, kit, heroId: heroId, itemNames: itemKeys.values.toSet());

    _db.saveAnalysis(
      heroId,
      summary: build.summary,
      skillOrder: build.skillOrder,
      talents: build.talents,
      coreItems: build.coreItems,
      itemTimings: weightedItemTimings(timings, build.coreItems, itemKeys),
      situationalItems: build.situationalItems,
      tactics: build.tactics,
    );
  }
}

/// Validates the model's JSON against the kit and item names. Throws [AiException].
HeroBuild parseBuild(
  Map<String, dynamic> json,
  HeroKit kit, {
  required int heroId,
  required Set<String> itemNames,
}) {
  List<Object?> list(String key) => json[key] is List ? json[key] as List : const [];
  String text(String key) => (json[key] is String ? json[key] as String : '').trim();

  final summary = text('ai_summary'), tactics = text('tactics');
  if (summary.isEmpty || tactics.isEmpty) throw AiException('AI returned an empty summary or tactics');

  final skillOrder = [for (final s in list('skill_order')) '$s'.trim()];
  validateSkillOrder(skillOrder, kit, heroId: heroId);

  final coreItems = [
    for (final name in list('core_items').whereType<String>().map((s) => s.trim()))
      if (itemNames.contains(name)) name,
  ].take(6).toList();
  if (coreItems.length < 4) throw AiException('core_items: fewer than 4 known items in ${json['core_items']}');

  final situational = [
    for (final item in list('situational_items').whereType<Map>())
      if (itemNames.contains('${item['name']}'.trim()))
        {'name': '${item['name']}'.trim(), 'reason': _clip('${item['reason'] ?? ''}'.trim(), 40)},
  ].take(4).toList();
  if (situational.length < 3) throw AiException('situational_items: fewer than 3 known items');

  return (
    summary: summary,
    skillOrder: skillOrder,
    talents: normalizeTalents(list('talents'), kit),
    coreItems: coreItems,
    situationalItems: situational,
    tactics: tactics,
  );
}

String _clip(String text, int max) => text.length <= max ? text : text.substring(0, max).trimRight();

String _prompt(
  Map<String, Object?> hero,
  HeroKit kit,
  Map<String, Map<String, int>> popularity,
  List<Map<String, dynamic>> matchups,
  Map<int, ({String name, int cost})> items,
  Map<int, String> heroNames,
) {
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

  final talents = [
    for (final level in talentLevels)
      if (kit.talents[level] case final pair?) '- рівень $level: L = "${pair.left}", R = "${pair.right}"',
  ].join('\n');

  return '''
Герой: ${hero['name']}
Основний атрибут: ${hero['primary_attr']}, тип атаки: ${hero['attack_type']}, ролі: ${(hero['roles'] as List?)?.join(', ')}
Публічні матчі: win rate ${hero['win_rate']}%, pick rate ${hero['pick_rate']}%, тір ${hero['tier']}

Здібності (пиши в skill_order точно так): ${kit.abilities.map((a) => '"$a"').join(', ')}
Ультимейт: "${kit.ultimate}" (зазвичай рівні 6, 12, 18)

Таланти, пари L/R:
$talents

Правила skill_order: рівно 18 елементів для рівнів 1-18. На рівні, де береш талант, пиши "L" або "R"
(та сама сторона, що в talents). На рівні 17 очка прокачки немає, там "-".

Найпопулярніші предмети за фазами гри:
- старт: ${topItems('start_game_items')}
- рання гра: ${topItems('early_game_items')}
- середина: ${topItems('mid_game_items')}
- пізня гра: ${topItems('late_game_items')}

Win rate героя проти інших (мінімум ${HeroAnalyzer._minMatchupGames} ігор):
- найкращі: ${describe(rated.take(3))}
- найгірші: ${describe(rated.reversed.take(3))}

situational_items: 3-4 предмети під конкретні загрози, reason українською до 40 символів.
''';
}
