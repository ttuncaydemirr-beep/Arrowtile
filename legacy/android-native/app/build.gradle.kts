import java.util.Properties

plugins {
    id("com.android.application")
}

// ---------------------------------------------------------------- Sürüm imzalama (keystore.properties)
// Anahtar deposu bu projede OLUŞTURULMAZ ve depoya konmaz. keystore.properties.example dosyasını
// keystore.properties olarak kopyalayıp doldurun (README.md "İmzalı AAB"). Dosya yoksa release
// derlemesi imzasız üretilir; Android Studio > Build > Generate Signed App Bundle de kullanılabilir.
val keystoreProps = Properties().apply {
    val f = rootProject.file("keystore.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val hasReleaseKey = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
    .all { !keystoreProps.getProperty(it).isNullOrBlank() }

android {
    namespace = "com.arrowtile.puzzle"
    // Google Play hedef API şartı (31.08.2026'dan beri): yeni uygulamalar ve güncellemeler API 36 (Android 16) hedeflemeli.
    compileSdk = 36

    defaultConfig {
        applicationId = "com.arrowtile.puzzle"
        minSdk = 24
        targetSdk = 36
        versionCode = 1          // Play'e her yüklemede 1 artırın (2, 3, ...)
        versionName = "1.0.0"
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = rootProject.file(keystoreProps.getProperty("storeFile"))
                storePassword = keystoreProps.getProperty("storePassword")
                keyAlias = keystoreProps.getProperty("keyAlias")
                keyPassword = keystoreProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // R8 (küçültme + karartma) açık. WebView JS arayüzü için keep kuralları proguard-rules.pro içinde.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            if (hasReleaseKey) signingConfig = signingConfigs.getByName("release")
        }
        debug {
            // Debug derlemesi HER ZAMAN Google'ın test reklam kimliklerini kullanır:
            // src/debug/res/values/ads.xml, src/main/res/values/ads.xml'i ezer.
            isMinifyEnabled = false
        }
    }

    buildFeatures {
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    implementation("androidx.activity:activity:1.13.0")      // EdgeToEdge, OnBackPressedDispatcher (androidx.core'u da getirir)
    implementation("androidx.webkit:webkit:1.18.0")          // WebViewAssetLoader
    implementation("com.google.android.gms:play-services-ads:25.5.0")       // AdMob (Google Mobile Ads SDK)
    implementation("com.google.android.ump:user-messaging-platform:4.0.0")  // UMP onay formu (AEA/BK/İsviçre)
    implementation("com.android.billingclient:billing:9.1.0")               // Google Play Billing Library
}

// ---------------------------------------------------------------- Oyun dosyaları: tek kaynak ../game/
// Her derlemede ../../game/ klasörü app/src/main/assets/www/ içine eşitlenir (Sync: fazlalıklar silinir).
// Oyun klasörü yoksa (ör. yalnızca android/ klasörü paylaşıldıysa) mevcut assets/www olduğu gibi kullanılır.
// Elle eşitlemek için: ../../legacy/sync-android.sh
val gameDir: File = rootProject.file("../../game") // legacy/android-native → proje kökündeki game/
val syncGameAssets by tasks.registering(Sync::class) {
    group = "arrowtile"
    description = "Oyun dosyalarını ../game/ klasöründen src/main/assets/www/ içine kopyalar."
    from(gameDir) {
        exclude("**/.DS_Store", "**/Thumbs.db")
    }
    into(layout.projectDirectory.dir("src/main/assets/www"))
    val indexFile = gameDir.resolve("index.html")
    onlyIf { indexFile.exists() }
}
tasks.matching {
    it.name != "syncGameAssets" && it.name != "clean" &&
        (it.name == "preBuild" || it.name.endsWith("Assets") || it.name.startsWith("lint"))
}.configureEach {
    dependsOn(syncGameAssets)
}
