# Règles R8 de l'application.
#
# R8 tourne sur **tout** build de release : c'est le plugin Gradle de Flutter
# qui l'active (`releaseBuildType.isMinifyEnabled = true` dans
# `FlutterPlugin.kt`), pas une option d'ici. Ce fichier est ramassé
# automatiquement dès lors qu'il existe à cet emplacement — il n'y a rien à
# câbler dans `build.gradle.kts`.
#
# Corollaire, et c'est tout le problème : rien de ce qui est écrit ici n'a
# d'effet en debug, et rien de ce que R8 casse ne se voit en debug. Voir
# `tool/fumee.py`.

# Room a besoin du constructeur sans argument de ses implémentations générées.
#
# Room instancie `<MaBase>_Impl` par réflexion : `Class.forName(...)` puis
# `newInstance()`. La règle que room-runtime 2.2.5 embarque de son côté,
# `-keep class * extends androidx.room.RoomDatabase`, ne nomme aucun membre —
# et en **mode complet**, qui est le défaut depuis AGP 8, R8 lit ça comme
# « garde la classe, fais ce que tu veux de son contenu ». Il constate alors
# que la classe n'est instanciée nulle part dans le code qu'il voit, et retire
# le constructeur. `Class.forName` répond donc présent, `newInstance()` lève
# `InstantiationException`, et Room la retraduit en
# « Failed to create an instance of ... ».
#
# La base concernée n'est pas la nôtre — la nôtre est en SQLite via drift, et
# ne connaît pas Room. C'est `androidx.work.impl.WorkDatabase`, arrivée par la
# chaîne google_mobile_ads → play-services-ads 25.4.0 → work-runtime 2.7.0 →
# room-runtime 2.2.5. WorkManager s'initialise depuis un ContentProvider
# (`androidx.startup.InitializationProvider`), c'est-à-dire **à la création du
# processus**, avant `Application.onCreate` et bien avant que le moteur Flutter
# ne démarre : sans cette règle, l'application meurt sur l'appui de l'icône,
# sans qu'une seule ligne de Dart ait été exécutée.
#
# Écrite générique plutôt que sur `WorkDatabase_Impl` : c'est mot pour mot
# celle que Room embarque lui-même depuis la 2.4, et elle couvrira la prochaine
# dépendance qui traînera sa propre base Room sans qu'on ait à repasser ici.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
