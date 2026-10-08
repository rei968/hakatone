# Схема Бази Даних (SQLite ERD) - MangoData

База даних: **SQLite 3**  
Відповідальний: **Бекенд (База даних - YY)**

## Діаграма сутностей SQLite

```mermaid
erDiagram
    HEROES ||--o{ ABILITIES : has
    HEROES ||--|| AI_BUILDS : generated_for

    HEROES {
        int id PK "Steam / OpenDota hero_id (14, 8, 74...)"
        text name "Назва героя (Pudge, Invoker...)"
        text primary_attr "str, agi, int, all"
        real win_rate "Вінрейт, наприклад 53.4"
        real pick_rate "Пікрейт, наприклад 26.8"
        text tier "S, A, B, C"
        text roles "JSON масив: ['Disabler','Initiator']"
        text avatar_url "Посилання на аватар"
        text bio "Лор героя"
        text stats "JSON об'єкт: {'base_hp':700,'base_mana':267}"
        text ai_summary "Короткий опис від Google Gemini AI"
        datetime created_at
    }

    ABILITIES {
        text id PK "meat_hook, rot..."
        int hero_id FK "heroes.id (CASCADE)"
        text name "Назва здібності"
        text description "Опис скіла"
        text cooldown "Кулдаун"
        text mana_cost "Манакост"
        text icon_url "Посилання на іконку"
        int slot_order "Порядок слота (1, 2, 3, 4)"
    }

    AI_BUILDS {
        int id PK "AUTOINCREMENT"
        int hero_id FK "heroes.id (UNIQUE, CASCADE)"
        text skill_order "JSON масив: ['Meat Hook','Rot']"
        text core_items "JSON масив: ['Phase Boots','Blink']"
        text tactics "Тактичні поради від Google Gemini API"
        datetime updated_at
    }
```

## Особливості реалізації в SQLite:
1. Масиви та вкладені об'єкти (`roles`, `stats`, `skill_order`, `core_items`) зберігаються як валідні JSON-рядки у полях типу `TEXT`.
2. Увімкнення Foreign Keys у Shelf-сервері: перед виконанням запитів викликати `PRAGMA foreign_keys = ON;`.
