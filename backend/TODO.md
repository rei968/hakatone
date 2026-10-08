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

## 3. Реалізація OpenDotaAPI (на перевірці)
- [x] Клієнт `GET /heroStats`: 127 героїв
- [x] Win rate, pick rate, тір (S/A/B/C) рахуються кодом, стати 1-го рівня
- [x] Upsert не стирає `bio`, `ai_summary`, abilities і AI-білди
- [x] [PR #4](https://github.com/rei968/hakatone/pull/4) у `develop`, чекає рев'ю ЖЕ (мерджити після #3)

## 4. Воркер: Timer.periodic + запит до OpenDota (на перевірці)
- [x] Sync при старті у фоні, далі кожні `SYNC_INTERVAL_HOURS` (6 год)
- [x] Якщо OpenDota недоступний, дані в БД лишаються як були
- [x] У [PR #4](https://github.com/rei968/hakatone/pull/4)

## 5. POST /admin/sync (ручний запуск для демо) (на перевірці)
- [x] Відповідь `{status, synced_at, heroes_updated}`, 502 при помилці
- [x] Паралельні виклики чекають один і той самий запуск
- [x] Захищено Bearer-токеном з `/api/auth/login` (розділ 8)

## 6. Реалізація AI-аналізу (Gemini замість Claude API) (на перевірці)
- [x] `gemini-3.5-flash-lite` через Google AI Studio, ключ у `GEMINI_API_KEY`
- [x] Білд генерується при першому запиті героя і кешується в `ai_builds`
- [x] Демо-герої 14, 8, 74 отримують свіжий білд під час sync
- [x] Без ключа або при помилці AI героя віддаємо без білда, а не 500
- [x] Закомічено в `feature/opendota-sync`
- [x] У [PR #4](https://github.com/rei968/hakatone/pull/4)
- [x] Документи в `develop` переведено на Gemini (77ea0f7)

## 7. Деплой на Render/Railway
- [x] Dockerfile: `database/` у образі, `WORKDIR /app`; бандл `dart build cli` перевірено локально
- [x] Гілку `feature/opendota-sync` запушено, Render може її зібрати
- [x] Web Service на Render: Root Directory `backend`, runtime Docker, env `GEMINI_API_KEY`
- [x] Публічний URL: [hakatone.onrender.com](https://hakatone.onrender.com/api/health), усі ендпоінти перевірено
- [ ] Передати URL TY
- [ ] Після мерджу #3 і #4 перемкнути Render з `feature/opendota-sync` на `develop` або `main`
- SQLite на Render живе до рестарту, для демо це прийнятно
- Безкоштовний інстанс засинає без запитів, перед демо його треба «розбудити»

## 8. Реалізація авторизації
- [x] Таблиця `users` у `schema.sql` (YY, глянь)
- [x] `POST /api/auth/register`: 201 + JWT; 400 з кодом `email_taken`, `invalid_email`, `password_too_short`
- [x] `POST /api/auth/login`: 200 + JWT; 401 `invalid_credentials`
- [x] Паролі через PBKDF2-HMAC-SHA256 (20 000 ітерацій, сіль), JWT HS256 на 7 днів
- [x] CORS пропускає заголовок `Authorization`
- [x] `docs/test_endpoints.ps1` проходить усі 5 кроків
- [x] Гілка `feature/backend-auth` запушена, PR у `develop`
- [ ] `JWT_SECRET` у змінних середовища на Render
- Користувачі живуть у SQLite, тож на Render зникають після рестарту

## Після демо (не потрібно)
- [ ] Тренди за `pub_pick_trend`
- [ ] Детект патча замість `patch` з `meta.json`

## Питання
1. YY: `lib/db.dart` (оновлений у 512a9fc) дублює `lib/db/app_database.dart`, яким користується сервер. Лишаємо один варіант? І чи прибираємо `bin/backend.dart` та `bin/pubspec.lock`?
2. Пороги тірів S ≥ 53%, A ≥ 50%, B ≥ 48% влаштовують ЖЕ і TY?
