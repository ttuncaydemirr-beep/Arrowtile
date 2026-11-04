// Flutter 3.4x şablonuyla (packages/flutter_tools/templates/app/android.tmpl, kaynak: github.com/flutter/flutter) aynı yapı.
// Sürümler şablondaki varsayılanlardır: AGP 9.3.1, Kotlin 2.4.20. `flutter create` farklı sürüm üretiyorsa onları kullanın.
pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.3.1" apply false
    id("org.jetbrains.kotlin.android") version "2.4.20" apply false
}

include(":app")
