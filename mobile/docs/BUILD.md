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
| `USE_MOCKS` | `false` | `true` — мета й картки з `assets/mocks` без мережі. Профіль завжди з OpenDota |

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

Release-APK підписується релізним ключем, якщо він заданий, інакше — debug-ключем цієї машини (як раніше):

- локально — файл `android/key.properties` (у git не потрапляє):
  ```properties
  storeFile=C:/шлях/до/mangodota-release.jks
  storePassword=...
  keyAlias=mangodota
  keyPassword=...
  ```
- у GitHub Actions — змінні `ANDROID_KEYSTORE_PATH`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` (workflow задає їх сам із секретів, див. «Реліз»).

Автооновлення працює лише між APK з одним і тим самим ключем: APK, зібраний локально debug-ключем, не оновиться на реліз із GitHub.

## Реліз і автооновлення

Застосунок при старті (не частіше разу на добу, лише релізна збірка на Android) питає `https://api.github.com/repos/rei968/hakatone/releases/latest`. Якщо там новіша версія з APK, він пропонує «Оновити», завантажує APK, перевіряє SHA-256 і відкриває системне встановлення. Репозиторій задає `UPDATE_REPO` у `config/app.json`; порожнє значення вимикає перевірку.

### Один раз: релізний ключ і секрети

1. Згенеруйте ключ (JDK 17, `keytool` питає паролі сам). Файл і паролі нікуди не комітьте й збережіть у надійному місці: без цього ключа оновлення вже встановленого застосунку неможливі.
   ```bash
   keytool -genkeypair -v -keystore mangodota-release.jks -alias mangodota -keyalg RSA -keysize 2048 -validity 10000
   ```
2. GitHub → репозиторій → Settings → Secrets and variables → Actions → New repository secret, чотири секрети:
   - `ANDROID_KEYSTORE_BASE64` — вміст `.jks` у base64. PowerShell: `[Convert]::ToBase64String([IO.File]::ReadAllBytes("mangodota-release.jks")) | Set-Clipboard`
   - `ANDROID_KEYSTORE_PASSWORD` — пароль сховища;
   - `ANDROID_KEY_ALIAS` — `mangodota`;
   - `ANDROID_KEY_PASSWORD` — пароль ключа (якщо keytool не питав окремо — той самий).
3. На телефонах, де стоїть APK, підписаний debug-ключем, перший реліз ставиться вручну: видаліть старий застосунок і встановіть APK зі сторінки Releases. Далі оновлення приходять самі.

### Кожен реліз

1. Код у `main` (або іншій гілці, з якої випускаєте).
2. Тег з новою версією — вона має бути більшою за попередню:
   ```bash
   git tag v0.2.0
   ```
   ```bash
   git push origin v0.2.0
   ```
   Або без тегу локально: Actions → Android release → Run workflow → версія `0.2.0`.
3. Workflow `.github/workflows/android-release.yml` проганяє `flutter analyze` і `flutter test`, збирає APK з версією `0.2.0` і `versionCode` 2000 (`major·1000000 + minor·1000 + patch`) та публікує `MangoDota-0.2.0.apk` у Releases.
4. Протягом доби кожен застосунок запропонує оновлення (або одразу після перезапуску, якщо доба з останньої перевірки минула).

## Перед демо

- Бекенд на Render засинає після ~15 хв без запитів. За кілька хвилин до демо відкрийте застосунок або `https://hakatone.onrender.com/api/health`, щоб він прокинувся.
- Вхід через Steam відкриває сторінку Steam у WebView застосунку. Якщо Steam недоступний, у профілі є «Увійти за Steam ID або посиланням».
- Офлайн-демо: відкрийте мету й картку Pudge з інтернетом, потім увімкніть режим польоту — застосунок покаже збережені дані.

## Довідники іконок

Назви предметів і здібностей з білдів перетворюються на картинки Steam CDN через `assets/data/*.json`. Після великого патча оновіть їх: `dart run tool/generate_dota_assets.dart` (з `mobile/`).

## Іконки

Іконки згенеровані з логотипа в коді. Якщо логотип зміниться: `flutter test tool/generate_icons.dart` (запускати з `mobile/`).
