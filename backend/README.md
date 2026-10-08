# Backend Service - GameGuide API

Цей модуль відповідає за надання REST API для мобільного клієнту та роботу з базою даних.

## 📁 Структура
```text
backend/
├── database/
│   ├── schema.sql         # SQL створення таблиць
│   └── seeds/             # Готові початкові дані (dota2.json, meta.json, cs2.json)
└── bin/ (або src/)        # Сервер API на Dart (shelf)
```

## 🚀 Швидкий старт
1. Ознайомтеся зі схемою БД: `../docs/DATABASE_ERD.md`
2. Перегляньте контракт ендпоінтів: `../docs/openapi.yaml`
3. Використовуйте готові сіди в `database/seeds/` для наповнення бази даних тестовими даними.
