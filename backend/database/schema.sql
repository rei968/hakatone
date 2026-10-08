-- SQL Схема для Kakatone Dota Guide (PostgreSQL / SQLite сумісна)

CREATE TABLE IF NOT EXISTS games (
    id VARCHAR(50) PRIMARY KEY,
    slug VARCHAR(50) UNIQUE NOT NULL,
    title VARCHAR(100) NOT NULL,
    description TEXT,
    icon_url TEXT,
    banner_url TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS heroes (
    id INT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    primary_attr VARCHAR(50),
    win_rate NUMERIC(5, 2),
    pick_rate NUMERIC(5, 2),
    tier VARCHAR(5),
    roles TEXT[],
    avatar_url TEXT,
    bio TEXT,
    ai_summary TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS abilities (
    id VARCHAR(50) PRIMARY KEY,
    hero_id INT NOT NULL REFERENCES heroes(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    cooldown VARCHAR(50),
    mana_cost VARCHAR(50),
    icon_url TEXT,
    slot_order INT DEFAULT 0
);

CREATE TABLE IF NOT EXISTS ai_builds (
    id SERIAL PRIMARY KEY,
    hero_id INT UNIQUE NOT NULL REFERENCES heroes(id) ON DELETE CASCADE,
    skill_order TEXT[],
    core_items TEXT[],
    tactics TEXT,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_heroes_tier ON heroes(tier);
CREATE INDEX IF NOT EXISTS idx_abilities_hero_id ON abilities(hero_id);
