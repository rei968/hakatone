import 'package:flutter/foundation.dart';

/// Профіль гравця з OpenDota (`GET /players/{account_id}` і `/wl`).
@immutable
class PlayerProfile {
  const PlayerProfile({
    required this.accountId,
    required this.name,
    this.avatarUrl,
    this.rankTier,
    this.leaderboardRank,
    this.wins = 0,
    this.losses = 0,
  });

  factory PlayerProfile.fromOpenDota(int accountId, Map<String, dynamic> player, Map<String, dynamic>? wl) {
    final profile = player['profile'] as Map<String, dynamic>? ?? const {};
    return PlayerProfile(
      accountId: accountId,
      name: (profile['personaname'] as String?)?.trim().isNotEmpty == true
          ? (profile['personaname'] as String).trim()
          : 'Гравець $accountId',
      avatarUrl: profile['avatarfull'] as String? ?? profile['avatarmedium'] as String?,
      rankTier: (player['rank_tier'] as num?)?.toInt(),
      leaderboardRank: (player['leaderboard_rank'] as num?)?.toInt(),
      wins: (wl?['win'] as num?)?.toInt() ?? 0,
      losses: (wl?['lose'] as num?)?.toInt() ?? 0,
    );
  }

  factory PlayerProfile.fromJson(Map<String, dynamic> json) => PlayerProfile(
        accountId: json['account_id'] as int,
        name: json['name'] as String,
        avatarUrl: json['avatar_url'] as String?,
        rankTier: json['rank_tier'] as int?,
        leaderboardRank: json['leaderboard_rank'] as int?,
        wins: json['wins'] as int? ?? 0,
        losses: json['losses'] as int? ?? 0,
      );

  final int accountId;
  final String name;
  final String? avatarUrl;

  /// Десятки — медаль 1–8 (Herald…Immortal), одиниці — зірки.
  final int? rankTier;
  final int? leaderboardRank;
  final int wins;
  final int losses;

  int get totalMatches => wins + losses;

  static const _medals = ['Herald', 'Guardian', 'Crusader', 'Archon', 'Legend', 'Ancient', 'Divine', 'Immortal'];

  /// «Divine 3», «Immortal #120» або `null`, якщо ранг не відкалібровано чи прихований.
  String? get medal {
    final tier = rankTier;
    if (tier == null || tier < 10) return null;
    final medal = tier ~/ 10, stars = tier % 10;
    if (medal < 1 || medal > _medals.length) return null;
    if (medal == 8) return leaderboardRank == null ? 'Immortal' : 'Immortal #$leaderboardRank';
    return stars == 0 ? _medals[medal - 1] : '${_medals[medal - 1]} $stars';
  }

  Map<String, dynamic> toJson() => {
        'account_id': accountId,
        'name': name,
        'avatar_url': avatarUrl,
        'rank_tier': rankTier,
        'leaderboard_rank': leaderboardRank,
        'wins': wins,
        'losses': losses,
      };
}

/// Матч гравця з `GET /players/{account_id}/matches`.
@immutable
class PlayerMatch {
  const PlayerMatch({
    required this.matchId,
    required this.heroId,
    required this.won,
    required this.kills,
    required this.deaths,
    required this.assists,
    required this.duration,
    required this.startTime,
    this.gpm,
    this.xpm,
  });

  factory PlayerMatch.fromOpenDota(Map<String, dynamic> json) {
    final radiant = ((json['player_slot'] as num?)?.toInt() ?? 0) < 128;
    return PlayerMatch(
      matchId: (json['match_id'] as num).toInt(),
      heroId: (json['hero_id'] as num?)?.toInt() ?? 0,
      won: radiant == (json['radiant_win'] == true),
      kills: (json['kills'] as num?)?.toInt() ?? 0,
      deaths: (json['deaths'] as num?)?.toInt() ?? 0,
      assists: (json['assists'] as num?)?.toInt() ?? 0,
      duration: Duration(seconds: (json['duration'] as num?)?.toInt() ?? 0),
      startTime: DateTime.fromMillisecondsSinceEpoch(((json['start_time'] as num?)?.toInt() ?? 0) * 1000, isUtc: true),
      gpm: (json['gold_per_min'] as num?)?.toInt(),
      xpm: (json['xp_per_min'] as num?)?.toInt(),
    );
  }

  final int matchId;
  final int heroId;
  final bool won;
  final int kills;
  final int deaths;
  final int assists;
  final Duration duration;
  final DateTime startTime;
  final int? gpm;
  final int? xpm;

  /// У форматі OpenDota, щоб кеш читався тим самим кодом.
  Map<String, dynamic> toJson() => {
        'match_id': matchId,
        'hero_id': heroId,
        'player_slot': 0,
        'radiant_win': won,
        'kills': kills,
        'deaths': deaths,
        'assists': assists,
        'duration': duration.inSeconds,
        'start_time': startTime.millisecondsSinceEpoch ~/ 1000,
        'gold_per_min': gpm,
        'xp_per_min': xpm,
      };
}

/// Період статистики в профілі.
enum ProfilePeriod {
  last25('25 ігор'),
  last100('100'),
  week('Тиждень'),
  month('Місяць'),
  patch('Патч');

  const ProfilePeriod(this.label);

  final String label;

  String get caption => switch (this) {
        last25 => 'останні 25 ігор',
        last100 => 'останні 100 ігор',
        week => 'останні 7 днів',
        month => 'останні 30 днів',
        patch => 'поточний патч',
      };
}

/// Як гравець грав на одному герої за період.
@immutable
class HeroUsage {
  const HeroUsage({required this.heroId, required this.games, required this.wins});

  final int heroId;
  final int games;
  final int wins;

  double get winRate => games == 0 ? 0 : wins / games * 100;
}

/// Підсумок періоду: усе рахується на пристрої зі списку матчів.
@immutable
class ProfileSummary {
  const ProfileSummary._({
    required this.games,
    required this.wins,
    required this.kills,
    required this.deaths,
    required this.assists,
    required this.gpm,
    required this.xpm,
    required this.heroPool,
  });

  factory ProfileSummary.of(List<PlayerMatch> matches) {
    final games = matches.length;
    double avg(num Function(PlayerMatch m) pick) =>
        games == 0 ? 0 : matches.fold<num>(0, (sum, m) => sum + pick(m)) / games;
    double? avgOf(int? Function(PlayerMatch m) pick) {
      final values = matches.map(pick).whereType<int>().toList();
      return values.isEmpty ? null : values.reduce((a, b) => a + b) / values.length;
    }

    final usage = <int, (int, int)>{};
    for (final m in matches) {
      final (g, w) = usage[m.heroId] ?? (0, 0);
      usage[m.heroId] = (g + 1, w + (m.won ? 1 : 0));
    }
    final pool = [
      for (final MapEntry(key: heroId, value: (games, wins)) in usage.entries)
        HeroUsage(heroId: heroId, games: games, wins: wins),
    ]..sort((a, b) => b.games != a.games ? b.games.compareTo(a.games) : b.winRate.compareTo(a.winRate));

    return ProfileSummary._(
      games: games,
      wins: matches.where((m) => m.won).length,
      kills: avg((m) => m.kills),
      deaths: avg((m) => m.deaths),
      assists: avg((m) => m.assists),
      gpm: avgOf((m) => m.gpm),
      xpm: avgOf((m) => m.xpm),
      heroPool: pool,
    );
  }

  final int games;
  final int wins;
  int get losses => games - wins;
  double get winRate => games == 0 ? 0 : wins / games * 100;

  /// Середні за матч.
  final double kills;
  final double deaths;
  final double assists;

  /// (K + A) / D, смерть мінімум одна.
  double get kda => (kills + assists) / (deaths < 1 ? 1 : deaths);
  final double? gpm;
  final double? xpm;

  /// Від найчастішого героя.
  final List<HeroUsage> heroPool;
}
