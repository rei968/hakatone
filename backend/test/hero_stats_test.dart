import 'package:test/test.dart';

import 'package:backend/meta/hero_stats.dart';

void main() {
  group('parseRank', () {
    test('missing, empty and all mean every rank', () {
      expect(parseRank(null), isNull);
      expect(parseRank(''), isNull);
      expect(parseRank('all'), isNull);
    });

    test('maps rank names to OpenDota brackets', () {
      expect(parseRank('herald'), 1);
      expect(parseRank('archon'), 4);
      expect(parseRank('divine'), 7);
    });

    test('rejects unknown values, including immortal', () {
      expect(() => parseRank('immortal'), throwsA(isA<InvalidRankException>()));
      expect(() => parseRank('Divine'), throwsA(isA<InvalidRankException>()));
      expect(() => parseRank('7'), throwsA(isA<InvalidRankException>()));
    });

    test('rankName round-trips', () {
      expect(rankName(null), 'all');
      for (final MapEntry(:key, :value) in rankBrackets.entries) {
        expect(rankName(value), key);
      }
    });
  });

  group('rank numbers from /heroStats', () {
    // A tiny fake /heroStats: three heroes, bracket 7 = Divine.
    final heroStats = [
      {'id': 1, '7_pick': 600, '7_win': 330, '1_pick': 10, '1_win': 5},
      {'id': 2, '7_pick': 300, '7_win': 141},
      {'id': 3, '7_pick': 100, '7_win': 49},
    ];

    test('rank_stats keeps raw pick/win for brackets 1..7', () {
      final stats = rankStatsFromHeroStats(heroStats.first);
      expect(stats.keys, ['1', '2', '3', '4', '5', '6', '7']);
      expect(stats['7'], {'pick': 600, 'win': 330});
      expect(stats['2'], {'pick': 0, 'win': 0});
    });

    test('win rate, pick rate and tier for a bracket', () {
      final totalPicks = heroStats.fold<num>(0, (sum, h) => sum + (h['7_pick'] as num)); // 1000 -> 100 matches
      final a = rateNumbers(picks: 600, wins: 330, totalPicks: totalPicks);
      expect(a.winRate, 55.0);
      expect(a.pickRate, 600.0); // 600 picks in 100 matches
      expect(a.tier, 'S');

      final b = rateNumbers(picks: 300, wins: 141, totalPicks: totalPicks);
      expect(b.winRate, 47.0);
      expect(b.tier, 'C');

      final c = rateNumbers(picks: 100, wins: 49, totalPicks: totalPicks);
      expect(c.winRate, 49.0);
      expect(c.pickRate, 100.0);
      expect(c.tier, 'B');
    });

    test('no picks gives null numbers instead of dividing by zero', () {
      final n = rateNumbers(picks: 0, wins: 0, totalPicks: 0);
      expect(n.winRate, isNull);
      expect(n.pickRate, isNull);
      expect(n.tier, isNull);
    });

    test('tier thresholds', () {
      expect(tierForWinRate(53.0), 'S');
      expect(tierForWinRate(52.9), 'A');
      expect(tierForWinRate(50.0), 'A');
      expect(tierForWinRate(48.0), 'B');
      expect(tierForWinRate(47.9), 'C');
    });
  });

  group('winRateDelta', () {
    test('days 3-5 minus days 0-2, rounded to 0.1', () {
      // Days 0-2: 150/300 = 50%. Days 3-5: 165/300 = 55%. Day 6 (unfinished) is ignored.
      expect(winRateDelta([100, 100, 100, 100, 100, 100, 7], [50, 50, 50, 55, 55, 55, 7]), 5.0);
    });

    test('real WK trends', () {
      final picks = [80746, 89163, 92698, 78842, 77293, 73526, 21335];
      final wins = [44374, 48950, 51026, 43417, 42508, 40881, 11735];
      expect(winRateDelta(picks, wins), closeTo(0.2, 0.05));
    });

    test('a window without picks gives null', () {
      expect(winRateDelta([0, 0, 0, 100, 100, 100, 0], [0, 0, 0, 50, 50, 50, 0]), isNull);
      expect(winRateDelta([100, 100, 100, 0, 0, 0, 0], [50, 50, 50, 0, 0, 0, 0]), isNull);
    });

    test('zeros on some days are fine', () {
      expect(winRateDelta([0, 100, 0, 0, 0, 200, 0], [0, 50, 0, 0, 0, 110, 0]), 5.0);
    });

    test('missing or short trends give null', () {
      expect(winRateDelta(null, [1, 2, 3, 4, 5, 6]), isNull);
      expect(winRateDelta([1, 2, 3], [1, 2, 3]), isNull);
    });
  });
}
