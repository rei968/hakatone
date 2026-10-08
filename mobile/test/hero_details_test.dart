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
