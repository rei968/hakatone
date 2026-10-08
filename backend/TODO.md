# Бекенд MangoData: TODO

Джерело для дашборда прогресу бекенду (`backend/docs/progress.html`).
Розділи `## N.` відповідають карткам NL на канбан-дошці.
Позначки: `[x]` готово, `[~]` в роботі, `[ ]` не почато; `(на перевірці)` і `(не потрібно)` після назви розділу.

## 1. Ініціалізувати Dart-сервер (shelf) (на перевірці)
- [x] Dart shelf-сервер: `PORT` з env (за замовчуванням 8080), логування запитів, CORS
- [x] `GET /api/health`
- [x] Seeds і `schema.sql` знаходяться і з `backend/`, і з кореня репо
- [x] [PR #3](https://github.com/rei968/hakatone/pull/3) у `develop`, чекає рев'ю ЖЕ

## 2. REST: /api/meta/dota, /api/dota/heroes/:id (на перевірці)
- [x] SQLite (`sqlite3` 3.x): при старті виконується `schema.sql`, порожня БД заповнюється з `dota2.json`
- [x] `GET /api/meta/dota` читає з БД, при помилці віддає `meta.json`
- [x] `GET /api/dota/heroes/{id}` читає з БД, 404 для невідомого героя
- [x] Колонка `heroes.attack_type` у `schema.sql` (YY, глянь у PR #3)
- `patch` поки береться з `meta.json`, детект патча в останню чергу

## 3. Реалізація OpenDotaAPI
- [x] Клієнт `GET /heroStats`: 127 героїв
- [x] Win rate, pick rate, тір (S/A/B/C) рахуються кодом, стати 1-го рівня
- [x] Upsert не стирає `bio`, `ai_summary`, abilities і AI-білди
- [~] Коміт `6a8d835` у `feature/opendota-sync`, ще не запушено

## 4. Воркер: Timer.periodic + запит до OpenDota
- [x] Sync при старті у фоні, далі кожні `SYNC_INTERVAL_HOURS` (6 год)
- [x] Якщо OpenDota недоступний, дані в БД лишаються як були
- [~] Push і PR разом з розділом 3

## 5. POST /admin/sync (ручний запуск для демо)
- [x] Відповідь `{status, synced_at, heroes_updated}`, 502 при помилці
- [x] Паралельні виклики чекають один і той самий запуск
- Захист токеном зробимо разом з авторизацією

## 6. Реалізація AI-аналізу (Gemini замість Claude API)
- [x] `gemini-3.5-flash-lite` через Google AI Studio, ключ у `GEMINI_API_KEY`
- [x] Білд генерується при першому запиті героя і кешується в `ai_builds`
- [x] Демо-герої 14, 8, 74 отримують свіжий білд під час sync
- [x] Без ключа або при помилці AI героя віддаємо без білда, а не 500
- [ ] Закомітити і відкрити PR
- [ ] Попередити ЖЕ: в `openapi.yaml` і презентації досі згадується Claude API

## 7. Деплой на Render/Railway
- [ ] Dockerfile: скопіювати `database/` в образ і задати `WORKDIR`
- [ ] Змінні середовища на сервісі: `GEMINI_API_KEY`
- [ ] Публічний URL бекенду для TY
- SQLite на Render живе до рестарту, для демо це прийнятно

## 8. Реалізація авторизації
- [ ] `/api/auth/*`, в останню чергу

## Після демо (не потрібно)
- [ ] Тренди за `pub_pick_trend`
- [ ] Детект патча замість `patch` з `meta.json`

## Питання
1. Видаляємо `lib/db.dart`, `bin/backend.dart` і `bin/pubspec.lock` з коміту YY (b397b59)? Сервер їх не використовує.
2. AI-аналіз комітимо в `feature/opendota-sync` разом з розділами 3–5 і відкриваємо один PR?
3. Пороги тірів S ≥ 53%, A ≥ 50%, B ≥ 48% влаштовують ЖЕ і TY?
