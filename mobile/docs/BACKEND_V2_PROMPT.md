# Промпт для Claude Code: бекенд MangoDota v2

Скопіюйте все, що нижче лінії, і надішліть Claude Code у корені репозиторію `hakatone`.

---

Ти працюєш над бекендом MangoDota у монорепо https://github.com/rei968/hakatone (Dart + shelf + SQLite, папка `backend/`). Мобільний клієнт (Flutter, `mobile/`) робить інша людина, його не чіпай, крім двох файлів моків, про які написано нижче.

## Git

- Працюй за gitflow: створи гілку `feature/backend-v2` від свіжого `origin/develop`, коміть туди невеликими комітами, наприкінці відкрий PR у `develop`. Мерджить тімлід, сам не мерджи і не пуш у `develop` чи `main`.
- Render збирає бекенд з гілки, яку налаштував тімлід. Кожен деплой рестартує сервер і стирає SQLite (акаунти теж), тому не пуш у ту гілку напряму.
- Перед PR: `dart analyze` без помилок, `dart test` зелений, сервер запускається локально (`dart run bin/server.dart`) і всі ендпоінти з `docs/test_endpoints.ps1` відповідають.

## Спершу прочитай

`docs/openapi.yaml`, `backend/TODO.md`, `backend/lib/api/router.dart`, `backend/lib/sync/hero_sync.dart`, `backend/lib/opendota/opendota_client.dart`, `backend/lib/ai/hero_analyzer.dart`, `backend/lib/db/app_database.dart`, `backend/database/schema.sql`, `backend/database/seeds/*.json`.

## Головне правило сумісності

Застосунок, який уже стоїть у людей, читає поточні поля. Нічого не перейменовуй і не міняй типів наявних полів. Нові поля лише додаються, і кожне може бути `null`. Новий клієнт теж переживе їхню відсутність, тож порядок злиття PR фронту й бекенду не важливий.

## Що зробити

### 1. Справжній патч

Зараз `patch` береться з `seeds/meta.json` (`_seedPatch` у `router.dart`), тому застосунок показує 7.37d, хоча актуальний 7.41.

- Під час sync бери `GET https://api.opendota.com/api/constants/patch` і зберігай `name` останнього елемента масиву (зараз `"7.41"`). Віддавай його в `patch` у `/api/meta/dota`.
- Якщо OpenDota недоступний, лишай попереднє значення, а якщо його ще немає — значення з `meta.json`.

### 2. Параметр рангу `?rank=`

Для `GET /api/meta/dota` і `GET /api/dota/heroes/{id}`.

- Значення: `herald`, `guardian`, `crusader`, `archon`, `legend`, `ancient`, `divine`. Без параметра або `all` — усі ранги, як зараз.
- `/heroStats` уже містить статистику за ранговими дужками: поля `1_pick`/`1_win` … `7_pick`/`7_win` (1 Herald … 7 Divine). Дужка `8_*` (Immortal) в OpenDota зараз порожня в усіх героїв, тому окремого `immortal` немає: `divine` означає Divine і вище.
- Для рангу: `win_rate = N_win / N_pick * 100`, `pick_rate = N_pick / (сума N_pick усіх героїв / 10) * 100`, `tier` за тими самими порогами `tierForWinRate`. Округлення як зараз, до 0,1.
- Невідоме значення: `400 {"error": "invalid_rank"}`. Додай код в `ErrorResponse` в `openapi.yaml`.
- Сирі цифри зручно зберігати в героя однією JSON-колонкою (наприклад `rank_stats TEXT`: `{"1": {"pick": 11964, "win": 6073}, …}`) і рахувати відповідь на льоту. Upsert, як і зараз, не повинен стирати `bio`, `ai_summary`, здібності й білди.
- AI-білд від рангу не залежить: один на героя, як зараз.

### 3. Нові поля мети (тиждень і обсяг вибірки)

У відповіді `/api/meta/dota`:

- `rank` — рядок: значення параметра або `"all"`.
- `total_matches` — ціле: кількість матчів у вибірці цього рангу (сума pick / 10).

У кожному `MetaHero` (і в `HeroWithBuild` теж):

- `matches` — ціле: скільки разів героя взяли в цьому ранзі (`N_pick` або `pub_pick`).
- `win_rate_delta` — число в процентних пунктах, може бути `null`: як змінився вінрейт за тиждень. Рахуй з `pub_win_trend` і `pub_pick_trend` з `/heroStats` (по 7 значень, по одному на добу; останнє — неповна поточна доба). Формула: вінрейт діб з індексами 3–5 мінус вінрейт діб 0–2, округлити до 0,1. Трендів по рангах OpenDota не дає, тому дельта завжди за всі ранги, незалежно від `?rank=`.

Застосунок сам рахує з цих полів «найкращий/найгірший герой», «найбільший зліт/падіння» і «найпопулярніші», окремий ендпоінт не потрібен.

### 4. AI-білд v2

Розшир JSON-схему Gemini в `hero_analyzer.dart` і відповідь `ai_build` у `/api/dota/heroes/{id}`. Мова тексту — українська, назви здібностей і предметів — англійською, точно як у грі.

```json
"ai_build": {
  "skill_order": ["Wraithfire Blast", "Vampiric Spirit", "Wraithfire Blast", "Vampiric Spirit", "Wraithfire Blast",
                  "Reincarnation", "Wraithfire Blast", "Vampiric Spirit", "Vampiric Spirit", "L",
                  "Mortal Strike", "Reincarnation", "Mortal Strike", "Mortal Strike", "R",
                  "Mortal Strike", "-", "Reincarnation"],
  "talents": [
    {"level": 10, "side": "L", "name": "+10% Lifesteal"},
    {"level": 15, "side": "R", "name": "+30 Attack Speed"},
    {"level": 20, "side": "L", "name": "+25% Critical Strike Chance"},
    {"level": 25, "side": "R", "name": "Reincarnation No Mana Cost"}
  ],
  "core_items": ["Phase Boots", "Radiance", "Blink Dagger", "Assault Cuirass", "Black King Bar"],
  "item_timings": {"Phase Boots": 400, "Radiance": 1040, "Blink Dagger": 1265, "Assault Cuirass": 1780, "Black King Bar": 1990},
  "situational_items": [
    {"name": "Black King Bar", "reason": "Проти контролю й магії"},
    {"name": "Monkey King Bar", "reason": "Проти ухилення"},
    {"name": "Aeon Disk", "reason": "Проти бурсту"}
  ],
  "tactics": "..."
}
```

- `skill_order` — рівно 18 рядків, рівні 1–18 по порядку. Кожен рядок — це назва здібності точно як `abilities[].name` цього героя, `"L"` чи `"R"`, якщо на цьому рівні береться талант, або `"-"`, якщо на рівні немає очка прокачки (у 7.41 це рівень 17). Перевіряй відповідь кодом: довжина 18, назви з переліку здібностей, ультимейт не раніше 6 рівня (для героїв з іншими правилами, як Invoker чи Meepo, цю перевірку пропусти). Невалідну відповідь не зберігай, кидай `AiException`, як зараз.
- `talents` — 4 елементи, рівні 10, 15, 20, 25. `side` — `"L"` або `"R"`, `name` — назва таланту англійською. Варіанти талантів героя бери з `GET /api/constants/hero_abilities` (`talents`: 8 елементів, `level` 1–4 відповідає рівням 10/15/20/25), назви з `GET /api/constants/abilities` (`dname`; плейсхолдери на кшталт `{s:bonus_...}` підстав значеннями з того ж запису або прибери). Передай Gemini обидва варіанти кожного рівня з позначками L і R. Який із пари лівий у грі, перевір на 1–2 героях за Dota 2 Wiki, перш ніж зафіксувати в коді.
- `core_items` — як зараз, 4–6 повних предметів у порядку покупки, назви точно як `dname` з `/constants/items`.
- `item_timings` — не від AI, рахує код: об’єкт «назва предмета з `core_items` → середній таймінг покупки в секундах». Джерело — `GET /api/scenarios/itemTimings?hero_id={id}`: масив `{item, time, games, wins}`, де `item` — ключ предмета (як ключі `/constants/items`), `time` — кошик часу в секундах, `games` і `wins` приходять рядками. Середній таймінг = середнє `time`, зважене на `games`. Предмета немає в даних — просто пропусти його. Таймінги за всі ранги, по рангах OpenDota їх не дає.
- `situational_items` — 3–4 предмети від AI: `name` як `dname`, `reason` українською до 40 символів.
- `tactics` — без змін.

Схема БД: додай в `ai_builds` колонки `talents`, `item_timings`, `situational_items` (JSON у `TEXT`, як решта). Для наявних локальних БД потрібна міграція: `ALTER TABLE … ADD COLUMN`, якщо колонки ще немає (через `PRAGMA table_info`).

Старі збережені білди (без `talents`) вважай застарілими: під час запиту героя перегенеруй їх так само, як зараз генерується відсутній білд (з тим самим таймаутом), а поки нового немає — віддавай старий.

### 5. Сіди, моки, документація

- Онови `docs/openapi.yaml`: параметр `rank`, нові поля з прикладами, `invalid_rank`. Нові поля — `nullable: true` і не в `required`.
- Онови `backend/database/seeds/dota2.json` (для демо-героїв 14, 8, 74 — повний `ai_build` v2) і `meta.json` (нові поля, `patch: "7.41"`).
- Мобільні тести вимагають, щоб `mobile/assets/mocks/dota2.json` і `mobile/assets/mocks/meta.json` були байт-у-байт копіями цих сідів. Скопіюй обидва файли туди без змін. Інші файли в `mobile/` не чіпай.
- Додай запити з `?rank=divine` в `docs/test_endpoints.ps1` і `docs/postman_collection.json`.
- Відміть зроблене в `backend/TODO.md` новим розділом.

### 6. Тести (`backend/test/`)

- Розбір і валідація `rank`, 400 `invalid_rank`.
- Вінрейт, пікрейт і тір для рангу на маленькому фейковому `/heroStats`.
- `win_rate_delta` з трендів, зокрема з нулями в pick.
- Зважений середній таймінг з `itemTimings` (рядкові `games`).
- Валідація відповіді AI: 18 рівнів, невідома здібність, ультимейт до 6 рівня.

## Чого робити не треба

- Вхід через Steam і профіль гравця: клієнт сам перевіряє Steam OpenID і бере матчі гравця напряму з OpenDota. Email-авторизацію не видаляй, нею користується `/admin/sync`.
- Окремий AI-білд на кожен ранг.

## Звіт наприкінці

Коротко: що зроблено, посилання на PR, приклад відповіді `GET /api/meta/dota?rank=divine` (перші 2 герої) і `GET /api/dota/heroes/42`, і чого не вдалося зробити, якщо таке є.
