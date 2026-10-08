# Backend Service - Kakatone Dota Guide API

Серверна частина на **Dart (shelf)**: робота з OpenDota API, інтеграція з Claude AI та базою даних.

## 📁 Структура
```text
backend/
├── database/
│   ├── schema.sql         # SQL створення таблиць (PostgreSQL / SQLite)
│   └── seeds/             # Готові початкові дані (dota2.json, meta.json fallback)
└── bin/ (або src/)        # Сервер API на Dart (shelf)
```

## 🚀 Швидкий старт
1. Ознайомтеся зі схемою БД: `../docs/DATABASE_ERD.md`
2. Перегляньте контракт ендпоінтів: `../docs/openapi.yaml`
3. Використовуйте `database/seeds/dota2.json` та `meta.json` як базовий fallback-знімок при помилках OpenDota.
