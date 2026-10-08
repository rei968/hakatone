import 'package:test/test.dart';

import 'package:backend/ai/ai_client.dart';
import 'package:backend/ai/build_rules.dart';
import 'package:backend/ai/hero_analyzer.dart';

/// Wraith King as /constants/hero_abilities + /constants/abilities return him (trimmed).
final _heroAbilities = <String, dynamic>{
  'abilities': [
    'skeleton_king_hellfire_blast',
    'skeleton_king_vampiric_spirit',
    'skeleton_king_mortal_strike',
    'generic_hidden',
    'skeleton_king_innate_thing',
    'skeleton_king_reincarnation',
  ],
  'talents': [
    {'name': 't1r', 'level': 1},
    {'name': 't1l', 'level': 1},
    {'name': 't2r', 'level': 2},
    {'name': 't2l', 'level': 2},
    {'name': 't3r', 'level': 3},
    {'name': 't3l', 'level': 3},
    {'name': 't4r', 'level': 4},
    {'name': 't4l', 'level': 4},
  ],
};

final _abilityConstants = <String, dynamic>{
  'skeleton_king_hellfire_blast': {'dname': 'Wraithfire Blast'},
  'skeleton_king_vampiric_spirit': {'dname': 'Vampiric Spirit'},
  'skeleton_king_mortal_strike': {'dname': 'Mortal Strike'},
  'skeleton_king_innate_thing': {'dname': 'Innate Thing'},
  'skeleton_king_reincarnation': {'dname': 'Reincarnation'},
  't1r': {'dname': '+{s:bonus_vampiric_aura}% Vampiric Spirit Lifesteal'},
  't1l': {'dname': '+{s:bonus_blast_dot_duration}s Wraithfire Blast Slow Duration'},
  't2r': {'dname': '+350 Health'},
  't2l': {'dname': '+{s:bonus_blast_stun_duration}s Wraithfire Blast Stun Duration'},
  't3r': {'dname': '+50 Attack Speed'},
  't3l': {'dname': '+{s:bonus_min_skeleton_spawn} Bone Guard Skeletons Spawned'},
  't4r': {'dname': '-{s:bonus_AbilityCooldown}s Mortal Strike Cooldown'},
  't4l': {'dname': 'Reincarnation Casts Wraithfire Blast'},
};

const _validOrder = [
  'Wraithfire Blast', 'Vampiric Spirit', 'Wraithfire Blast', 'Mortal Strike', 'Wraithfire Blast', //
  'Reincarnation', 'Wraithfire Blast', 'Vampiric Spirit', 'Vampiric Spirit', 'L', //
  'Vampiric Spirit', 'Reincarnation', 'Mortal Strike', 'Mortal Strike', 'R', //
  'Mortal Strike', '-', 'Reincarnation',
];

void main() {
  final kit = heroKitFromConstants(_heroAbilities, _abilityConstants);

  group('hero kit from OpenDota constants', () {
    test('skips hidden and innate abilities, the ultimate is the last one', () {
      expect(kit.abilities, ['Wraithfire Blast', 'Vampiric Spirit', 'Mortal Strike', 'Reincarnation']);
      expect(kit.ultimate, 'Reincarnation');
    });

    test('first talent of a pair is right, second is left (checked on the Dota 2 Wiki)', () {
      expect(kit.talents[10], (right: 'Vampiric Spirit Lifesteal', left: 'Wraithfire Blast Slow Duration'));
      expect(kit.talents[25], (right: 'Mortal Strike Cooldown', left: 'Reincarnation Casts Wraithfire Blast'));
    });

    test('placeholders go away with their sign and unit', () {
      expect(cleanTalentName('+{s:bonus_damage} Meat Hook Damage'), 'Meat Hook Damage');
      expect(cleanTalentName('{s:bonus_dismember_damage}x Dismember Damage/Heal'), 'Dismember Damage/Heal');
      expect(cleanTalentName('+350 Health'), '+350 Health');
    });
  });

  group('skill order validation', () {
    test('accepts a valid 18-level order', () {
      expect(() => validateSkillOrder(_validOrder, kit, heroId: 42), returnsNormally);
    });

    test('needs exactly 18 levels', () {
      expect(() => validateSkillOrder(_validOrder.take(17).toList(), kit, heroId: 42), throwsA(isA<AiException>()));
      expect(() => validateSkillOrder([..._validOrder, 'Mortal Strike'], kit, heroId: 42), throwsA(isA<AiException>()));
    });

    test('rejects an unknown ability', () {
      final order = [..._validOrder]..[1] = 'Bone Guard';
      expect(() => validateSkillOrder(order, kit, heroId: 42), throwsA(isA<AiException>()));
    });

    test('rejects the ultimate before level 6', () {
      final order = [..._validOrder]..[4] = 'Reincarnation';
      expect(() => validateSkillOrder(order, kit, heroId: 42), throwsA(isA<AiException>()));
    });

    test('Invoker and Meepo skip the ultimate rule', () {
      final order = [..._validOrder]..[0] = 'Reincarnation';
      expect(() => validateSkillOrder(order, kit, heroId: 74), returnsNormally);
      expect(() => validateSkillOrder(order, kit, heroId: 82), returnsNormally);
    });

    test('rejects a talent before level 10', () {
      final order = [..._validOrder]..[8] = 'L';
      expect(() => validateSkillOrder(order, kit, heroId: 42), throwsA(isA<AiException>()));
    });
  });

  group('talents', () {
    test('names come from the kit for the chosen side', () {
      final talents = normalizeTalents([
        {'level': 10, 'side': 'L', 'name': 'whatever'},
        {'level': 15, 'side': 'R', 'name': '+350 Health'},
        {'level': 20, 'side': 'R', 'name': ''},
        {'level': 25, 'side': 'L', 'name': 'x'},
      ], kit);
      expect(talents, [
        {'level': 10, 'side': 'L', 'name': 'Wraithfire Blast Slow Duration'},
        {'level': 15, 'side': 'R', 'name': '+350 Health'},
        {'level': 20, 'side': 'R', 'name': '+50 Attack Speed'},
        {'level': 25, 'side': 'L', 'name': 'Reincarnation Casts Wraithfire Blast'},
      ]);
    });

    test('a missing level or a bad side is invalid', () {
      expect(() => normalizeTalents([{'level': 10, 'side': 'L', 'name': 'a'}], kit), throwsA(isA<AiException>()));
      expect(
        () => normalizeTalents([
          for (final level in talentLevels) {'level': level, 'side': 'X', 'name': 'a'},
        ], kit),
        throwsA(isA<AiException>()),
      );
    });
  });

  group('item timings', () {
    test('average time weighted by games, games come as strings', () {
      final rows = [
        {'item': 'radiance', 'time': 900, 'games': '10', 'wins': '6'},
        {'item': 'radiance', 'time': 1200, 'games': '30', 'wins': '15'},
        {'item': 'phase_boots', 'time': 450, 'games': '5', 'wins': '3'},
        {'item': 'blink', 'time': 1500, 'games': '0', 'wins': '0'},
        {'item': 'unknown_item', 'time': 100, 'games': '50', 'wins': '1'},
      ];
      final names = {'radiance': 'Radiance', 'phase_boots': 'Phase Boots', 'blink': 'Blink Dagger'};

      final timings = weightedItemTimings(rows, ['Phase Boots', 'Radiance', 'Blink Dagger', 'Assault Cuirass'], names);
      expect(timings, {'Phase Boots': 450, 'Radiance': 1125}); // (900*10 + 1200*30) / 40
    });
  });

  group('parseBuild', () {
    final itemNames = {
      'Phase Boots', 'Radiance', 'Blink Dagger', 'Assault Cuirass', 'Black King Bar', 'Monkey King Bar', 'Aeon Disk',
    };
    Map<String, dynamic> answer({List<String>? order}) => {
          'ai_summary': 'Сильний керрі.',
          'skill_order': order ?? _validOrder,
          'talents': [for (final level in talentLevels) {'level': level, 'side': 'L', 'name': ''}],
          'core_items': ['Phase Boots', 'Radiance', 'Made Up Item', 'Blink Dagger', 'Assault Cuirass'],
          'situational_items': [
            {'name': 'Black King Bar', 'reason': 'Проти контролю й магії, коли вороги мають багато станів'},
            {'name': 'Monkey King Bar', 'reason': 'Проти ухилення'},
            {'name': 'Aeon Disk', 'reason': 'Проти бурсту'},
          ],
          'tactics': 'Фармити й ініціювати.',
        };

    test('keeps known items and clips reasons to 40 characters', () {
      final build = parseBuild(answer(), kit, heroId: 42, itemNames: itemNames);
      expect(build.coreItems, ['Phase Boots', 'Radiance', 'Blink Dagger', 'Assault Cuirass']);
      expect(build.situationalItems.first['reason']!.length, lessThanOrEqualTo(40));
      expect(build.talents.map((t) => t['level']), talentLevels);
    });

    test('an invalid skill order is not accepted', () {
      final order = [..._validOrder]..[2] = 'Reincarnation';
      expect(() => parseBuild(answer(order: order), kit, heroId: 42, itemNames: itemNames), throwsA(isA<AiException>()));
    });
  });
}
