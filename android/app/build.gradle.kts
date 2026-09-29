import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing. Create android/key.properties (never commit it):
//   storePassword=…
//   keyPassword=…
//   keyAlias=upload
//   storeFile=/absolute/path/to/upload-keystore.jks
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKey = keystorePropertiesFile.exists()
if (hasReleaseKey) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "com.kshitijcodecraft.tasktrackr"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications needs java.time on older Android.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.kshitijcodecraft.tasktrackr"
        // Firebase requires 23+; 24 keeps 99%+ of active devices.
        minSdk = 24
        // Google Play requires targeting a recent API level for new apps and updates.
        targetSdk = 36
        // From pubspec.yaml `version: <name>+<code>`. Bump the +code for every Play upload.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig =
                if (hasReleaseKey) {
                    signingConfigs.getByName("release")
                } else {
                    // Lets `flutter run --release` work locally. Play rejects
                    // debug-signed bundles, so add key.properties before uploading.
                    logger.warn("⚠ android/key.properties not found: release is signed with the DEBUG key.")
                    signingConfigs.getByName("debug")
                }
            // R8: shrink, optimise and obfuscate Java/Kotlin, drop unused resources.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
