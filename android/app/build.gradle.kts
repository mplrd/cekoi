plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.twoagames.cekoi"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.twoagames.cekoi"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // L'identifiant d'application AdMob est une donnée du manifeste, lue
        // par le SDK natif au démarrage du processus : contrairement aux
        // identifiants de blocs publicitaires, il ne peut pas passer par
        // --dart-define, qui ne vit que côté Dart. Sans lui, l'application
        // plante à l'initialisation du SDK.
        //
        // Par défaut l'identifiant de test public de Google. Le vrai arrive
        // au build de publication :
        //
        //   flutter build appbundle -Padmob.app.id=ca-app-pub-XXXX~YYYY
        manifestPlaceholders["admobAppId"] =
            (project.findProperty("admob.app.id") as String?)
                ?: "ca-app-pub-3940256099942544~3347511713"
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
