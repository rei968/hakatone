import 'dart:convert';
import 'dart:io';
import 'package:sqlite3/sqlite3.dart';

late final Database db;

void initDatabase() {
  db = sqlite3.open('hackathon.db');
  
  // Обов'язково вмикаємо підтримку зовнішніх ключів для кожного з'єднання
  db.execute('PRAGMA foreign_keys = ON;');

  _createTables();
  print('✅ [БД]: Схема ERD підключена!');
  seedData();
}

void _createTables() {
  // Перевірка наявності schema.sql як єдиного джерела правди (Single Source of Truth)
  final schemaFile = File('database/schema.sql');
  if (schemaFile.existsSync()) {
    final schemaSql = schemaFile.readAsStringSync();
    db.execute(schemaSql);
  } else {
    // Резервне створення таблиць строго за актуальною ERD
    db.execute('''
      CREATE TABLE IF NOT EXISTS heroes (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        primary_attr TEXT,
        win_rate REAL,
        pick_rate REAL,
        tier TEXT,
        roles TEXT,
        avatar_url TEXT,
        bio TEXT,
        stats TEXT,
        ai_summary TEXT,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      );

      CREATE TABLE IF NOT EXISTS abilities (
        id TEXT PRIMARY KEY,
        hero_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        description TEXT,
        cooldown TEXT,
        mana_cost TEXT,
        icon_url TEXT,
        slot_order INTEGER,
        FOREIGN KEY (hero_id) REFERENCES heroes(id) ON DELETE CASCADE
      );

      CREATE TABLE IF NOT EXISTS ai_builds (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        hero_id INTEGER UNIQUE NOT NULL,
        skill_order TEXT,
        core_items TEXT,
        tactics TEXT,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (hero_id) REFERENCES heroes(id) ON DELETE CASCADE
      );

      CREATE INDEX IF NOT EXISTS idx_abilities_hero_id ON abilities(hero_id);
      CREATE INDEX IF NOT EXISTS idx_ai_builds_hero_id ON ai_builds(hero_id);
    ''');
  }
}

void seedData() {
  final countResult = db.select('SELECT COUNT(*) as count FROM heroes');
  if ((countResult.first['count'] as int) == 0) {
    // Перевірка наявності dota2.json для первинного заповнення (Seed)
    final dotaJsonFile = File('database/dota2.json');
    
    if (dotaJsonFile.existsSync()) {
      final String content = dotaJsonFile.readAsStringSync();
      final List<dynamic> heroesData = jsonDecode(content) as List<dynamic>;

      final heroStmt = db.prepare('''
        INSERT INTO heroes (id, name, primary_attr, win_rate, pick_rate, tier, roles, avatar_url, bio, stats, ai_summary)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''');

      final abilityStmt = db.prepare('''
        INSERT INTO abilities (id, hero_id, name, description, cooldown, mana_cost, icon_url, slot_order)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ''');

      final buildStmt = db.prepare('''
        INSERT INTO ai_builds (hero_id, skill_order, core_items, tactics)
        VALUES (?, ?, ?, ?)
      ''');

      for (final item in heroesData) {
        final heroMap = item as Map<String, dynamic>;
        
        heroStmt.execute([
          heroMap['id'],
          heroMap['name'],
          heroMap['primary_attr'],
          heroMap['win_rate'],
          heroMap['pick_rate'],
          heroMap['tier'],
          jsonEncode(heroMap['roles'] ?? []),
          heroMap['avatar_url'],
          heroMap['bio'],
          jsonEncode(heroMap['stats'] ?? {}),
          heroMap['ai_summary'],
        ]);

        if (heroMap['abilities'] != null) {
          for (final ab in heroMap['abilities'] as List<dynamic>) {
            final abMap = ab as Map<String, dynamic>;
            abilityStmt.execute([
              abMap['id'],
              heroMap['id'],
              abMap['name'],
              abMap['description'],
              abMap['cooldown'],
              abMap['mana_cost'],
              abMap['icon_url'],
              abMap['slot_order'],
            ]);
          }
        }

        if (heroMap['ai_build'] != null) {
          final buildMap = heroMap['ai_build'] as Map<String, dynamic>;
          buildStmt.execute([
            heroMap['id'],
            jsonEncode(buildMap['skill_order'] ?? []),
            jsonEncode(buildMap['core_items'] ?? []),
            buildMap['tactics'],
          ]);
        }
      }

      heroStmt.dispose();
      abilityStmt.dispose();
      buildStmt.dispose();

    } else {
      // Резервний фалбек-значення за відсутності json (Pudge з id = 14 OpenDota)
      db.execute('''
        INSERT INTO heroes (id, name, primary_attr, win_rate, pick_rate, tier, roles, avatar_url, bio, stats, ai_summary)
        VALUES (
          14, 
          'Pudge', 
          'str', 
          51.5, 
          25.4, 
          'S', 
          '["Durable", "Disabler", "Initiator"]', 
          'https://cdn.cloudflare.steamstatic.com/apps/dota2/images/dota_react/heroes/pudge.png',
          'Thick butcher...',
          '{"base_hp": 620, "base_mana": 267}',
          'Strong ganker with Meat Hook.'
        )
      ''');

      db.execute('''
        INSERT INTO abilities (id, hero_id, name, description, cooldown, mana_cost, icon_url, slot_order)
        VALUES ('pudge_meat_hook', 14, 'Meat Hook', 'Launches a bloody hook at a unit or location.', '18/16/14/12', '110', 'https://cdn.cloudflare.steamstatic.com/apps/dota2/images/dota_react/abilities/pudge_meat_hook.png', 1)
      ''');

      db.execute('''
        INSERT INTO ai_builds (hero_id, skill_order, core_items, tactics)
        VALUES (14, '["Meat Hook", "Rot", "Meat Hook", "Flesh Heap", "Meat Hook", "Dismember"]', '["Phase Boots", "Blink Dagger", "Aether Lens"]', 'Hook enemies into tower range.')
      ''');
    }

    print('🌱 [Seed]: Базу даних наповнено згідно з ERD!');
  }
}

/// Повертає список героїв із вкладеними об'єктами відповідно до openapi.yaml
String getHeroesWithBuildsJson() {
  final ResultSet heroResults = db.select('SELECT * FROM heroes');

  final list = heroResults.map((heroRow) {
    final heroId = heroRow['id'] as int;

    // Отримання abilities для героя
    final ResultSet abilityResults = db.select(
      'SELECT id, name, description, cooldown, mana_cost, icon_url, slot_order FROM abilities WHERE hero_id = ? ORDER BY slot_order ASC',
      [heroId],
    );

    final abilities = abilityResults.map((abRow) => {
      'id': abRow['id'],
      'name': abRow['name'],
      'description': abRow['description'],
      'cooldown': abRow['cooldown'],
      'mana_cost': abRow['mana_cost'],
      'icon_url': abRow['icon_url'],
      'slot_order': abRow['slot_order'],
    }).toList();

    // Отримання ai_build для героя
    final ResultSet buildResults = db.select(
      'SELECT skill_order, core_items, tactics, updated_at FROM ai_builds WHERE hero_id = ? LIMIT 1',
      [heroId],
    );

    Map<String, dynamic>? aiBuild;
    if (buildResults.isNotEmpty) {
      final buildRow = buildResults.first;
      aiBuild = {
        'skill_order': buildRow['skill_order'] != null ? jsonDecode(buildRow['skill_order'] as String) : [],
        'core_items': buildRow['core_items'] != null ? jsonDecode(buildRow['core_items'] as String) : [],
        'tactics': buildRow['tactics'],
        'updated_at': buildRow['updated_at'],
      };
    }

    return {
      'id': heroRow['id'],
      'name': heroRow['name'],
      'primary_attr': heroRow['primary_attr'],
      'win_rate': heroRow['win_rate'],
      'pick_rate': heroRow['pick_rate'],
      'tier': heroRow['tier'],
      'roles': heroRow['roles'] != null ? jsonDecode(heroRow['roles'] as String) : [],
      'avatar_url': heroRow['avatar_url'],
      'bio': heroRow['bio'],
      'stats': heroRow['stats'] != null ? jsonDecode(heroRow['stats'] as String) : {},
      'ai_summary': heroRow['ai_summary'],
      'abilities': abilities,
      'ai_build': aiBuild,
      'created_at': heroRow['created_at'],
    };
  }).toList();

  return jsonEncode(list);
}