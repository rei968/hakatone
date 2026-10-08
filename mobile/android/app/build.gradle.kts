import groovy.json.JsonSlurper
import java.util.Properties

// Єдине джерело назви, applicationId і адреси API — mobile/config/app.json
// (його ж читає Dart через --dart-define-from-file).
@Suppress("UNCHECKED_CAST")
val appConfig = JsonSlurper().parse(rootProject.file("../config/app.json")) as Map<String, String>

// Релізний ключ: локально — android/key.properties, у GitHub Actions — змінні середовища
// (див. mobile/docs/BUILD.md). Обидва варіанти в git не потрапляють.
val keyProperties = Properties().apply {
    rootProject.file("key.properties").takeIf { it.exists() }?.inputStream()?.use { load(it) }
}
fun signingValue(property: String, env: String): String? =
    keyProperties.getProperty(property) ?: System.getenv(env)
val releaseKeystore = signingValue("storeFile", "ANDROID_KEYSTORE_PATH")

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.kakatone.mangodota"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Плагін автооновлення ota_update використовує нові Java API, тож потрібен desugaring.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = appConfig.getValue("APPLICATION_ID")
        manifestPlaceholders["appName"] = appConfig.getValue("APP_NAME")
        // http-бекенд (локальний сервер) потребує cleartext, https (Render) — ні.
        manifestPlaceholders["usesCleartextTraffic"] =
            appConfig.getValue("API_BASE_URL").startsWith("http://").toString()
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseKeystore != null) {
            create("release") {
                storeFile = file(releaseKeystore)
                storePassword = signingValue("storePassword", "ANDROID_KEYSTORE_PASSWORD")
                keyAlias = signingValue("keyAlias", "ANDROID_KEY_ALIAS")
                keyPassword = signingValue("keyPassword", "ANDROID_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            // Автооновлення працює лише між APK з одним ключем, тож релізи в GitHub Releases
            // підписуються релізним ключем. Без нього (локальна збірка) — debug-ключ, як раніше.
            signingConfig = signingConfigs.getByName(if (releaseKeystore != null) "release" else "debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Та сама версія, що в ota_update.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
