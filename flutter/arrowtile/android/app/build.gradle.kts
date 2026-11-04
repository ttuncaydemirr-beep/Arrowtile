import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ---------------------------------------------------------------- Sürüm imzalama (android/key.properties)
// Anahtar deposu bu projede OLUŞTURULMAZ ve depoya konmaz. android/key.properties.example dosyasını
// key.properties olarak kopyalayıp doldurun (README.md "İmzalama"). Dosya yoksa release derlemesi DEBUG anahtarıyla
// imzalanır: `flutter run --release` çalışır, ancak bu paket Play Console'a YÜKLENEMEZ.
val keyProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val hasReleaseKey = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
    .all { !keyProps.getProperty(it).isNullOrBlank() }

android {
    namespace = "com.arrowtile.puzzle"
    // Google Play hedef API şartı: yeni uygulamalar ve güncellemeler API 36 (Android 16) hedeflemeli.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.arrowtile.puzzle" // native Android projesiyle aynı → Play'de aynı uygulama
        minSdk = 24
        targetSdk = 36
        // pubspec.yaml: version: 1.0.0+2  →  versionName 1.0.0, versionCode 2
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = rootProject.file(keyProps.getProperty("storeFile"))
                storePassword = keyProps.getProperty("storePassword")
                keyAlias = keyProps.getProperty("keyAlias")
                keyPassword = keyProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            signingConfig = if (hasReleaseKey) signingConfigs.getByName("release") else signingConfigs.getByName("debug")
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
