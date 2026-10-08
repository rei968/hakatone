# Схема Бази Даних (ERD) - GameGuide

Документ для розробника **Бекенд (База даних)**.

## Діаграма зв'язків сутностей (Mermaid ERD)

```mermaid
erDiagram
    GAMES ||--o{ HEROES : contains
    GAMES ||--o{ WEAPONS : contains
    GAMES ||--o{ ITEMS : contains
    HEROES ||--o{ ABILITIES : has
    HEROES ||--o{ HERO_COUNTERS : counter_by
    HEROES ||--o{ BUILDS : recommends

    GAMES {
        string id PK
        string slug UK
        string title
        string description
        string developer
        string genre
        string icon_url
        string banner_url
        timestamp created_at
    }

    HEROES {
        string id PK
        string game_id FK
        string name
        string primary_attribute
        string attack_type
        text bio
        jsonb stats
        string avatar_url
        timestamp created_at
    }

    ABILITIES {
        string id PK
        string hero_id FK
        string name
        text description
        string cooldown
        string mana_cost
        string icon_url
        int slot_order
    }

    WEAPONS {
        string id PK
        string game_id FK
        string name
        string side
        string category
        int price
        int kill_award
        int damage
        int magazine_size
        string image_url
    }

    ITEMS {
        string id PK
        string game_id FK
        string name
        int cost
        text description
        string icon_url
    }

    HERO_COUNTERS {
        int id PK
        string hero_id FK
        string counter_hero_id FK
        text tip
    }
```

## Пояснення полів JSONB в `HEROES.stats`
Для MOBA-ігор характеристики відрізняються, тому реляційне ядро доповнюється полем `stats` (JSONB у PostgreSQL або TEXT у SQLite):
```json
{
  "base_hp": 670,
  "base_mana": 267,
  "base_armor": 1.8,
  "movement_speed": 280,
  "attack_range": 150
}
```
