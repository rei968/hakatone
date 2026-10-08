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
- [~] Повідомлення для TY з URL і контрактом підготовлено, треба надіслати
- [ ] Перемкнути Render з `feature/backend-auth` на `develop` (PR #3–#5 уже там)
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

## Підготовка до демо (14:40)
- [ ] ЖЕ: реліз `develop` → `main`, якщо демо йде з `main` (зараз `main` відкочено на `0151442`, бекенду там немає)
- [ ] Після ~14:00 нічого не вливати в гілку, яку збирає Render: кожен пуш рестартує сервер і стирає акаунти
- [ ] За 10–15 хв: розбудити `/api/health`, дочекатися 127 героїв у `/api/meta/dota`
- [ ] Цикл-пінг кожні 10 хв, щоб Render не заснув
- [ ] Зареєструвати демо-акаунт у застосунку і відкрити героїв для показу (кеш AI-білдів)
- [ ] Один раз прогнати скрипт Live Sync (`/api/auth/login` → `POST /admin/sync`)

## Порядок у репо після YY
- [x] Прямий пуш YY у `main` прибрано
- [x] Прибрано порожній `bin/backend.dart` і `bin/pubspec.lock` (за згодою YY)
- [x] Прибрано `lib/db.dart` і `bin/test_db.dart`, що дублювали БД сервера (за згодою YY)
- `6ecb83d` пішов у `develop` без PR; далі тільки через PR

## Після демо (не потрібно)
- [ ] Тренди за `pub_pick_trend`
- [ ] Детект патча замість `patch` з `meta.json`

## Питання
1. YY: таблиця `users` у `schema.sql` (з PR #5) ок?
2. Пороги тірів S ≥ 53%, A ≥ 50%, B ≥ 48% влаштовують ЖЕ і TY?
