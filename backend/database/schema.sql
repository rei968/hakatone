-- SQL Схема для GameGuide (PostgreSQL / SQLite сумісна)

CREATE TABLE IF NOT EXISTS games (
    id VARCHAR(50) PRIMARY KEY,
    slug VARCHAR(50) UNIQUE NOT NULL,
    title VARCHAR(100) NOT NULL,
    description TEXT,
    developer VARCHAR(100),
    genre VARCHAR(50),
    icon_url TEXT,
    banner_url TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS heroes (
    id VARCHAR(50) PRIMARY KEY,
    game_id VARCHAR(50) NOT NULL REFERENCES games(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    primary_attribute VARCHAR(50),
    attack_type VARCHAR(50),
    bio TEXT,
    stats JSONB,
    avatar_url TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS abilities (
    id VARCHAR(50) PRIMARY KEY,
    hero_id VARCHAR(50) NOT NULL REFERENCES heroes(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    cooldown VARCHAR(50),
    mana_cost VARCHAR(50),
    icon_url TEXT,
    slot_order INT DEFAULT 0
);

CREATE TABLE IF NOT EXISTS weapons (
    id VARCHAR(50) PRIMARY KEY,
    game_id VARCHAR(50) NOT NULL REFERENCES games(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    side VARCHAR(10),
    category VARCHAR(50),
    price INT,
    kill_award INT,
    damage INT,
    magazine_size INT,
    image_url TEXT
);

CREATE INDEX IF NOT EXISTS idx_heroes_game_id ON heroes(game_id);
CREATE INDEX IF NOT EXISTS idx_abilities_hero_id ON abilities(hero_id);
CREATE INDEX IF NOT EXISTS idx_weapons_game_id ON weapons(game_id);
