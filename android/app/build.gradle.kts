plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreFile = System.getenv("VOLEO_KEYSTORE_PATH")
val keystoreAlias = System.getenv("VOLEO_KEY_ALIAS")
val keystorePassword = System.getenv("VOLEO_STORE_PASSWORD")
val keyPassword = System.getenv("VOLEO_KEY_PASSWORD")

val hasSigningConfig = keystoreFile != null && keystoreAlias != null &&
        keystorePassword != null && keyPassword != null

android {
    namespace = "de.capycode.voleo"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    if (hasSigningConfig) {
        signingConfigs {
            create("release") {
                storeFile = file(keystoreFile!!)
                storePassword = keystorePassword
                keyAlias = keystoreAlias
                keyPassword = keyPassword
            }
        }
    }

    defaultConfig {
        applicationId = "de.capycode.voleo"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = if (hasSigningConfig) {
                signingConfigs.getByName("release")
            } else {
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
