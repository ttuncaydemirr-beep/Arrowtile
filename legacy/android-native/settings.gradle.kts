// Arrowtile — Android Studio projesi (WebView kabuğu). Oyunun kendisi ../game/ klasöründedir (tek kaynak).
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}
rootProject.name = "Arrowtile"
include(":app")
