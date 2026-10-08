import 'dart:convert';
import 'package:sqlite3/sqlite3.dart';

late final Database db;

void initDatabase() {
  db = sqlite3.open('hackathon.db');
  db.execute('PRAGMA foreign_keys = ON;');

  _createTables();
  print('✅ [БД]: Схема ERD підключена!');
  seedData();
}

void _createTables() {
  db.execute('''
    CREATE TABLE IF NOT EXISTS games (
      id TEXT PRIMARY KEY,
      slug TEXT UNIQUE NOT NULL,
      title TEXT NOT NULL,
      description TEXT,
      icon_url TEXT,
      banner_url TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS heroes (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      game_id TEXT NOT NULL DEFAULT 'dota2',
      name TEXT NOT NULL,
      primary_attr TEXT,
      win_rate REAL,
      pick_rate REAL,
      tier TEXT,
      roles TEXT,
      avatar_url TEXT,
      bio TEXT,
      ai_summary TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (game_id) REFERENCES games(id)
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
      FOREIGN KEY (hero_id) REFERENCES heroes(id)
    );

    CREATE TABLE IF NOT EXISTS ai_builds (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      hero_id INTEGER NOT NULL,
      skill_order TEXT,
      core_items TEXT,
      tactics TEXT,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (hero_id) REFERENCES heroes(id)
    );
  ''');
}

void seedData() {
  final countResult = db.select('SELECT COUNT(*) as count FROM games');
  if ((countResult.first['count'] as int) == 0) {
    db.execute('''
      INSERT INTO games (id, slug, title, description)
      VALUES ('dota2', 'dota-2', 'Dota 2', 'MOBA game by Valve')
    ''');

    db.execute('''
      INSERT INTO heroes (id, game_id, name, primary_attr, win_rate, pick_rate, tier, roles, avatar_url)
      VALUES (1, 'dota2', 'Pudge', 'str', 51.5, 25.4, 'S', '["Durable", "Disabler"]', 'https://example.com/pudge.png')
    ''');

    db.execute('''
      INSERT INTO abilities (id, hero_id, name, description, cooldown, mana_cost, slot_order)
      VALUES ('pudge_hook', 1, 'Meat Hook', 'Launches a bloody hook', '18/16/14/12', '110', 1)
    ''');

    db.execute('''
      INSERT INTO ai_builds (hero_id, skill_order, core_items, tactics)
      VALUES (1, '["Q", "W", "Q", "E", "Q", "R"]', '["Bottle", "Phase Boots", "Blink Dagger"]', 'Hook enemies into tower range.')
    ''');

    print('🌱 [Seed]: Базу даних наповнено згідно з ERD!');
  }
}

String getHeroesWithBuildsJson() {
  final ResultSet results = db.select('''
    SELECT h.id, h.name, h.primary_attr, h.win_rate, h.tier, b.core_items, b.tactics
    FROM heroes h
    LEFT JOIN ai_builds b ON h.id = b.hero_id
  ''');

  final list = results.map((row) => {
    'id': row['id'],
    'name': row['name'],
    'primary_attr': row['primary_attr'],
    'win_rate': row['win_rate'],
    'tier': row['tier'],
    'core_items': row['core_items'] != null ? jsonDecode(row['core_items'] as String) : [],
    'tactics': row['tactics'],
  }).toList();

  return jsonEncode(list);
}