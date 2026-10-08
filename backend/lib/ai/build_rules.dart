/// Pure rules for AI build v2: the hero's kit from OpenDota constants, validation of the
/// model's answer and item timings. No network or DB here, so everything is unit-tested.
library;

import 'package:backend/ai/ai_client.dart';

/// Talent levels in the game, in the order of OpenDota's `level` 1..4.
const talentLevels = [10, 15, 20, 25];

/// Heroes whose ultimate isn't bound to level 6 (Invoker's Invoke, Meepo's Divided We Stand).
const heroesWithoutUltimateRule = {74, 82};

/// Levelable abilities, the ultimate and the talent pairs of one hero.
class HeroKit {
  const HeroKit({required this.abilities, required this.ultimate, required this.talents});

  /// Display names (`dname`), e.g. "Meat Hook".
  final List<String> abilities;

  /// The last ability of the kit; null when the kit is empty.
  final String? ultimate;

  /// Game level (10/15/20/25) -> left and right talent names.
  final Map<int, ({String left, String right})> talents;
}

/// Builds the kit from `/constants/hero_abilities[npc_name]` and `/constants/abilities`.
///
/// OpenDota lists each talent level as a pair. Checked against the Dota 2 Wiki talent trees of
/// Pudge (all four levels) and Wraith King: the first of the pair is the RIGHT talent in game,
/// the second is the LEFT one.
HeroKit heroKitFromConstants(Map<String, dynamic> heroAbilities, Map<String, dynamic> abilityConstants) {
  String? dname(Object? key) => (abilityConstants[key] as Map?)?['dname'] as String?;

  final abilities = <String>[];
  for (final key in (heroAbilities['abilities'] as List? ?? const []).cast<String>()) {
    if (key == 'generic_hidden' || key.contains('_empty') || key.contains('innate')) continue;
    final name = dname(key);
    if (name != null && name.isNotEmpty && !abilities.contains(name)) abilities.add(name);
  }

  final byLevel = <int, List<String>>{};
  for (final t in (heroAbilities['talents'] as List? ?? const []).cast<Map<String, dynamic>>()) {
    final level = t['level'];
    final name = dname(t['name']);
    if (level is int && level >= 1 && level <= 4 && name != null) {
      (byLevel[talentLevels[level - 1]] ??= []).add(cleanTalentName(name));
    }
  }

  return HeroKit(
    abilities: abilities,
    ultimate: abilities.isEmpty ? null : abilities.last,
    talents: {
      for (final MapEntry(:key, :value) in byLevel.entries)
        if (value.length == 2) key: (right: value[0], left: value[1]),
    },
  );
}

/// OpenDota talent names carry placeholders without values ("+{s:bonus_vampiric_aura}%
/// Vampiric Spirit Lifesteal"); the placeholder goes away together with its sign and unit.
String cleanTalentName(String dname) => dname
    .replaceAll(RegExp(r'[+\-]?\{s:[^}]*\}(%|s\b|x\b)?'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Checks an 18-level skill order: ability names from the kit, `"L"`/`"R"` for a talent (not
/// before level 10), `"-"` for a level without a skill point, and the ultimate not before
/// level 6 (skipped for [heroesWithoutUltimateRule]). Throws [AiException] when invalid.
void validateSkillOrder(List<String> order, HeroKit kit, {required int heroId}) {
  if (order.length != 18) throw AiException('skill_order has ${order.length} levels, expected 18');
  for (var i = 0; i < order.length; i++) {
    final level = i + 1;
    final entry = order[i];
    if (entry == '-') continue;
    if (entry == 'L' || entry == 'R') {
      if (level < 10) throw AiException('skill_order: talent "$entry" at level $level');
      continue;
    }
    if (!kit.abilities.contains(entry)) throw AiException('skill_order: unknown ability "$entry" at level $level');
    if (entry == kit.ultimate && level < 6 && !heroesWithoutUltimateRule.contains(heroId)) {
      throw AiException('skill_order: ultimate "$entry" at level $level');
    }
  }
}

/// Exactly one talent for each of levels 10/15/20/25. The side comes from the model; the
/// name is taken from the kit, so it always matches the game. Throws [AiException].
List<Map<String, Object>> normalizeTalents(List<Object?> raw, HeroKit kit) {
  final talents = <Map<String, Object>>[];
  for (final level in talentLevels) {
    final pick = raw.whereType<Map>().where((t) => t['level'] == level).firstOrNull;
    final side = pick?['side'];
    if (side != 'L' && side != 'R') throw AiException('talents: no L/R choice for level $level');
    final pair = kit.talents[level];
    final name = pair == null ? (pick?['name'] as String? ?? '').trim() : (side == 'L' ? pair.left : pair.right);
    if (name.isEmpty) throw AiException('talents: no name for level $level');
    talents.add({'level': level, 'side': side as String, 'name': name});
  }
  return talents;
}

/// Average purchase time (seconds) per item of [coreItems], weighted by games, from
/// `/scenarios/itemTimings`: rows `{item, time, games, wins}` where `games` comes as a string.
/// [itemNames] maps item keys ("black_king_bar") to display names. Items without data are skipped.
Map<String, int> weightedItemTimings(
  List<Map<String, dynamic>> rows,
  List<String> coreItems,
  Map<String, String> itemNames,
) {
  final totals = <String, ({num weighted, num games})>{};
  for (final row in rows) {
    final name = itemNames[row['item']];
    final time = row['time'];
    final games = num.tryParse('${row['games']}') ?? 0;
    if (name == null || time is! num || games <= 0) continue;
    final t = totals[name] ?? (weighted: 0, games: 0);
    totals[name] = (weighted: t.weighted + time * games, games: t.games + games);
  }
  return {
    for (final item in coreItems)
      if (totals[item] case final t?) item: (t.weighted / t.games).round(),
  };
}
