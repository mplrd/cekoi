import 'package:cekoi/app/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Thème de l'application.
///
/// Le contexte d'usage guide tout : téléphone tenu à bout de bras, souvent
/// debout, lu par des joueurs à un mètre. D'où des cibles tactiles larges et
/// une typographie généreuse plutôt que les valeurs Material par défaut.
///
/// La palette est **posée**, pas dérivée. `ColorScheme.fromSeed` construisait
/// à partir du corail un brique désaturé qui n'existe nulle part dans le logo,
/// et le posait sur tous les boutons pleins de l'application. Les couleurs
/// viennent donc de [AppColors], qui les tient du dessin.
abstract final class AppTheme {
  /// Hauteur minimale d'une zone tactile principale.
  ///
  /// Material recommande 48. On monte à 64 parce qu'on vise le pouce d'une
  /// personne debout qui ne regarde pas l'écran en permanence.
  static const double minTouchTarget = 64;

  /// Hauteur minimale d'un contrôle secondaire — une tuile de choix, un
  /// nombre d'équipes. Assez haut pour ne pas être un bouton écrasé sur une
  /// ligne, assez bas pour qu'il en tienne plusieurs de front.
  static const double minTile = 60;

  /// Rayon commun. Un seul, pour que rien n'ait l'air emprunté ailleurs.
  static const double radius = 18;

  static const BorderRadius _rounded = BorderRadius.all(
    Radius.circular(radius),
  );

  static ThemeData light() => _build();

  /// L'application garde le même visage en thème sombre.
  ///
  /// Le corail pastel *est* l'identité, au même titre que le logo : la
  /// retourner en gris foncé donnerait une seconde application, à concevoir et
  /// à vérifier, pour un jeu qu'on sort le soir entre amis avec la lumière
  /// allumée. C'est un choix, pas un oubli.
  static ThemeData dark() => _build();

  static ThemeData _build() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      // L'action principale est le teal des étincelles : la seule couleur du
      // logo qui porte du texte blanc sans effort.
      primary: AppColors.deep,
      onPrimary: Colors.white,
      primaryContainer: AppColors.secondary,
      onPrimaryContainer: AppColors.ink,
      // Le secondaire est le personnage du logo. Trop clair pour du blanc :
      // il se remplit d'encre.
      secondary: AppColors.secondary,
      onSecondary: AppColors.ink,
      secondaryContainer: AppColors.secondary,
      onSecondaryContainer: AppColors.ink,
      tertiary: AppColors.main,
      onTertiary: AppColors.ink,
      error: AppColors.urgent,
      onError: Colors.white,
      // La surface est le fond corail pastélisé, et non un blanc neutre : les
      // écrans Material qui n'ont pas de fond explicite le prennent d'ici.
      surface: AppColors.ground,
      onSurface: AppColors.ink,
      surfaceContainerHighest: AppColors.groundSoft,
      onSurfaceVariant: AppColors.ink,
      outline: AppColors.main,
      outlineVariant: AppColors.groundSoft,
      shadow: AppColors.ink,
    );

    // Le thème se construit en deux temps, et ce n'est pas un détour.
    //
    // Les styles qu'on pose ici ont besoin d'une police, et un `TextStyle` nu
    // n'en porte aucune : le libellé retombait sur la police par défaut de la
    // plateforme, seul élément de l'écran à ne pas se composer comme le reste.
    // On part donc du `textTheme` que `ThemeData` a composé, qui apporte la
    // famille — et la bonne, celle de la plateforme : figer
    // `Typography.material2021()` aurait imposé Roboto sur iOS, à côté de la
    // police système du reste de l'interface.
    //
    // **La taille, elle, doit être écrite.** `ThemeData.textTheme` ne porte pas
    // encore la géométrie : elle n'est fusionnée qu'au rendu, par le widget
    // `Theme`, selon la catégorie d'écriture de la locale. Un `headlineSmall`
    // pris ici a un `fontSize` nul — sans conséquence pour un style hérité,
    // mais l'`AppBar` *remplace* le style ambiant au lieu de le fusionner, et
    // son titre retombait alors sur les 14 px par défaut de `TextStyle`.
    // Mesuré, pas supposé.
    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.ground,
    );
    final texte = base.textTheme;
    final libelle = texte.labelLarge!.copyWith(
      fontSize: 20,
      fontWeight: FontWeight.w800,
    );

    return base.copyWith(
      // La barre ne se distingue plus du contenu : elle porte le titre et le
      // retour, et disparaît dans le fond. Le bandeau plein qu'elle formait
      // avant coupait chaque écran en deux, avec ses angles arrondis qui
      // laissaient des encoches dans les coins.
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.ground,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: texte.headlineSmall?.copyWith(
          fontSize: 24,
          color: AppColors.ink,
          fontWeight: FontWeight.w800,
        ),
      ),
      // Toutes les actions sont pleines et colorées. Aucune n'est blanche :
      // sur un fond pastel, un bouton blanc ressemble à un trou dans la page.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.deep,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.deep.withValues(alpha: 0.25),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
          minimumSize: const Size.fromHeight(minTouchTarget),
          textStyle: libelle,
          shape: const RoundedRectangleBorder(borderRadius: _rounded),
        ),
      ),
      // L'action secondaire est blanche, cernée du corail de la marque.
      //
      // Elle a été essayée dans le vert du personnage : deux pastels voisins,
      // elle ne se détachait pas du fond. Le blanc tranche, et le liseré dit
      // que c'est une action — un aplat blanc seul ne le dirait pas.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.card,
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.main, width: 3),
          minimumSize: const Size.fromHeight(minTouchTarget),
          textStyle: libelle,
          shape: const RoundedRectangleBorder(borderRadius: _rounded),
        ),
      ),
      // Même les actions discrètes — celles des boîtes de dialogue — gardent
      // une vraie hauteur de doigt.
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.ink,
          minimumSize: const Size(88, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          textStyle: libelle.copyWith(fontSize: 17),
          shape: const RoundedRectangleBorder(borderRadius: _rounded),
        ),
      ),
      // Le bouton flottant est une action principale comme une autre : même
      // teal, même encre blanche. Sans le poser, Material lui donnait le
      // conteneur secondaire et une ombre portée qui cernait la forme d'un
      // trait noir épais sur ce fond pastel.
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.deep,
        foregroundColor: Colors.white,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        extendedTextStyle: libelle.copyWith(fontSize: 17),
        extendedPadding: const EdgeInsets.symmetric(horizontal: 22),
        shape: const RoundedRectangleBorder(borderRadius: _rounded),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.ink,
          minimumSize: const Size.square(52),
        ),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: _rounded),
      ),
      // Les champs sont remplis plutôt que cernés : un contour fin sur fond
      // pastel donne un formulaire fantôme.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.groundSoft,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        // 0,6 et non 0,45 : plus clair, l'indication tombait à 3:1 sur ce
        // fond. Or c'est elle qui porte R8.3 — le nom d'équipe par défaut est
        // un libellé, pas une valeur à effacer — et elle n'est écrite nulle
        // part ailleurs.
        hintStyle: TextStyle(color: AppColors.ink.withValues(alpha: 0.6)),
        border: const OutlineInputBorder(
          borderRadius: _rounded,
          borderSide: BorderSide.none,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: _rounded,
          borderSide: BorderSide.none,
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: _rounded,
          borderSide: BorderSide(color: AppColors.deep, width: 2),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.groundSoft,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: texte.bodyLarge?.copyWith(
          fontSize: 16,
          color: Colors.white,
        ),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: _rounded),
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.ink.withValues(alpha: 0.12),
        space: 1,
        thickness: 1,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.deep
              : Colors.transparent,
        ),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        side: const BorderSide(color: AppColors.ink, width: 2),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : AppColors.groundSoft,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.deep
              : AppColors.ink.withValues(alpha: 0.2),
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: AppColors.deep,
        thumbColor: AppColors.deep,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.deep,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.ink,
        textColor: AppColors.ink,
      ),
    );
  }
}
