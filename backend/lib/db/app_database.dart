import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import 'database_files.dart';

/// SQLite access. Arrays and objects are stored as JSON text (see schema.sql).
class AppDatabase {
  AppDatabase._(this._db);

  final Database _db;

  /// Opens (or creates) the DB file, applies schema.sql and seeds an empty DB from dota2.json.
  factory AppDatabase.open(String path) {
    final db = AppDatabase._(sqlite3.open(path));
    db._db.execute(findDatabaseFile('schema.sql').readAsStringSync());
    db._seedIfEmpty();
    return db;
  }

  /// Heroes for /api/meta/dota, best win rate first.
  List<Map<String, Object?>> metaHeroes() => [
        for (final row in _db.select('SELECT * FROM heroes ORDER BY win_rate DESC')) _metaHero(row),
      ];

  /// Time of the latest hero write as ISO-8601 UTC, or null when there are no heroes.
  String? lastUpdated() {
    final value = _db.select('SELECT MAX(created_at) AS t FROM heroes').first['t'] as String?;
    // CURRENT_TIMESTAMP is UTC in 'YYYY-MM-DD HH:MM:SS' format.
    return value == null ? null : DateTime.parse('${value}Z').toIso8601String();
  }

  /// Full hero card (HeroWithBuild), or null when the hero is not in the DB.
  Map<String, Object?>? heroWithBuild(int id) {
    final rows = _db.select('SELECT * FROM heroes WHERE id = ?', [id]);
    if (rows.isEmpty) return null;
    final hero = rows.first;

    final abilities = _db.select(
      'SELECT id, name, description, cooldown, mana_cost, icon_url, slot_order '
      'FROM abilities WHERE hero_id = ? ORDER BY slot_order',
      [id],
    );
    final builds = _db.select(
      'SELECT skill_order, core_items, tactics FROM ai_builds WHERE hero_id = ?',
      [id],
    );

    return {
      ..._metaHero(hero),
      'attack_type': hero['attack_type'],
      'bio': hero['bio'],
      'stats': _decodeJson(hero['stats']),
      'abilities': [for (final a in abilities) {...a}],
      'ai_build': builds.isEmpty
          ? null
          : {
              'skill_order': _decodeJson(builds.first['skill_order']),
              'core_items': _decodeJson(builds.first['core_items']),
              'tactics': builds.first['tactics'],
            },
    };
  }

  Map<String, Object?> _metaHero(Row row) => {
        'id': row['id'],
        'name': row['name'],
        'win_rate': row['win_rate'],
        'pick_rate': row['pick_rate'],
        'primary_attr': row['primary_attr'],
        'roles': _decodeJson(row['roles']),
        'avatar_url': row['avatar_url'],
        'tier': row['tier'],
        'ai_summary': row['ai_summary'],
      };

  void _seedIfEmpty() {
    final count = _db.select('SELECT COUNT(*) AS n FROM heroes').first['n'] as int;
    if (count > 0) return;

    final seed = jsonDecode(findDatabaseFile('seeds/dota2.json').readAsStringSync()) as Map<String, dynamic>;
    final heroes = (seed['heroes'] as List).cast<Map<String, dynamic>>();

    _transaction(() {
      for (final h in heroes) {
        _db.execute(
          'INSERT INTO heroes (id, name, primary_attr, attack_type, win_rate, pick_rate, tier, '
          'roles, avatar_url, bio, stats, ai_summary) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            h['id'], h['name'], h['primary_attr'], h['attack_type'], h['win_rate'], h['pick_rate'],
            h['tier'], _encodeJson(h['roles']), h['avatar_url'], h['bio'], _encodeJson(h['stats']),
            h['ai_summary'],
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
            'INSERT INTO ai_builds (hero_id, skill_order, core_items, tactics) VALUES (?, ?, ?, ?)',
            [h['id'], _encodeJson(build['skill_order']), _encodeJson(build['core_items']), build['tactics']],
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
