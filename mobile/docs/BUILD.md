# Збірка APK MangoDota

Інструкція для того, хто збирає APK на машині з Android Studio.

## Що потрібно

- Flutter stable 3.47 або новіший (`flutter --version`).
- Android Studio з Android SDK 36 і JDK 17 (входить в Android Studio). Перевірка: `flutter doctor`.

## Налаштування

Усе, що залежить від середовища, лежить в одному файлі — `mobile/config/app.json`. Його читають і Dart (`--dart-define-from-file`), і Gradle.

| Ключ | Зараз | Що означає |
|---|---|---|
| `APP_NAME` | `MangoDota` | Назва під іконкою |
| `APPLICATION_ID` | `com.kakatone.mangodota` | Ідентифікатор застосунку. Після першого встановлення не змінювати |
| `API_BASE_URL` | `https://hakatone.onrender.com` | Бекенд команди. Для локального сервера: емулятор — `http://10.0.2.2:8080`, телефон — `http://<IP ноутбука>:8080` |
| `USE_MOCKS` | `false` | `true` — мета й картки з `assets/mocks` без мережі |
| `MOCK_AUTH` | `false` | `true` — вхід на моках (`player@example.com` / `secret123`) |

Якщо `API_BASE_URL` починається з `http://`, Gradle сам дозволяє незашифрований трафік (`usesCleartextTraffic`). Для `https` він вимкнений.

## Збірка

```bash
cd mobile
flutter pub get
flutter test
flutter build apk --release --dart-define-from-file=config/app.json
```

Готовий файл: `mobile/build/app/outputs/flutter-apk/app-release.apk`. Його можна скинути на телефон і встановити (потрібно дозволити встановлення з невідомих джерел).

## Підпис

Зараз release-APK підписується debug-ключем: для хакатону й демо цього досить. Для Google Play потрібен власний ключ: створіть його командою `keytool` за інструкцією https://docs.flutter.dev/deployment/android#sign-the-app і не комітьте keystore та паролі в репозиторій.

## Перед демо

- Бекенд на Render засинає після ~15 хв без запитів. За кілька хвилин до демо відкрийте застосунок або `https://hakatone.onrender.com/api/health`, щоб він прокинувся.
- Після перезапуску сервера зареєстровані акаунти зникають. Просто зареєструйтеся знову.
- Офлайн-демо: відкрийте мету й картку Pudge з інтернетом, потім увімкніть режим польоту — застосунок покаже збережені дані.

## Іконки

Іконки згенеровані з логотипа в коді. Якщо логотип зміниться: `flutter test tool/generate_icons.dart` (запускати з `mobile/`).
