plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.saas.app.saas_app"
    compileSdk = flutter.compileSdkVersion
    // rive_native (mascota ORB) compila rive_text.so y necesita un NDK moderno;
    // el recomendado por el paquete. Ver platform_considerations.md de rive.
    ndkVersion = "27.2.12479018"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications programa avisos con la API de fechas de
        // Java 8, que en Android solo existe a partir de API 26. El
        // "desugaring" la reescribe para las versiones anteriores; sin esto el
        // build de release falla en checkReleaseAarMetadata y ni siquiera
        // empieza a compilar.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.saas.app.saas_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
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

dependencies {
    // La libreria de desugaring que exige flutter_local_notifications. La
    // version es la minima que pide el paquete; subirla no aporta nada aqui.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
