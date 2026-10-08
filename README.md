# 🥭 MangoDota

Мобільний інтерактивний асистент та довідник з Dota 2 (актуальна мета з OpenDota + персоналізовані AI-білди від Google Gemini).  
Проєкт розроблено в рамках хакатону командою **Kakatone**.

---

## 👥 Команда та розподіл ролей

- **Team Lead & QA / Тестувальник (ЖЕ):** Загальна архітектура, контроль стандартів розробки, Git-процеси, тестування API та клієнта, фінальний реліз і демо.
- **Backend - API & Business Logic (NL):** Dart (`shelf`) сервер, інтеграція OpenDota API та Google Gemini API (`gemini-3.5-flash-lite`), фоновий воркер оновлення мети, ендпоінти, Dockerfile.
- **Backend - Database (YY):** Проєктування та налаштування БД (**SQLite 3**), сід-скрипт для Dota 2, резервний дамп даних.
- **Frontend - Mobile (TY):** Flutter-додаток (`dio`, `Riverpod`, локальний кеш у `Hive`), екран мети (тіри S–C), картки героїв та AI-білдів.

---

## 🏗️ Архітектура та структура репозиторію

Репозиторій організовано за монорепо-структурою для швидкої синхронізації та уникнення конфліктів у Git:

```text
hakatone/
├── backend/                  # Серверна частина (Dart shelf + Dockerfile)
│   ├── database/             # База даних (SQLite 3)
│   │   ├── schema.sql        # Схема створення таблиць SQLite
│   │   └── seeds/            # Готові початкові дані (dota2.json, meta.json fallback)
│   └── README.md             # Інструкції для Backend-розробника
├── mobile/                   # Клієнтська мобільна частина (Flutter)
│   └── README.md             # Інструкції для Mobile-розробника
├── docs/                     # Проєктна документація
│   ├── openapi.yaml          # Єдиний контракт API (OpenAPI 3.0, Gemini AI)
│   ├── DATABASE_ERD.md       # Діаграма бази даних SQLite (Mermaid ERD)
│   ├── TEST_PLAN.md          # Чекліст тестування для QA
│   ├── DEMO_SCENARIO.md      # Покроковий сценарій демо + багтрекер
│   ├── postman_collection.json # Колекція для Postman
│   └── test_endpoints.ps1    # Скрипт автоматичного тестування ендпоінтів
├── .gitignore                # Фільтр для Dart/Flutter, IDE, .env (pubspec.lock відстежується)
└── README.md                 # Загальний опис проєкту
```

---

## ⚡ Швидкий старт для кожного учасника

1. **Мобільному розробнику (TY):** Почніть з вивчення [mobile/README.md](mobile/README.md). Моделі відповідають [docs/openapi.yaml](docs/openapi.yaml) та [backend/database/seeds/dota2.json](backend/database/seeds/dota2.json).
2. **Розробнику БД (YY):** Ознайомтеся з [docs/DATABASE_ERD.md](docs/DATABASE_ERD.md) та застосуйте чистий SQLite3 скрипт [backend/database/schema.sql](backend/database/schema.sql).
3. **Бекенд-розробнику (NL):** Ваш контракт описано в [docs/openapi.yaml](docs/openapi.yaml). AI працює через `GEMINI_API_KEY`.
4. **Тестувальнику / Тімліду (ЖЕ):** Запускайте [docs/test_endpoints.ps1](docs/test_endpoints.ps1) або використовуйте Postman для перевірки готовності.

---

## 🌿 Git Workflow

1. Основна гілка: `main` (завжди стабільна, готова для презентації).
2. Робоча інтеграційна гілка: `develop`.
3. Фічі розробляються в окремих гілках від `develop`:
   - `feature/main-menu` (TY)
   - `feature/opendota-sync` (NL)
   - `feature/db-seeds-init` (YY)
4. Злиття тільки через Pull Request у `develop` після перевірки Тімлідом/QA.


## Tech Stack

![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![SQLite](https://img.shields.io/badge/SQLite-003B57?style=for-the-badge&logo=sqlite&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)
![Google Gemini](https://img.shields.io/badge/Google%20Gemini-8E75B2?style=for-the-badge&logo=googlegemini&logoColor=white)
![Render](https://img.shields.io/badge/Render-46E3B7?style=for-the-badge&logo=render&logoColor=black)
![JWT](https://img.shields.io/badge/JWT-black?style=for-the-badge&logo=JSON%20web%20tokens)
