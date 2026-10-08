/// Pure math behind /api/meta/dota: ranks, rates, tiers and the weekly win-rate change.
library;

/// `?rank=` values mapped to OpenDota /heroStats brackets (`N_pick`/`N_win`).
/// Bracket 8 (Immortal) is empty in OpenDota, so `divine` means Divine and above.
const rankBrackets = {
  'herald': 1,
  'guardian': 2,
  'crusader': 3,
  'archon': 4,
  'legend': 5,
  'ancient': 6,
  'divine': 7,
};

class InvalidRankException implements Exception {
  InvalidRankException(this.value);

  final String value;

  @override
  String toString() => 'InvalidRankException($value)';
}

/// Bracket 1..7 for a `?rank=` value, or null for all ranks (missing, empty or `all`).
/// Throws [InvalidRankException] for anything else.
int? parseRank(String? value) {
  if (value == null || value.isEmpty || value == 'all') return null;
  return rankBrackets[value] ?? (throw InvalidRankException(value));
}

/// The `rank` field of the meta response: the parameter value or `all`.
String rankName(int? bracket) =>
    bracket == null ? 'all' : rankBrackets.entries.firstWhere((e) => e.value == bracket).key;

/// Tier is computed from win rate in code, not by AI.
String tierForWinRate(double winRate) => switch (winRate) {
      >= 53 => 'S',
      >= 50 => 'A',
      >= 48 => 'B',
      _ => 'C',
    };

double round1(num value) => (value * 10).round() / 10;

/// Win rate, pick rate and tier of one hero in a sample with [totalPicks] picks in total.
/// Every match has 10 picks, so pick rate = picks / (totalPicks / 10).
({double? winRate, double? pickRate, String? tier}) rateNumbers({
  required num picks,
  required num wins,
  required num totalPicks,
}) {
  final winRate = picks > 0 ? round1(wins / picks * 100) : null;
  final pickRate = totalPicks > 0 ? round1(picks / (totalPicks / 10) * 100) : null;
  return (winRate: winRate, pickRate: pickRate, tier: winRate == null ? null : tierForWinRate(winRate));
}

/// Raw per-bracket counts from a /heroStats entry, stored as heroes.rank_stats:
/// `{"1": {"pick": 11964, "win": 6073}, ..., "7": {...}}`.
Map<String, Map<String, int>> rankStatsFromHeroStats(Map<String, dynamic> h) => {
      for (final bracket in rankBrackets.values)
        '$bracket': {
          'pick': (h['${bracket}_pick'] as num?)?.toInt() ?? 0,
          'win': (h['${bracket}_win'] as num?)?.toInt() ?? 0,
        },
    };

/// Win-rate change over the week in percentage points from `pub_pick_trend`/`pub_win_trend`
/// (7 daily values, the last one is the unfinished current day): win rate of days 3-5 minus
/// win rate of days 0-2. Null when the trends are missing or a window has no picks.
double? winRateDelta(List<Object?>? pickTrend, List<Object?>? winTrend) {
  if (pickTrend == null || winTrend == null || pickTrend.length < 6 || winTrend.length < 6) return null;

  num sum(List<Object?> values, int from) => [for (var i = from; i < from + 3; i++) (values[i] as num?) ?? 0]
      .fold<num>(0, (a, b) => a + b);

  final earlyPicks = sum(pickTrend, 0), latePicks = sum(pickTrend, 3);
  if (earlyPicks <= 0 || latePicks <= 0) return null;
  final early = sum(winTrend, 0) / earlyPicks * 100;
  final late = sum(winTrend, 3) / latePicks * 100;
  return round1(late - early);
}
