import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services") version "4.5.0" apply false
}

// A Gradle property (~/.gradle/gradle.properties, ORG_GRADLE_PROJECT_<name>), else the ignored sallapush.properties.
val sallaPushProperties = Properties().apply {
    val file = rootProject.file("sallapush.properties")
    if (file.isFile) file.inputStream().use { load(it) }
}

fun sallaPushSetting(name: String, default: String): String =
    providers.gradleProperty(name).orNull ?: sallaPushProperties.getProperty(name) ?: default

android {
    namespace = "sa.salla.sallapush_flutter_example"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = sallaPushSetting("sallapushApplicationId", "sa.salla.sallapush.flutter.example")
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["sallaPushAppId"] = sallaPushSetting("sallapushAppId", "")
    }

    buildTypes {
        release {
            // The example is never published: its release build uses the debug key.
            signingConfig = signingConfigs.getByName("debug")
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

// google-services.json is never committed. Without it the app still builds, and SallaPush logs token.firebase_missing.
if (file("google-services.json").isFile) {
    apply(plugin = "com.google.gms.google-services")
}
