import 'dart:async';

import 'package:backend/db/app_database.dart';
import 'package:backend/opendota/opendota_client.dart';

const _steamCdn = 'https://cdn.cloudflare.steamstatic.com';

typedef SyncResult = ({DateTime syncedAt, int heroesUpdated});

/// Tier is computed from win rate in code, not by AI.
String tierForWinRate(double winRate) => switch (winRate) {
      >= 53 => 'S',
      >= 50 => 'A',
      >= 48 => 'B',
      _ => 'C',
    };

/// Pulls hero stats from OpenDota into the heroes table.
class HeroSync {
  HeroSync(this._db, this._openDota);

  final AppDatabase _db;
  final OpenDotaClient _openDota;
  Future<SyncResult>? _running;

  /// Runs one sync. Throws on failure, and the DB is left untouched in that case.
  /// Concurrent callers (timer + /admin/sync) share the same in-flight run.
  Future<SyncResult> run() => _running ??= _run().whenComplete(() => _running = null);

  /// Syncs once now in the background, then every [interval].
  void startPeriodic(Duration interval) {
    unawaited(_runLogged());
    Timer.periodic(interval, (_) => _runLogged());
  }

  Future<void> _runLogged() async {
    try {
      final result = await run();
      print('sync: ${result.heroesUpdated} heroes updated');
    } catch (e) {
      print('sync failed, keeping existing data: $e');
    }
  }

  Future<SyncResult> _run() async {
    final stats = await _openDota.heroStats();
    if (stats.isEmpty) throw OpenDotaException('/heroStats returned no heroes');

    // Every match has 10 picks, so total matches = all picks / 10.
    final totalPicks = stats.fold<num>(0, (sum, h) => sum + ((h['pub_pick'] as num?) ?? 0));
    final heroes = [for (final h in stats) _heroFromStats(h, totalPicks / 10)];

    final updated = _db.upsertHeroes(heroes);
    return (syncedAt: DateTime.now().toUtc(), heroesUpdated: updated);
  }
}

Map<String, Object?> _heroFromStats(Map<String, dynamic> h, num totalMatches) {
  final picks = (h['pub_pick'] as num?) ?? 0;
  final wins = (h['pub_win'] as num?) ?? 0;
  final winRate = picks > 0 ? _round1(wins / picks * 100) : null;
  final pickRate = totalMatches > 0 ? _round1(picks / totalMatches * 100) : null;
  final img = h['img'] as String?;

  return {
    'id': h['id'],
    'name': h['localized_name'],
    'primary_attr': h['primary_attr'],
    'attack_type': h['attack_type'],
    'win_rate': winRate,
    'pick_rate': pickRate,
    'tier': winRate == null ? null : tierForWinRate(winRate),
    'roles': h['roles'],
    // img comes as "/apps/.../pudge.png?", drop the trailing '?'.
    'avatar_url': img == null ? null : '$_steamCdn${img.replaceFirst(RegExp(r'\?$'), '')}',
    'stats': _levelOneStats(h),
  };
}

/// Level-1 stats in the seed's format: 22 HP per STR, 12 mana per INT, 1/6 armor per AGI.
/// Damage gets the primary attribute; universal heroes get 0.45 per point of every attribute.
Map<String, Object?> _levelOneStats(Map<String, dynamic> h) {
  num stat(String key) => (h[key] as num?) ?? 0;
  final str = stat('base_str'), agi = stat('base_agi'), intel = stat('base_int');
  final damageBonus = switch (h['primary_attr']) {
    'str' => str,
    'agi' => agi,
    'int' => intel,
    _ => (str + agi + intel) * 0.45,
  }.floor();

  return {
    'base_hp': (stat('base_health') + str * 22).round(),
    'base_mana': (stat('base_mana') + intel * 12).round(),
    'base_armor': _round1(stat('base_armor') + agi / 6),
    'movement_speed': stat('move_speed'),
    'damage': '${stat('base_attack_min') + damageBonus}-${stat('base_attack_max') + damageBonus}',
  };
}

double _round1(num value) => (value * 10).round() / 10;
