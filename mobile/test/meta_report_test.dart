import 'dart:convert';
import 'dart:io';

import 'package:dota_builds/features/meta/domain/hero_attribute.dart';
import 'package:dota_builds/features/meta/domain/meta_insights.dart';
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

    expect(report.patch, '7.41');
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

  test('тиждень: найкращий, найгірший, зліт і падіння, популярні', () {
    final report = MetaReport.fromJson({
      'patch': '7.41',
      'rank': 'divine',
      'total_matches': 396740,
      'meta_heroes': [
        {'id': 1, 'name': 'A', 'win_rate': 55.1, 'pick_rate': 12.9, 'win_rate_delta': 1.8, 'primary_attr': 'str', 'tier': 'S'},
        {'id': 2, 'name': 'B', 'win_rate': 44.2, 'pick_rate': 3.0, 'win_rate_delta': -0.9, 'primary_attr': 'agi', 'tier': 'C'},
        {'id': 3, 'name': 'C', 'win_rate': 60.0, 'pick_rate': 0.2, 'win_rate_delta': 3.4, 'primary_attr': 'int', 'tier': 'S'},
        {'id': 4, 'name': 'D', 'win_rate': 50.0, 'pick_rate': 20.0, 'win_rate_delta': -2.9, 'primary_attr': 'all', 'tier': 'A'},
      ],
    });
    final insights = MetaInsights.of(report);
    expect(insights.best?.name, 'A', reason: 'C має замалу вибірку');
    expect(insights.worst?.name, 'B');
    expect(insights.risers.first.name, 'C');
    expect(insights.fallers.first.name, 'D');
    expect(insights.popular.first.name, 'D');
    expect(report.totalMatches, 396740);

    expect([for (final h in queryHeroes(report.heroes, sort: MetaSort.winRate)) h.name], ['C', 'A', 'D', 'B']);
    expect([for (final h in queryHeroes(report.heroes)) h.name], ['C', 'A', 'D', 'B'], reason: 'S, S, A, C');
    expect([for (final h in queryHeroes(report.heroes, search: ' b ')) h.name], ['B']);
  });

  test('updated_at: null від бекенду без героїв не ламає розбір', () {
    final report = MetaReport.fromJson({'updated_at': null, 'patch': '7.37d', 'meta_heroes': []});
    expect(report.updatedAt, isNull);
    expect(report.byTier, isEmpty);
  });
}
