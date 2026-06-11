plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val envKeystoreFile = System.getenv("VOLEO_KEYSTORE_PATH")
val envKeyAlias = System.getenv("VOLEO_KEY_ALIAS")
val envStorePassword = System.getenv("VOLEO_STORE_PASSWORD")
val envKeyPassword = System.getenv("VOLEO_KEY_PASSWORD")

val hasSigningConfig = envKeystoreFile != null && envKeyAlias != null &&
        envStorePassword != null && envKeyPassword != null

android {
    namespace = "de.capycode.voleo"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        if (hasSigningConfig) {
            create("release") {
                storeFile = file(envKeystoreFile!!)
                storePassword = envStorePassword
                keyAlias = envKeyAlias
                keyPassword = envKeyPassword
            }
            getByName("debug") {
                storeFile = file(envKeystoreFile!!)
                storePassword = envStorePassword
                keyAlias = envKeyAlias
                keyPassword = envKeyPassword
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
