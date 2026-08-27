import 'package:cekoi/domain/engine/game_phase.dart';
import 'package:cekoi/domain/engine/game_state.dart';
import 'package:cekoi/features/play/presentation/widgets/tie_break_view.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';
import '../../support/geometrie.dart';
import '../../support/partie.dart';

/// Le départage (R5.3), mesuré comme la face de carte du jeu.
///
/// L'écran avait déjà quatre tests de géométrie, dans `end_of_game_test.dart`,
/// et ils ne voyaient pas ce que celui-ci mesure. Trois raisons, et chacune
/// suffit :
///
/// * ils tournent en **Ahem**, la police de secours de `flutter test`, qui rend
///   chaque glyphe comme un carré du corps — un rapport de 1,7 avec Roboto ;
/// * ils montent l'écran **sans le thème de l'application**, donc mesurent la
///   typographie Material par défaut et non celle qui est livrée ;
/// * ils s'arrêtent à ×1,3, et n'ont jamais posé de carte longue — la seule
///   qui exerce `TexteDeCarte`.
///
/// Or c'est ici que le repli a le plus de chances de céder : la boîte de la
/// carte est plafonnée à 40 % de la hauteur utile, contre les deux tiers de
/// l'écran de jeu, et il n'y a **aucune autre sortie que les boutons de cet
/// écran**. Un bouton sous le bord et R5.3 ne peut plus être tranchée, donc la
/// partie ne peut plus se terminer.
void main() {
  late AppLocalizations l10n;
  late ProviderContainer container;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('fr'));
    await exigerLesVraiesPolices();
  });

  /// Une partie arrêtée sur le départage, avec [texte] sur la carte.
  ///
  /// Toutes les équipes sont à égalité : c'est la partie où personne n'a rien
  /// trouvé, et c'est la seule façon d'en amener dix sur cet écran.
  GameState departage(String texte, {int equipes = 3, String? nomLong}) {
    var game = testGame(cardCount: 12, teamCount: equipes);
    if (nomLong != null) {
      game = game.copyWith(
        teams: [
          game.teams.first.copyWith(name: nomLong),
          ...game.teams.skip(1),
        ],
      );
    }
    return game.copyWith(
      phase: GamePhase.tieBreak,
      roundIndex: game.rounds.length - 1,
      pile: const [],
      turn: null,
      tieBreakTeamIds: [for (var i = 1; i <= equipes; i++) 'team-$i'],
      tieBreakReserve: [testCard(texte)],
    );
  }

  Future<void> poser(
    WidgetTester tester,
    GameState game, {
    Size taille = const Size(360, 800),
    double echelleTexte = 1,
  }) async {
    container = await monterLaPartie(
      tester,
      game,
      taille: taille,
      echelleTexte: echelleTexte,
    );
    expect(find.byType(TieBreakView), findsOneWidget);
  }

  Future<void> ranger(WidgetTester tester) => rangerLaPartie(tester, container);

  /// Ce que la carte du départage affiche vraiment.
  ///
  /// Même mesure que `game_card_face_layout_test.dart`, et pour la même
  /// raison : la taille déclarée par le style ne dit rien, entre elle et l'œil
  /// il y a le réglage système puis l'échelle de `FittedBox`. `getRect`
  /// traverse la transformation, la mise en page ne la voit pas.
  ({double taillePeinte, int lignes, double reduction}) mesurer(
    WidgetTester tester,
    String texte,
  ) {
    // Un seul finder pour les deux mesures : sans ça, un même texte présent
    // deux fois à l'écran ferait lever `getRect` sans qu'on comprenne pourquoi.
    final carte = find.descendant(
      of: find.byType(TieBreakView),
      matching: find.text(texte),
    );
    final para = tester.renderObject<RenderParagraph>(carte);
    final declaree = para.text.style?.fontSize;
    expect(
      declaree,
      isNotNull,
      reason: 'le style de la carte doit fixer une taille',
    );

    final peinte = tester.getRect(carte);
    final echelle = peinte.height / para.size.height;
    final uneLigne = para.getMinIntrinsicHeight(double.infinity);

    return (
      taillePeinte: para.textScaler.scale(declaree!) * echelle,
      lignes: (para.size.height / uneLigne).round(),
      reduction: echelle,
    );
  }

  group('la carte du départage reste lisible', () {
    /// Les longueurs mesurées sur un 360 × 640, et ce que chacune doit tenir.
    ///
    /// Relevé : *Chat* sort à 45,0 px sur une ligne, la situation à 45,0 px sur
    /// trois, la carte à la borne à 44,3 px sur cinq ; à ×2, *Chat* double à
    /// 90,0 px et la carte à la borne tient ses 44,2 px sur cinq lignes. Les
    /// planchers sont ces valeurs avec un sixième de marge — ils doivent
    /// survivre à une dérive de métriques entre deux versions de Flutter, pas
    /// épouser la métrique du jour. Les lignes exigées sont, pour la même
    /// raison, une de moins que le relevé, sauf pour un mot seul : là c'est
    /// une **égalité**, parce que « au moins une ligne » est vrai de tout
    /// paragraphe non vide et ne peut donc pas échouer.
    ///
    /// **Ce qui porte le test, c'est `reduction`.** Elle vaut 1 quand la taille
    /// retenue tenait déjà, c'est-à-dire quand le texte a été *composé*. Le
    /// défaut que `TexteDeCarte` corrige composait tout sur une seule ligne
    /// avant de l'écraser : une réduction très inférieure à 1, et une carte à
    /// la borne à 10 px de haut.
    for (final (libelle, texte, echelle, plancher, lignes)
        in <(String, String, double, double, Matcher)>[
          ('un mot court', 'Chat', 1.0, 38, equals(1)),
          (
            'une situation',
            'Se cogner le petit orteil dans le meuble',
            1.0,
            38,
            greaterThanOrEqualTo(2),
          ),
          (
            'une carte à la borne',
            'Retrouver ses lunettes sur sa tête après les avoir cherchées',
            1.0,
            38,
            greaterThanOrEqualTo(4),
          ),
          // Le maximum du réglage d'Android. Un mot court double vraiment — la
          // boîte a la place — tandis que la carte longue rend l'agrandissement
          // en lignes plutôt qu'en corps, ce qui est le bon arbitrage : cinq
          // lignes lisibles valent mieux qu'une ligne écrasée.
          ('un mot court à ×2', 'Chat', 2.0, 75, equals(1)),
          (
            'une carte à la borne à ×2',
            'Retrouver ses lunettes sur sa tête après les avoir cherchées',
            2.0,
            38,
            greaterThanOrEqualTo(4),
          ),
        ]) {
      testWidgets('$libelle tient sa taille', (tester) async {
        await poser(
          tester,
          departage(texte),
          taille: const Size(360, 640),
          echelleTexte: echelle,
        );

        final m = mesurer(tester, texte);

        expect(
          m.taillePeinte,
          greaterThanOrEqualTo(plancher),
          reason:
              'la carte sort à ${m.taillePeinte.toStringAsFixed(1)} px peints, '
              'sur ${m.lignes} ligne(s)',
        );
        expect(
          m.lignes,
          lignes,
          reason:
              'le texte se compose sur ${m.lignes} ligne(s) : il est écrasé au '
              'lieu d être replié',
        );
        // `BoxFit.scaleDown` n'agrandit jamais : la borne haute est acquise,
        // et c'est bien un plancher qu'on pose.
        expect(
          m.reduction,
          inInclusiveRange(0.98, 1),
          reason:
              'le texte est écrasé de ${((1 - m.reduction) * 100).round()} % : '
              'la taille retenue ne tenait pas dans la boîte',
        );
        aucunTexteRogne(tester);
        await ranger(tester);
      });
    }
  });

  testWidgets('le titre reste centré à taille de texte normale', (
    tester,
  ) async {
    // `TexteQuiTient` ne porte pas d'alignement de texte par défaut, et le
    // titre vit sous un `CrossAxisAlignment.stretch` : sans `textAlign`, il
    // passait silencieusement à gauche pour tout le monde — c'est-à-dire dans
    // le cas où il n'y avait rien à corriger.
    await poser(tester, departage('Chat'), taille: const Size(360, 640));

    resteCentre(tester, find.text(l10n.tieBreakTitle));
    await ranger(tester);
  });

  testWidgets('un nom d équipe long ne se fait pas rogner sur son bouton', (
    tester,
  ) async {
    // Le nom d'équipe est la seule chaîne de l'application que rien ne borne :
    // le champ de l'étape des équipes n'a pas de `maxLength`. Les tests
    // existants du départage nomment les équipes « team-1 », dont le trait
    // d'union est justement un point de coupure — ils ne pouvaient rien voir.
    //
    // Le bouton reste tapable quoi qu'il arrive, donc R5.3 reste tranchable.
    // Ce qu'on perd, c'est de pouvoir distinguer deux noms de même début, sur
    // le seul écran où l'on désigne une équipe par son nom.
    const nom = 'Anticonstitution';

    await poser(
      tester,
      departage('Chat', nomLong: nom),
      taille: const Size(360, 640),
      echelleTexte: 2,
    );

    expect(find.text(l10n.tieBreakWinner(nom)), findsOneWidget);
    await resteAtteignable(tester, find.text(l10n.tieBreakWinner(nom)));
    aucunTexteRogne(tester);
    await ranger(tester);
  });

  group('rien ne sort de l écran, ni ne se rogne', () {
    /// Trois équipes, la forme courante d'une égalité, et dix, le plafond que
    /// R8.1 promet utilisable.
    ///
    /// ×3,1 est le maximum d'iOS (AX5). Android s'arrête à ×2 ; l'écran n'a
    /// jamais tourné sur iOS, et c'est justement pour ça qu'il est mesuré ici.
    for (final (equipes, taille, echelle) in const [
      (3, Size(360, 800), 2.0),
      (3, Size(360, 640), 2.0),
      (3, Size(360, 640), 3.1),
      (10, Size(360, 800), 2.0),
      (10, Size(360, 640), 3.1),
    ]) {
      final ecran = '${taille.width.toInt()}×${taille.height.toInt()}';
      testWidgets('$equipes équipes sur $ecran à ×$echelle', (tester) async {
        // Une carte à la borne de soixante caractères, faite de vrais mots :
        // c'est elle qui pousse la boîte contre son plafond de 40 %, et un
        // pavé d'une seule lettre ne replierait nulle part — cas dégénéré déjà
        // couvert par `game_card_face_layout_test.dart`.
        const texte =
            'Retrouver ses lunettes sur sa tête après les avoir '
            'cherchées';

        await poser(
          tester,
          departage(texte, equipes: equipes),
          taille: taille,
          echelleTexte: echelle,
        );

        // Un débordement de `RenderFlex` remonte comme exception de test.
        expect(tester.takeException(), isNull);

        // Chaque équipe reste réellement désignable — pas seulement visible.
        // Sans ces boutons, R5.3 ne peut plus être tranchée et la partie ne
        // peut plus se terminer.
        for (var i = 1; i <= equipes; i++) {
          await resteAtteignable(
            tester,
            find.text(l10n.tieBreakWinner('team-$i')),
          );
        }
        await resteAtteignable(tester, find.text(l10n.actionTieBreakRestart));

        // Et ce qu'aucune exception ne signale : un texte plus large que sa
        // boîte est simplement coupé, et l'écran reste vert.
        aucunTexteRogne(tester);
        await ranger(tester);
      });
    }
  });
}
