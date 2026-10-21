import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ---- Yayın imzası (docs/10_android_ios_release_readiness.md §Android imzalama) ----
// Gizli bilgi depoya yazılmaz. Öncelik sırası:
//  1. CI (Codemagic): CM_KEYSTORE_PATH, CM_KEYSTORE_PASSWORD, CM_KEY_ALIAS, CM_KEY_PASSWORD ortam değişkenleri
//  2. Yerel: android/key.properties (storeFile, storePassword, keyAlias, keyPassword); .gitignore'da
// İkisi de yoksa release derlemesi debug anahtarıyla imzalanır ve uyarı yazılır. Bu derleme mağazaya
// YÜKLENEMEZ; yalnızca yerel deneme içindir.
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val ciKeystore: String? = System.getenv("CM_KEYSTORE_PATH")
val releaseStoreFile: String? = ciKeystore ?: keystoreProperties.getProperty("storeFile")
val hasReleaseSigning = releaseStoreFile != null && file(releaseStoreFile).exists()

android {
    namespace = "com.burakhamzali.istanbul_flight"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Uygulama kimliği: Google Play'e ilk yüklemeden sonra DEĞİŞTİRİLEMEZ.
        // Kesinleştirme kullanıcı kararı (docs/10_android_ios_release_readiness.md §Kimlik önerisi).
        applicationId = "com.burakhamzali.istanbul_flight"
        minSdk = flutter.minSdkVersion // Flutter 3.47: 24 (Android 7.0)
        targetSdk = flutter.targetSdkVersion // Flutter 3.47: 36 (Android 16); Google Play şartı: ≥ 35
        versionCode = flutter.versionCode // pubspec.yaml: 1.0.0+1 → 1
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(releaseStoreFile!!)
                storePassword = System.getenv("CM_KEYSTORE_PASSWORD") ?: keystoreProperties.getProperty("storePassword")
                keyAlias = System.getenv("CM_KEY_ALIAS") ?: keystoreProperties.getProperty("keyAlias")
                keyPassword = System.getenv("CM_KEY_PASSWORD") ?: keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                logger.warn("UYARI: Yayın anahtarı bulunamadı; release derlemesi debug anahtarıyla imzalanıyor (mağazaya yüklenemez).")
                signingConfigs.getByName("debug")
            }
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
