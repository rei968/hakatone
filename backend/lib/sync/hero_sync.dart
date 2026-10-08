import 'dart:async';

import 'package:backend/ai/hero_analyzer.dart';
import 'package:backend/db/app_database.dart';
import 'package:backend/meta/hero_stats.dart';
import 'package:backend/opendota/opendota_client.dart';

const _steamCdn = 'https://cdn.cloudflare.steamstatic.com';

typedef SyncResult = ({DateTime syncedAt, int heroesUpdated});

/// Pulls hero stats from OpenDota into the heroes table and refreshes AI builds for demo heroes.
class HeroSync {
  HeroSync(this._db, this._openDota, {this._analyzer});

  /// Heroes shown in the demo (Pudge, Juggernaut, Invoker): their AI builds are prepared ahead.
  static const demoHeroIds = [14, 8, 74];

  final AppDatabase _db;
  final OpenDotaClient _openDota;
  final HeroAnalyzer? _analyzer;
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
    await _refreshPatch();
    await _refreshDemoAnalyses();
    return (syncedAt: DateTime.now().toUtc(), heroesUpdated: updated);
  }

  /// A failed request keeps the previous patch (or the seed value before the first success).
  Future<void> _refreshPatch() async {
    try {
      _db.savePatch(await _openDota.latestPatch());
    } catch (e) {
      print('sync: patch not updated, keeping the previous one: $e');
    }
  }

  /// A failed analysis keeps the previous build (seed or earlier AI result) and doesn't fail the sync.
  Future<void> _refreshDemoAnalyses() async {
    if (_analyzer == null) return;
    for (final id in demoHeroIds) {
      try {
        await _analyzer.analyze(id);
        print('sync: AI build refreshed for hero $id');
      } catch (e) {
        print('sync: AI build for hero $id failed, keeping the previous one: $e');
      }
    }
  }
}

Map<String, Object?> _heroFromStats(Map<String, dynamic> h, num totalMatches) {
  final picks = (h['pub_pick'] as num?) ?? 0;
  final numbers = rateNumbers(picks: picks, wins: (h['pub_win'] as num?) ?? 0, totalPicks: totalMatches * 10);
  final img = h['img'] as String?;

  return {
    'id': h['id'],
    'name': h['localized_name'],
    'primary_attr': h['primary_attr'],
    'attack_type': h['attack_type'],
    'win_rate': numbers.winRate,
    'pick_rate': numbers.pickRate,
    'tier': numbers.tier,
    'roles': h['roles'],
    // img comes as "/apps/.../pudge.png?", drop the trailing '?'.
    'avatar_url': img == null ? null : '$_steamCdn${img.replaceFirst(RegExp(r'\?$'), '')}',
    'stats': _levelOneStats(h),
    'matches': picks.toInt(),
    'win_rate_delta': winRateDelta(h['pub_pick_trend'] as List?, h['pub_win_trend'] as List?),
    'rank_stats': rankStatsFromHeroStats(h),
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
    'base_armor': round1(stat('base_armor') + agi / 6),
    'movement_speed': stat('move_speed'),
    'damage': '${stat('base_attack_min') + damageBonus}-${stat('base_attack_max') + damageBonus}',
  };
}

