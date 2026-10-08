import 'package:dota_builds/features/hero/data/hero_repository.dart';
import 'package:dota_builds/features/hero/domain/hero_details.dart';
import 'package:dota_builds/features/meta/domain/tier.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app.dart';

void main() {
  final repository = MockHeroRepository(bundle: FileAssetBundle(), latency: Duration.zero);

  test('у Juggernaut усі 4 здібності за слотами', () async {
    final jugg = await repository.fetchHero(8);
    expect([for (final a in jugg.abilities) a.name], ['Blade Fury', 'Healing Ward', 'Blade Dance', 'Omnislash']);
    expect(jugg.aiBuild?.coreItems, contains('Maelstrom'));
  });

  test('картка Pudge з сіду HeroWithBuild', () async {
    final pudge = await repository.fetchHero(14);

    expect(pudge.hero.name, 'Pudge');
    expect(pudge.hero.tier, Tier.s);
    expect(pudge.hero.winRate, 53.4);
    expect(pudge.attackType, 'Melee');
    expect(pudge.stats?.baseHp, 700);
    expect(pudge.bio, isNotNull);
    expect([for (final a in pudge.abilities) a.slotOrder], [1, 2, 3, 4]);
    expect(pudge.aiBuild?.skillOrder, hasLength(18));
    expect(pudge.aiBuild?.coreItems.first, 'Phase Boots');
  });

  test('AI-білд v2: 18 рівнів, таланти, таймінги, ситуативні предмети', () async {
    final build = (await repository.fetchHero(14)).aiBuild!;
    final steps = build.steps;
    expect(steps, hasLength(18));
    expect(steps[9].kind, SkillStepKind.talentLeft);
    expect(steps[14].kind, SkillStepKind.talentRight);
    expect(steps[16].kind, SkillStepKind.none);
    expect(steps.first.ability, 'Meat Hook');
    expect([for (final t in build.talents) t.level], [25, 20, 15, 10]);
    expect(build.timingOf('Phase Boots'), const Duration(seconds: 575));
    expect(build.timingOf('phase boots'), const Duration(seconds: 575));
    expect(build.situationalItems.first.name, 'Force Staff');
  });

  test('старий білд без нових полів читається', () {
    final build = AiBuild.fromJson({
      'skill_order': ['Rot', 'Meat Hook'],
      'core_items': ['Blink Dagger', {'name': 'Radiance', 'timing_sec': 1040}],
      'tactics': 'x',
    });
    expect(build.talents, isEmpty);
    expect(build.situationalItems, isEmpty);
    expect(build.coreItems, ['Blink Dagger', 'Radiance']);
    expect(build.timingOf('Radiance'), const Duration(seconds: 1040));
  });

  test('невідомий герой — HeroNotFoundException (404)', () async {
    expect(() => repository.fetchHero(99999), throwsA(isA<HeroNotFoundException>()));
  });

  test('порожній ai_build не показується', () {
    final details = HeroDetails.fromJson({
      'id': 1,
      'name': 'Test',
      'ai_build': {'skill_order': [], 'core_items': [], 'tactics': ' '},
    });
    expect(details.aiBuild, isNull);
    expect(details.abilities, isEmpty);
  });
}
