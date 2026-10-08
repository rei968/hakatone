import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import 'package:backend/meta/hero_stats.dart';

import 'database_files.dart';

/// SQLite access. Arrays and objects are stored as JSON text (see schema.sql).
class AppDatabase {
  AppDatabase._(this._db);

  final Database _db;

  /// Columns added after the first release. CREATE TABLE IF NOT EXISTS doesn't touch an
  /// existing table, so older DB files get them through ALTER TABLE.
  static const _addedColumns = {
    'heroes': {'matches': 'INTEGER', 'win_rate_delta': 'REAL', 'rank_stats': 'TEXT'},
    'ai_builds': {'talents': 'TEXT', 'item_timings': 'TEXT', 'situational_items': 'TEXT'},
  };

  /// Opens (or creates) the DB file, applies schema.sql and migrations, seeds an empty DB from dota2.json.
  factory AppDatabase.open(String path) {
    final db = AppDatabase._(sqlite3.open(path));
    db._db.execute(findDatabaseFile('schema.sql').readAsStringSync());
    db._migrate();
    db._seedIfEmpty();
    return db;
  }

  void close() => _db.close();

  void _migrate() {
    for (final MapEntry(key: table, value: columns) in _addedColumns.entries) {
      final existing = {for (final row in _db.select('PRAGMA table_info($table)')) row['name'] as String};
      for (final MapEntry(key: column, value: type) in columns.entries) {
        if (!existing.contains(column)) _db.execute('ALTER TABLE $table ADD COLUMN $column $type');
      }
    }
  }

  /// Heroes for /api/meta/dota in [bracket] (null = all ranks), best win rate first,
  /// and the number of matches in that sample.
  ({List<Map<String, Object?>> heroes, int totalMatches}) metaHeroes({int? bracket}) {
    final rows = _db.select('SELECT * FROM heroes');
    final totalPicks = _totalPicks(rows, bracket);
    final heroes = [for (final row in rows) _metaHero(row, bracket: bracket, totalPicks: totalPicks)]
      ..sort((a, b) => ((b['win_rate'] as num?) ?? -1).compareTo((a['win_rate'] as num?) ?? -1));
    return (heroes: heroes, totalMatches: (totalPicks / 10).round());
  }

  /// Time of the latest hero write as ISO-8601 UTC, or null when there are no heroes.
  String? lastUpdated() {
    final value = _db.select('SELECT MAX(created_at) AS t FROM heroes').first['t'] as String?;
    // CURRENT_TIMESTAMP is UTC in 'YYYY-MM-DD HH:MM:SS' format.
    return value == null ? null : DateTime.parse('${value}Z').toIso8601String();
  }

  /// Latest patch saved by sync, or null before the first successful sync.
  String? patch() => _db.select("SELECT value FROM app_meta WHERE key = 'patch'").firstOrNull?['value'] as String?;

  void savePatch(String patch) => _db.execute(
        "INSERT INTO app_meta (key, value) VALUES ('patch', ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value",
        [patch],
      );

  /// Full hero card (HeroWithBuild) with numbers for [bracket], or null when the hero is not in the DB.
  Map<String, Object?>? heroWithBuild(int id, {int? bracket}) {
    final rows = _db.select('SELECT * FROM heroes WHERE id = ?', [id]);
    if (rows.isEmpty) return null;
    final hero = rows.first;
    final totalPicks = _totalPicks(_db.select('SELECT matches, rank_stats FROM heroes'), bracket);

    final abilities = _db.select(
      'SELECT id, name, description, cooldown, mana_cost, icon_url, slot_order '
      'FROM abilities WHERE hero_id = ? ORDER BY slot_order',
      [id],
    );
    final build = _db.select('SELECT * FROM ai_builds WHERE hero_id = ?', [id]).firstOrNull;

    return {
      ..._metaHero(hero, bracket: bracket, totalPicks: totalPicks),
      'bio': hero['bio'],
      'stats': _decodeJson(hero['stats']),
      'abilities': [for (final a in abilities) {...a}],
      'ai_build': build == null
          ? null
          : {
              'skill_order': _decodeJson(build['skill_order']),
              'talents': _decodeJson(build['talents']),
              'core_items': _decodeJson(build['core_items']),
              'item_timings': _decodeJson(build['item_timings']),
              'situational_items': _decodeJson(build['situational_items']),
              'tactics': build['tactics'],
            },
    };
  }

  /// Inserts or updates OpenDota heroes in one transaction and returns how many were written.
  /// Fields OpenDota doesn't provide (bio, ai_summary) and abilities/ai_builds are kept.
  int upsertHeroes(List<Map<String, Object?>> heroes) {
    _transaction(() {
      for (final h in heroes) {
        _db.execute(
          'INSERT INTO heroes (id, name, primary_attr, attack_type, win_rate, pick_rate, tier, '
          'roles, avatar_url, stats, matches, win_rate_delta, rank_stats) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?) '
          'ON CONFLICT(id) DO UPDATE SET name = excluded.name, primary_attr = excluded.primary_attr, '
          'attack_type = excluded.attack_type, win_rate = excluded.win_rate, '
          'pick_rate = excluded.pick_rate, tier = excluded.tier, roles = excluded.roles, '
          'avatar_url = excluded.avatar_url, stats = excluded.stats, matches = excluded.matches, '
          'win_rate_delta = excluded.win_rate_delta, rank_stats = excluded.rank_stats, '
          // No updated_at column: created_at doubles as the last-sync time shown in /api/meta/dota.
          'created_at = CURRENT_TIMESTAMP',
          [
            h['id'], h['name'], h['primary_attr'], h['attack_type'], h['win_rate'], h['pick_rate'],
            h['tier'], _encodeJson(h['roles']), h['avatar_url'], _encodeJson(h['stats']),
            h['matches'], h['win_rate_delta'], _encodeJson(h['rank_stats']),
          ],
        );
      }
    });
    return heroes.length;
  }

  /// Hero id -> name, e.g. to label matchups.
  Map<int, String> heroNames() => {
        for (final row in _db.select('SELECT id, name FROM heroes')) row['id'] as int: row['name'] as String,
      };

  /// Stores an AI analysis: the summary goes to heroes, the build to ai_builds (one per hero).
  void saveAnalysis(
    int heroId, {
    required String summary,
    required List<String> skillOrder,
    required List<Map<String, Object>> talents,
    required List<String> coreItems,
    required Map<String, int> itemTimings,
    required List<Map<String, String>> situationalItems,
    required String tactics,
  }) {
    _transaction(() {
      _db.execute('UPDATE heroes SET ai_summary = ? WHERE id = ?', [summary, heroId]);
      _db.execute(
        'INSERT INTO ai_builds (hero_id, skill_order, talents, core_items, item_timings, situational_items, tactics) '
        'VALUES (?, ?, ?, ?, ?, ?, ?) '
        'ON CONFLICT(hero_id) DO UPDATE SET skill_order = excluded.skill_order, talents = excluded.talents, '
        'core_items = excluded.core_items, item_timings = excluded.item_timings, '
        'situational_items = excluded.situational_items, tactics = excluded.tactics, '
        'updated_at = CURRENT_TIMESTAMP',
        [
          heroId, jsonEncode(skillOrder), jsonEncode(talents), jsonEncode(coreItems),
          jsonEncode(itemTimings), jsonEncode(situationalItems), tactics,
        ],
      );
    });
  }

  ({String id, String email, String passwordHash})? findUserByEmail(String email) {
    final rows = _db.select('SELECT id, email, password_hash FROM users WHERE email = ?', [email]);
    if (rows.isEmpty) return null;
    final row = rows.first;
    return (id: row['id'] as String, email: row['email'] as String, passwordHash: row['password_hash'] as String);
  }

  void createUser({required String id, required String email, required String passwordHash}) =>
      _db.execute('INSERT INTO users (id, email, password_hash) VALUES (?, ?, ?)', [id, email, passwordHash]);

  /// All-rank numbers come from the stored columns. For a bracket they are computed from
  /// rank_stats; a hero without rank_stats (seeded, never synced) keeps its all-rank numbers.
  Map<String, Object?> _metaHero(Row row, {required int? bracket, required num totalPicks}) {
    var winRate = row['win_rate'] as num?, pickRate = row['pick_rate'] as num?;
    var tier = row['tier'] as String?;
    var matches = row['matches'] as int?;

    final counts = bracket == null ? null : _bracketCounts(row, bracket);
    if (counts != null) {
      final numbers = rateNumbers(picks: counts.pick, wins: counts.win, totalPicks: totalPicks);
      (winRate, pickRate, tier, matches) = (numbers.winRate, numbers.pickRate, numbers.tier, counts.pick);
    }

    return {
      'id': row['id'],
      'name': row['name'],
      'win_rate': winRate,
      'pick_rate': pickRate,
      'primary_attr': row['primary_attr'],
      'attack_type': row['attack_type'],
      'roles': _decodeJson(row['roles']),
      'avatar_url': row['avatar_url'],
      'tier': tier,
      'ai_summary': row['ai_summary'],
      'matches': matches,
      // OpenDota has no per-rank trends, so the weekly change is always for all ranks.
      'win_rate_delta': row['win_rate_delta'],
    };
  }

  ({int pick, int win})? _bracketCounts(Row row, int bracket) {
    final stats = _decodeJson(row['rank_stats']) as Map<String, dynamic>?;
    final entry = stats?['$bracket'] as Map<String, dynamic>?;
    if (entry == null) return null;
    return (pick: (entry['pick'] as num?)?.toInt() ?? 0, win: (entry['win'] as num?)?.toInt() ?? 0);
  }

  /// Sum of picks in the sample: `matches` for all ranks, the bracket's picks otherwise
  /// (falling back to `matches` for heroes without rank_stats, as in [_metaHero]).
  num _totalPicks(ResultSet rows, int? bracket) => rows.fold<num>(0, (sum, row) {
        final counts = bracket == null ? null : _bracketCounts(row, bracket);
        return sum + (counts?.pick ?? (row['matches'] as int?) ?? 0);
      });

  void _seedIfEmpty() {
    final count = _db.select('SELECT COUNT(*) AS n FROM heroes').first['n'] as int;
    if (count > 0) return;

    final seed = jsonDecode(findDatabaseFile('seeds/dota2.json').readAsStringSync()) as Map<String, dynamic>;
    final heroes = (seed['heroes'] as List).cast<Map<String, dynamic>>();

    _transaction(() {
      for (final h in heroes) {
        _db.execute(
          'INSERT INTO heroes (id, name, primary_attr, attack_type, win_rate, pick_rate, tier, '
          'roles, avatar_url, bio, stats, ai_summary, matches, win_rate_delta) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            h['id'], h['name'], h['primary_attr'], h['attack_type'], h['win_rate'], h['pick_rate'],
            h['tier'], _encodeJson(h['roles']), h['avatar_url'], h['bio'], _encodeJson(h['stats']),
            h['ai_summary'], h['matches'], h['win_rate_delta'],
          ],
        );

        final abilities = (h['abilities'] as List? ?? const []).cast<Map<String, dynamic>>();
        for (final a in abilities) {
          _db.execute(
            'INSERT INTO abilities (id, hero_id, name, description, cooldown, mana_cost, icon_url, slot_order) '
            'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
            [
              a['id'], h['id'], a['name'], a['description'], a['cooldown'], a['mana_cost'],
              a['icon_url'], a['slot_order'],
            ],
          );
        }

        final build = h['ai_build'] as Map<String, dynamic>?;
        if (build != null) {
          _db.execute(
            'INSERT INTO ai_builds (hero_id, skill_order, talents, core_items, item_timings, situational_items, tactics) '
            'VALUES (?, ?, ?, ?, ?, ?, ?)',
            [
              h['id'], _encodeJson(build['skill_order']), _encodeJson(build['talents']),
              _encodeJson(build['core_items']), _encodeJson(build['item_timings']),
              _encodeJson(build['situational_items']), build['tactics'],
            ],
          );
        }
      }
    });
    print('DB seeded from dota2.json: ${heroes.length} heroes');
  }

  void _transaction(void Function() body) {
    _db.execute('BEGIN');
    try {
      body();
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }
}

Object? _decodeJson(Object? value) => value == null ? null : jsonDecode(value as String);

String? _encodeJson(Object? value) => value == null ? null : jsonEncode(value);
