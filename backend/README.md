# Backend Service - MangoData API

Серверна частина на **Dart (shelf)** з локальною базою даних **SQLite 3**: робота з OpenDota API, інтеграція з Claude AI та роздача даних клієнту.

## 📁 Структура
```text
backend/
├── database/
│   ├── schema.sql         # Чистий SQLite3 DDL скрипт
│   └── seeds/             # Готові початкові дані (dota2.json, meta.json fallback)
└── bin/ (або src/)        # Сервер API на Dart (shelf)
```

## 🚀 Швидкий старт
1. Ознайомтеся зі схемою БД: `../docs/DATABASE_ERD.md` (чистий SQLite, масиви зберігаються у `TEXT` як JSON).
2. Перегляньте контракт ендпоінтів: `../docs/openapi.yaml`.
3. Використовуйте `database/seeds/dota2.json` та `meta.json` (числові ID: 14, 8, 74; змінні в snake_case).
4. **Важливо:** Не видаляйте і не ігноруйте `pubspec.lock` — він має бути в Git для коректного білду на Render/Railway.
