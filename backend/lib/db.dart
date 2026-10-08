import 'dart:convert';
import 'dart:io';
import 'package:sqlite3/sqlite3.dart';

late final Database db;

void initDatabase() {
  db = sqlite3.open('hackathon.db');
  
  // Увімкнення підтримки зовнішніх ключів
  db.execute('PRAGMA foreign_keys = ON;');

  _applySchema();
  print('✅ [БД]: Схему з schema.sql успішно підключено!');
  seedData();
}

/// Напряму виконує SQL-скрипт із schema.sql як Single Source of Truth
void _applySchema() {
  final schemaFile = File('database/schema.sql');
  if (schemaFile.existsSync()) {
    final schemaSql = schemaFile.readAsStringSync();
    db.execute(schemaSql);
  } else {
    print('⚠️ [БД]: Файл database/schema.sql не знайдено! Використовуємо фолбек...');
  }
}

/// Початкове заповнення даних відповідно до нової схеми
void seedData() {
  final countResult = db.select('SELECT COUNT(*) as count FROM heroes');
  if ((countResult.first['count'] as int) == 0) {
    // 1. Pudge (OpenDota ID = 14)
    db.execute('''
      INSERT INTO heroes (id, name, primary_attr, attack_type, win_rate, pick_rate, tier, roles, avatar_url, bio, stats, ai_summary)
      VALUES (
        14, 
        'Pudge', 
        'str', 
        'Melee',
        51.5,
        25.4,
        'S',
        '["Durable", "Disabler", "Initiator"]',
        'https://cdn.cloudflare.steamstatic.com/apps/dota2/images/dota_react/heroes/pudge.png',
        'Thick butcher from the Fields of Endless Carnage.',
        '{"base_hp": 620, "base_mana": 267}',
        'Strong ganker with Meat Hook.'
      );
    ''');

    // 2. Здібності Pudge
    db.execute('''
      INSERT INTO abilities (id, hero_id, name, description, cooldown, mana_cost, icon_url, slot_order)
      VALUES (
        'pudge_meat_hook', 
        14, 
        'Meat Hook', 
        'Launches a bloody hook at a unit or location.', 
        '18/16/14/12', 
        '110', 
        'https://cdn.cloudflare.steamstatic.com/apps/dota2/images/dota_react/abilities/pudge_meat_hook.png', 
        1
      );
    ''');

    // 3. AI-білд для Pudge
    db.execute('''
      INSERT INTO ai_builds (hero_id, skill_order, core_items, tactics)
      VALUES (
        14, 
        '["Meat Hook", "Rot", "Meat Hook", "Flesh Heap", "Meat Hook", "Dismember"]', 
        '["Phase Boots", "Blink Dagger", "Aether Lens"]', 
        'Hook enemies into tower range.'
      );
    ''');

    print('🌱 [Seed]: Базу даних заповнено згідно з актуальною схемою MangoDota!');
  }
}

/// Повертає список героїв із вкладеними об'єктами (abilities та ai_build) за OpenAPI
String getHeroesWithBuildsJson() {
  final ResultSet heroResults = db.select('SELECT * FROM heroes');

  final list = heroResults.map((heroRow) {
    final heroId = heroRow['id'] as int;

    // Здібності героя
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

    // AI-білд героя
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
      'attack_type': heroRow['attack_type'],
      'win_rate': heroRow['win_rate'],
      'pick_rate': heroRow['pick_rate'],
      'tier': heroRow['tier'],
      'roles': heroRow['roles'] != null ? jsonDecode(heroRow['roles'] as String) : [],
      'avatar_url': heroRow['avatar_url'],
      'bio': heroRow['bio'],
      'stats': heroRow['stats'] != null ? jsonDecode(heroRow['stats'] as String) : {},
      'ai_summary': heroRow['ai_summary'],
      'created_at': heroRow['created_at'],
      'abilities': abilities,
      'ai_build': aiBuild,
    };
  }).toList();

  return jsonEncode(list);
}