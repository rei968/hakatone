# Бекенд MangoData: TODO

Джерело для дашборда прогресу бекенду (`backend/docs/progress.html`).
Розділи `## N.` відповідають карткам NL на канбан-дошці.
Позначки: `[x]` готово, `[~]` в роботі, `[ ]` не почато; `(на перевірці)` і `(не потрібно)` після назви розділу.

## 1. Ініціалізувати Dart-сервер (shelf)
- [x] Dart shelf-сервер: `PORT` з env (за замовчуванням 8080), логування запитів, CORS
- [x] `GET /api/health` (`{status, timestamp}` за `openapi.yaml`)
- [x] Seeds і `schema.sql` знаходяться і з `backend/`, і з кореня репо
- [x] [PR #3](https://github.com/rei968/hakatone/pull/3) змерджено в `develop`

## 2. REST: /api/meta/dota, /api/dota/heroes/:id
- [x] SQLite (`sqlite3` 3.x): при старті виконується `schema.sql`, порожня БД заповнюється з `dota2.json`
- [x] `GET /api/meta/dota` читає з БД, при помилці віддає `meta.json`; `attack_type` у кожному герої
- [x] `GET /api/dota/heroes/{id}` читає з БД, 404 `hero_not_found` для невідомого героя
- [x] Колонка `heroes.attack_type` у `schema.sql`
- `patch` поки береться з `meta.json`, детект патча в останню чергу

## 3. Реалізація OpenDotaAPI
- [x] Клієнт `GET /heroStats`: 127 героїв
- [x] Win rate, pick rate, тір (S/A/B/C) рахуються кодом, стати 1-го рівня
- [x] Upsert не стирає `bio`, `ai_summary`, abilities і AI-білди
- [x] [PR #4](https://github.com/rei968/hakatone/pull/4) змерджено в `develop`

## 4. Воркер: Timer.periodic + запит до OpenDota
- [x] Sync при старті у фоні, далі кожні `SYNC_INTERVAL_HOURS` (6 год)
- [x] Якщо OpenDota недоступний, дані в БД лишаються як були
- [x] У [PR #4](https://github.com/rei968/hakatone/pull/4), змерджено

## 5. POST /admin/sync (ручний запуск для демо)
- [x] Відповідь `{status, synced_at, heroes_updated}`, 502 при помилці
- [x] Паралельні виклики чекають один і той самий запуск
- [x] Захищено Bearer-токеном з `/api/auth/login`, без токена 401 `unauthorized`

## 6. Реалізація AI-аналізу (Gemini замість Claude API)
- [x] `gemini-3.5-flash-lite` через Google AI Studio, ключ у `GEMINI_API_KEY`
- [x] Білд генерується при першому запиті героя і кешується в `ai_builds`
- [x] Демо-герої 14, 8, 74 отримують свіжий білд під час sync
- [x] Без ключа або при помилці AI героя віддаємо без білда, а не 500
- [x] Документи в `develop` переведено на Gemini (77ea0f7)
- [x] У [PR #4](https://github.com/rei968/hakatone/pull/4), змерджено

## 7. Деплой на Render/Railway
- [x] Dockerfile: `database/` у образі, `WORKDIR /app`; `dart build cli` збирає і `develop`
- [x] Web Service на Render: Root Directory `backend`, Docker, env `GEMINI_API_KEY` і `JWT_SECRET`
- [x] Публічний URL: [hakatone.onrender.com](https://hakatone.onrender.com/api/health), усі ендпоінти й `test_endpoints.ps1` перевірено
- [x] TY підключив застосунок до hakatone.onrender.com з авторизацією (PR #6 у `develop`)
- [x] Render збирає `develop` (PR #3–#7 влито)
- SQLite на Render живе до рестарту, для демо це прийнятно

## 8. Реалізація авторизації
- [x] Таблиця `users` у `schema.sql`
- [x] `POST /api/auth/register`: 201 + JWT; 400 з кодом `email_taken`, `invalid_email`, `password_too_short`
- [x] `POST /api/auth/login`: 200 + JWT; 401 `invalid_credentials`
- [x] Паролі через PBKDF2-HMAC-SHA256 (20 000 ітерацій, сіль), JWT HS256 на 7 днів
- [x] CORS пропускає заголовок `Authorization`
- [x] Коди помилок (`ErrorResponse`) описано в `docs/openapi.yaml`
- [x] [PR #5](https://github.com/rei968/hakatone/pull/5) змерджено в `develop`
- [x] На Render: реєстрація, вхід і `/admin/sync` з токеном працюють
- Користувачі живуть у SQLite, тож на Render зникають після рестарту

## 9. Бекенд v2 (на перевірці)
- [x] Справжній патч з OpenDota `/constants/patch` при кожному sync (зараз 7.41); без OpenDota — попередній або з `meta.json`
- [x] `?rank=herald…divine` для мети й героя: вінрейт, пікрейт і тір з `N_pick`/`N_win` `/heroStats` (колонка `rank_stats`); невідоме значення — 400 `invalid_rank`
- [x] Нові поля мети: `rank`, `total_matches`; у героя `matches` і `win_rate_delta` (доби 3–5 мінус 0–2 з `pub_*_trend`)
- [x] AI-білд v2: `skill_order` на 18 рівнів з `L`/`R`/`-`, `talents`, `situational_items`; невалідну відповідь Gemini код відкидає
- [x] Таланти з `/constants/hero_abilities`: у парі OpenDota перший — правий у грі (звірено з Dota 2 Wiki на Pudge і Wraith King)
- [x] `item_timings` рахує код з `/scenarios/itemTimings`, зважено на ігри
- [x] Старі білди без `talents` перегенеровуються під час запиту героя, поки нового немає — віддається старий
- [x] Міграція наявних БД: `ALTER TABLE … ADD COLUMN` через `PRAGMA table_info`
- [x] Сіди й моки: патч 7.41, нові поля, білд v2 для 14, 8, 74; Pudge — Meat Shield, Invoker — Quas/Wex/Exort/Invoke
- [x] `openapi.yaml`, `test_endpoints.ps1`, Postman: `rank`, нові поля, `invalid_rank`
- [x] Тести `backend/test/`: 32 зелені
- [ ] TY: два мобільні тести чекають старих сідів (`meta_report_test.dart:22` — патч 7.37d, `hero_details_test.dart` — 6 рівнів у Pudge)
- [ ] У героїв поза сідом `abilities` порожні, тож іконок для `skill_order` клієнт там не знайде

## Підготовка до демо (14:40)
- [ ] ЖЕ: реліз `develop` → `main`, якщо демо йде з `main` (зараз `main` відкочено на `0151442`, бекенду там немає)
- [ ] Після ~14:00 нічого не вливати в гілку, яку збирає Render: кожен пуш рестартує сервер і стирає акаунти
- [ ] За 10–15 хв: розбудити `/api/health`, дочекатися 127 героїв у `/api/meta/dota`
- [ ] Цикл-пінг кожні 10 хв, щоб Render не заснув
- [ ] Зареєструвати демо-акаунт у застосунку і відкрити героїв для показу (кеш AI-білдів)
- [ ] Один раз прогнати скрипт Live Sync (`/api/auth/login` → `POST /admin/sync`)

## Порядок у репо після YY
- [x] Прямий пуш YY у `main` прибрано
- [x] Прибрано порожній `bin/backend.dart` і `bin/pubspec.lock` (за згодою YY, PR #7 влито)
- [x] Прибрано `lib/db.dart` і `bin/test_db.dart`, що дублювали БД сервера (за згодою YY)
- `6ecb83d` пішов у `develop` без PR; далі тільки через PR

## Питання
1. YY: таблиця `users` у `schema.sql` (з PR #5) ок?
2. Пороги тірів S ≥ 53%, A ≥ 50%, B ≥ 48% влаштовують ЖЕ і TY?
