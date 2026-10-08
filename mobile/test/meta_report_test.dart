import 'dart:convert';
import 'dart:io';

import 'package:dota_builds/features/meta/domain/hero_attribute.dart';
import 'package:dota_builds/features/meta/domain/meta_report.dart';
import 'package:dota_builds/features/meta/domain/tier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final name in ['meta.json', 'dota2.json']) {
    test('мок $name збігається з сідом бекенду', () {
      final mock = File('assets/mocks/$name').readAsStringSync();
      final seed = File('../backend/database/seeds/$name').readAsStringSync();
      expect(mock, seed, reason: 'Онови assets/mocks з backend/database/seeds');
    });
  }

  test('розбирає meta.json за контрактом openapi', () {
    final json = jsonDecode(File('assets/mocks/meta.json').readAsStringSync()) as Map<String, dynamic>;
    final report = MetaReport.fromJson(json);

    expect(report.patch, '7.37d');
    expect(report.updatedAt, DateTime.utc(2026, 10, 8, 9));
    expect(report.heroes, hasLength(3));

    final pudge = report.heroes.first;
    expect(pudge.id, 14);
    expect(pudge.tier, Tier.s);
    expect(pudge.winRate, 53.4);
    expect(pudge.primaryAttribute, HeroAttribute.strength);
    expect(report.heroes.last.primaryAttribute, HeroAttribute.universal);
  });

  test('групує за тірами від S, усередині за вінрейтом, порожні тіри пропускає', () {
    final report = MetaReport.fromJson({
      'updated_at': '2026-10-08T09:00:00Z',
      'patch': '7.37d',
      'meta_heroes': [
        {'id': 1, 'name': 'Low A', 'win_rate': 50.1, 'tier': 'A'},
        {'id': 2, 'name': 'No tier', 'win_rate': 60.0},
        {'id': 3, 'name': 'High A', 'win_rate': 51.8, 'tier': 'a'},
        {'id': 4, 'name': 'C hero', 'win_rate': 46.8, 'tier': 'C', 'ai_summary': '  '},
      ],
    });
    final groups = report.byTier;
    expect([for (final (tier, _) in groups) tier], [Tier.a, Tier.c, Tier.none]);
    expect([for (final h in groups.first.$2) h.name], ['High A', 'Low A']);
    expect(groups[1].$2.single.aiSummary, isNull, reason: 'порожня підказка не показується');
  });
}
