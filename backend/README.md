# Backend Service - MangoDota API

Серверна частина на **Dart (shelf)** з локальною базою даних **SQLite 3**: робота з OpenDota API, інтеграція з **Google Gemini API** (`gemini-3.5-flash-lite`) та роздача даних клієнту.

## 📁 Структура
```text
backend/
├── database/
│   ├── schema.sql         # Чистий SQLite3 DDL скрипт
│   └── seeds/             # Готові початкові дані (dota2.json, meta.json fallback)
├── Dockerfile             # Збірка під Render/Railway
└── bin/server.dart        # Сервер API на Dart (shelf)
```

## 🚀 Швидкий старт
1. Ознайомтеся зі схемою БД: `../docs/DATABASE_ERD.md` (чистий SQLite, масиви зберігаються у `TEXT` як JSON).
2. Перегляньте контракт ендпоінтів: `../docs/openapi.yaml`.
3. AI-білди генеруються через Gemini API: потрібен `GEMINI_API_KEY` в оточенні.
4. Використовуйте `database/seeds/dota2.json` та `meta.json` (числові ID: 14, 8, 74; змінні в snake_case).
