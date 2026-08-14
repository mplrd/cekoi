import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Les identifiants de la clé de signature, lus dans `android/key.properties`.
//
// Hors du dépôt, et pour de bon : `android/.gitignore` couvre `key.properties`,
// `*.jks` et `*.keystore`, et le `.gitignore` racine les rattrape où qu'ils
// soient dans l'arbre.
//
// Absent chez qui n'a pas la clé — la CI, une machine fraîchement clonée — d'où
// la lecture conditionnelle plutôt qu'un fichier d'exemple à copier : un build
// de debug ne doit rien demander à personne.
//
// Lu en UTF-8 explicitement : `Properties.load(InputStream)` décode en
// ISO-8859-1, donc un mot de passe accentué saisi dans un éditeur moderne
// devient « keystore password was incorrect », sans autre indice. Sur un
// projet francophone, c'est l'après-midi qu'on ne veut pas perdre.
val signingKeyFile = rootProject.file("key.properties")
val signingProperties =
    Properties().apply {
        if (signingKeyFile.exists()) {
            signingKeyFile.reader(Charsets.UTF_8).use { load(it) }
        }
    }

// Les quatre champs, pas seulement le premier.
//
// N'en tester qu'un laisserait passer un `key.properties` amputé d'une faute de
// frappe : configuration de signature aux champs nuls, aucun avertissement
// puisque la clé est réputée présente, et selon la version d'AGP un artefact
// carrément non signé. C'est exactement le cas que tout ce fichier existe pour
// empêcher.
val signingFields = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
val missingSigningFields =
    signingFields.filter { signingProperties.getProperty(it).isNullOrBlank() }

// Fichier présent mais incomplet : c'est une faute de frappe, pas une absence
// de clé. Y retomber en silence sur la clé de debug serait pire que d'échouer,
// puisque c'est le cas où quelqu'un croit produire un artefact signé.
if (signingKeyFile.exists() && missingSigningFields.isNotEmpty()) {
    throw GradleException(
        "android/key.properties est incomplet — champs manquants : " +
            "${missingSigningFields.joinToString(", ")}. " +
            "Voir docs/ADMINISTRATIF.md.",
    )
}
if (signingKeyFile.exists() && !file(signingProperties.getProperty("storeFile")).exists()) {
    throw GradleException(
        "Le keystore déclaré dans android/key.properties est introuvable : " +
            "${signingProperties.getProperty("storeFile")}. " +
            "Chemin absolu attendu, avec des slashs — dans un .properties, " +
            "l'antislash est un caractère d'échappement.",
    )
}

val hasSigningKey = signingKeyFile.exists()

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

    signingConfigs {
        // Créée seulement si la clé existe : une configuration aux champs nuls
        // fait échouer le build de debug, qui n'a rien à voir avec elle.
        if (hasSigningKey) {
            create("release") {
                storeFile = file(signingProperties.getProperty("storeFile"))
                storePassword = signingProperties.getProperty("storePassword")
                keyAlias = signingProperties.getProperty("keyAlias")
                keyPassword = signingProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Sans clé, on retombe sur celle de debug pour que `flutter run
            // --release` reste possible : c'est le seul moyen de juger les
            // performances réelles sur un téléphone, et l'exiger signé
            // rendrait la mesure impossible tant que la clé n'existe pas.
            //
            // Un artefact ainsi signé n'est pas publiable, et les stores le
            // refusent — mais silencieusement pour qui le construit, d'où
            // l'avertissement ci-dessous.
            signingConfig =
                signingConfigs.getByName(if (hasSigningKey) "release" else "debug")
        }
    }
}

// Averti au moment où ça compte, pas à chaque build.
//
// Le mettre dans le bloc `release` ci-dessus le ferait apparaître à chaque
// compilation de debug, CI comprise : un avertissement permanent finit par ne
// plus être lu, et c'est précisément celui-ci qu'il ne faut pas rater.
//
// `error` et non `warn` : l'outil Flutter lance Gradle avec `-q` hors mode
// verbeux, et `-q` ne laisse passer que QUIET et ERROR. Un `logger.warn` est
// donc invisible sur `flutter build apk --release` — c'est-à-dire sur le seul
// chemin que quelqu'un emprunte — et ne se voit qu'en appelant `gradlew`
// directement, ce que personne ne fait. Ce n'est pas une erreur de build : le
// build réussit, et son exit code ne change pas.
//
// Le test porte sur les noms de tâches demandés, ce qui couvre toutes les
// invocations de l'outil Flutter — `assembleRelease`, `bundleRelease`. Un
// `gradlew build` ou l'abréviation `gradlew aR` y échapperaient ; ce n'est pas
// ainsi que ce projet se construit.
if (!hasSigningKey &&
    gradle.startParameter.taskNames.any { it.contains("Release") }
) {
    logger.error(
        "ATTENTION : build de release signé avec la clé de debug. " +
            "android/key.properties est absent — cet artefact n'est pas " +
            "publiable, et ne pourra pas être mis à jour par un artefact " +
            "signé de la vraie clé. Voir docs/ADMINISTRATIF.md.",
    )
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
