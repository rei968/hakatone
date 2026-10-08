-- SQLite Схема для MangoData (чистий SQLite3)
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS heroes (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    primary_attr TEXT,
    win_rate REAL,
    pick_rate REAL,
    tier TEXT,
    roles TEXT,             -- Зберігається як JSON-масив рядків: '["Disabler","Initiator"]'
    avatar_url TEXT,
    bio TEXT,
    stats TEXT,             -- Зберігається як JSON-об'єкт: '{"base_hp": 700, "base_mana": 267}'
    ai_summary TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS abilities (
    id TEXT PRIMARY KEY,
    hero_id INTEGER NOT NULL REFERENCES heroes(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    cooldown TEXT,
    mana_cost TEXT,
    icon_url TEXT,
    slot_order INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS ai_builds (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    hero_id INTEGER UNIQUE NOT NULL REFERENCES heroes(id) ON DELETE CASCADE,
    skill_order TEXT,       -- Зберігається як JSON-масив: '["Meat Hook","Rot"]'
    core_items TEXT,        -- Зберігається як JSON-масив: '["Phase Boots","Blink Dagger"]'
    tactics TEXT,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_heroes_tier ON heroes(tier);
CREATE INDEX IF NOT EXISTS idx_abilities_hero_id ON abilities(hero_id);
