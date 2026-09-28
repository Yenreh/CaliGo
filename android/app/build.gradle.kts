import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing key, described by a key.properties that is never
// committed: android/key.properties, which the release workflow writes from
// its secrets, or else private/signing/key.properties, next to the key, for
// local release builds. Its storeFile is relative to the file naming it.
val keystorePropertiesFile = listOf(
    rootProject.file("key.properties"),
    rootProject.file("../private/signing/key.properties"),
).firstOrNull { it.exists() }
val keystoreProperties = Properties()
keystorePropertiesFile?.let { file ->
    FileInputStream(file).use { keystoreProperties.load(it) }
}

android {
    namespace = "com.yenreh.caligo"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.yenreh.caligo"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile != null) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = keystorePropertiesFile.parentFile
                    .resolve(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Without the key, a local release build still runs, signed with
            // the debug key; published releases always carry the real one,
            // or updates stop installing over each other
            signingConfig = if (keystorePropertiesFile != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
