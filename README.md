# 🎮 Kakatone Dota Guide

Мобільний інтерактивний асистент та довідник з Dota 2 (актуальна мета з OpenDota + персоналізовані AI-білди від Claude).  
Проєкт розроблено в рамках хакатону.

---

## 👥 Команда та розподіл ролей

- **Team Lead & QA / Тестувальник (ЖЕ):** Загальна архітектура, контроль стандартів розробки, Git-процеси, тестування API та клієнта, фінальний реліз і демо.
- **Backend - API & Business Logic (NL):** Dart (`shelf`) сервер, інтеграція OpenDota API та Claude API, фоновий воркер оновлення мети, ендпоінти.
- **Backend - Database (YY):** Проєктування та налаштування БД, сід-скрипт для Dota 2, резервний дамп даних.
- **Frontend - Mobile (TY):** Flutter-додаток (`dio`, `Riverpod`, локальний кеш у `Hive`), екран мети, картки героїв та AI-білдів.

---

## 🏗️ Архітектура та структура репозиторію

Репозиторій організовано за монорепо-структурою для швидкої синхронізації та уникнення конфліктів у Git:

```text
hakatone/
├── backend/                  # Серверна частина (Dart shelf)
│   ├── database/             # База даних
│   │   ├── schema.sql        # Схема створення таблиць (PostgreSQL / SQLite)
│   │   └── seeds/            # Готові початкові дані (dota2.json, meta.json fallback)
│   └── README.md             # Інструкції для Backend-розробника
├── mobile/                   # Клієнтська мобільна частина (Flutter)
│   └── README.md             # Інструкції для Mobile-розробника
├── docs/                     # Проєктна документація
│   ├── openapi.yaml          # Єдиний контракт API (OpenAPI 3.0)
│   ├── DATABASE_ERD.md       # Діаграма бази даних (Mermaid ERD)
│   ├── TEST_PLAN.md          # Чекліст тестування для QA
│   ├── DEMO_SCENARIO.md      # Покроковий сценарій демо + багтрекер
│   ├── postman_collection.json # Колекція для Postman
│   └── test_endpoints.ps1    # Скрипт автоматичного тестування ендпоінтів
├── .gitignore                # Фільтр для Dart/Flutter, IDE, .env
└── README.md                 # Загальний опис проєкту
```

---

## ⚡ Швидкий старт для кожного учасника

1. **Мобільному розробнику (TY):** Почніть з вивчення [mobile/README.md](mobile/README.md). Ви вже маєте готові мокові дані в [backend/database/seeds](backend/database/seeds/) і можете верстати екрани прямо зараз!
2. **Розробнику БД (YY):** Ознайомтеся з [docs/DATABASE_ERD.md](docs/DATABASE_ERD.md) та застосуйте [backend/database/schema.sql](backend/database/schema.sql).
3. **Бекенд-розробнику (NL):** Ваш контракт описано в [docs/openapi.yaml](docs/openapi.yaml).
4. **Тестувальнику / Тімліду (ЖЕ):** Запускайте [docs/test_endpoints.ps1](docs/test_endpoints.ps1) або використовуйте Postman для перевірки готовності.

---

## 🌿 Git Workflow

1. Основна гілка: `main` (завжди стабільна, готова для презентації).
2. Робоча інтеграційна гілка: `develop`.
3. Фічі розробляються в окремих гілках від `develop`:
   - `feature/mobile-meta-screen`
   - `feature/backend-opendota-worker`
   - `feature/db-seeds-init`
4. Злиття тільки через Pull Request у `develop` після перевірки Тімлідом/QA.
