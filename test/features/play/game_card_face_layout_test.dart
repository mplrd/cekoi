import 'package:cekoi/app/clock.dart';
import 'package:cekoi/app/current_game.dart';
import 'package:cekoi/app/preferences.dart';
import 'package:cekoi/app/screen_awake.dart';
import 'package:cekoi/app/theme/app_theme.dart';
import 'package:cekoi/domain/decks/card_length.dart';
import 'package:cekoi/domain/engine/game_state.dart';
import 'package:cekoi/features/play/presentation/game_screen.dart';
import 'package:cekoi/features/play/presentation/widgets/game_card_face.dart';
import 'package:cekoi/l10n/generated/app_localizations.dart';
import 'package:cekoi/services/feedback/feedback.dart';
import 'package:cekoi/services/feedback/game_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';
import '../../support/geometrie.dart';
import '../../support/providers.dart';
import 'play_controller_test.dart' show FakeClock;

/// La carte doit rester lisible à bout de bras, quelle que soit sa longueur.
///
/// Rien ne le voyait, et `aucunTexteRogne` ne pouvait pas : le texte n'est ni
/// rogné ni débordant, il est **réduit**. `FittedBox` mesure son enfant sans
/// borne de largeur, donc le paragraphe n'a jamais de raison de replier ; il se
/// compose sur une seule ligne, puis se fait écraser jusqu'à tenir. La carte
/// reste haute et vide pendant que la phrase devient illisible.
///
/// Ce fichier mesure ce que le narrateur voit vraiment — la taille **peinte**,
/// c'est-à-dire la taille déclarée multipliée par l'échelle qu'applique
/// `FittedBox` — et non la taille que le style demande.
void main() {
  late AppLocalizations l10n;
  late FakeClock clock;
  late ProviderContainer container;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('fr'));
    await exigerLesVraiesPolices();
  });

  /// Une partie dont la carte du dessus porte le texte à mesurer.
  ///
  /// `roundIndex` vaut 1, donc une manche qui offre *Passer* : les deux zones
  /// d'action se partagent alors le bas de l'écran et la carte reçoit la moitié
  /// du reste au lieu des deux tiers. C'est le cas le plus étroit des trois
  /// manches, et c'est celui qu'il faut mesurer.
  GameState partieAvec(String texte) {
    final base = testGame(cardCount: 6);
    final carte = testCard(texte);
    final autres = testCards(5, prefix: 'autre');
    return base.copyWith(
      deck: [carte, ...autres],
      pile: [carte.id, for (final c in autres) c.id],
    );
  }

  Future<void> pumpCarte(
    WidgetTester tester, {
    required GameState game,
    Size taille = const Size(360, 800),
    double echelleTexte = 1,
  }) async {
    clock = FakeClock();
    poserEcran(tester, taille: taille, echelleTexte: echelleTexte);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          monotonicClockProvider.overrideWithValue(clock.read),
          screenAwakeProvider.overrideWithValue(fakeScreenAwake()),
          gameFeedbackProvider.overrideWithValue(const SilentGameFeedback()),
          currentPreferencesProvider.overrideWithValue(fakePreferences()),
        ],
        child: MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // Sans le thème, on mesure la typographie Material par défaut et non
          // celle de l'application.
          theme: AppTheme.light(),
          home: const GameScreen(),
        ),
      ),
    );

    container = ProviderScope.containerOf(
      tester.element(find.byType(GameScreen)),
    );
    container.read(currentGameProvider.notifier).game = game;
    await tester.pumpAndSettle();

    // L'écran s'ouvre sur l'annonce du tour, puis sur un compte à rebours de
    // trois secondes. La carte n'existe qu'après les deux.
    await tester.tap(find.text(l10n.actionStartTurn));
    await clock.advance(tester, const Duration(seconds: 3));
    expect(find.byType(GameCardFace), findsOneWidget);
  }

  /// Ce que la carte affiche vraiment.
  ///
  /// La taille déclarée par le style ne dit rien : entre elle et l'écran il y a
  /// l'échelle de `FittedBox`. On la retrouve en comparant la boîte **peinte**
  /// du paragraphe — `getRect` traverse la transformation — à sa boîte de mise
  /// en page.
  ({double taillePeinte, int lignes, double reduction}) mesurer(
    WidgetTester tester,
  ) {
    final texte = find.descendant(
      of: find.byType(GameCardFace),
      matching: find.byType(RichText),
    );
    final para = tester.renderObject<RenderParagraph>(texte);
    final declaree = para.text.style?.fontSize;
    expect(
      declaree,
      isNotNull,
      reason: 'le style de la carte doit fixer une taille',
    );

    final peinte = tester.getRect(texte);
    final echelle = peinte.height / para.size.height;

    // La taille déclarée n'est pas celle qui arrive à l'œil : le réglage
    // système la multiplie avant que `FittedBox` ne la réduise. Sans ce
    // facteur, une mesure à ×2 rendait la moitié de ce qui est peint.
    final avecReglage = para.textScaler.scale(declaree!);

    // Le nombre de lignes se déduit sans API privée : la hauteur d'une seule
    // ligne est celle que le paragraphe demande quand rien ne borne sa largeur.
    final uneLigne = para.getMinIntrinsicHeight(double.infinity);

    return (
      taillePeinte: avecReglage * echelle,
      lignes: (para.size.height / uneLigne).round(),
      // 1 quand rien n'a été écrasé : la taille choisie tenait déjà. C'est la
      // propriété qui distingue « composé » de « réduit », et c'est elle que le
      // défaut violait sur les quatre longueurs.
      reduction: echelle,
    );
  }

  /// Les quatre longueurs mesurées, à deux échelles.
  ///
  /// Les trois premières sont de vraies cartes du paquet livré ; la quatrième
  /// est un gabarit à la borne que `CONTENU.md` autorise.
  ///
  /// **C'est `reduction` qui porte le test, pas le plancher.** Les planchers
  /// sont larges à dessein — ils doivent survivre à une dérive de métriques
  /// entre versions de Flutter — et le premier cas, « Chat », est un témoin :
  /// il sortait déjà à 60 px avant correction et passerait des deux côtés. Ce
  /// qui rougit sur un retour en arrière, c'est le nombre de lignes et
  /// l'absence de réduction : le défaut composait tout sur une seule ligne
  /// avant de l'écraser.
  const cartes = <(String, String, double, double, int)>[
    ('un mot court', 'Chat', 1, 55, 1),
    ('un nom propre', 'Zinédine Zidane', 1, 50, 2),
    ('une situation', 'Se cogner le petit orteil dans le meuble', 1, 30, 2),
    (
      'la borne',
      'Retrouver ses lunettes sur sa tête après les avoir cherchées',
      1,
      25,
      2,
    ),
    // Le maximum du réglage d'Android. La taille peinte ne bouge presque pas,
    // et c'est le propre de cet écran : la carte tient dans sa boîte quoi qu'il
    // arrive. Ce qui est vérifié ici, c'est que la recherche ne s'effondre pas
    // sur son plancher — `tailleMinimale` est une taille **déclarée**, donc à
    // ×2 elle vaut 32 px peints, et la branche « même le plancher ne tient
    // pas » se déclencherait bien plus tôt.
    ('un mot court à ×2', 'Chat', 2, 100, 1),
    ('un nom propre à ×2', 'Zinédine Zidane', 2, 55, 2),
    (
      'une situation à ×2',
      'Se cogner le petit orteil dans le meuble',
      2,
      30,
      3,
    ),
    (
      'la borne à ×2',
      'Retrouver ses lunettes sur sa tête après les avoir cherchées',
      2,
      25,
      3,
    ),
  ];

  for (final (libelle, texte, echelle, plancher, lignesMini) in cartes) {
    testWidgets('$libelle (${texte.length} caractères) reste lisible', (
      tester,
    ) async {
      await pumpCarte(tester, game: partieAvec(texte), echelleTexte: echelle);
      final m = mesurer(tester);

      expect(
        m.taillePeinte,
        greaterThanOrEqualTo(plancher),
        reason:
            "« $texte » s'affiche à ${m.taillePeinte.toStringAsFixed(1)} px, "
            'sur ${m.lignes} ligne(s)',
      );

      expect(
        m.lignes,
        greaterThanOrEqualTo(lignesMini),
        reason:
            'le texte doit replier aux espaces : une seule ligne signifie que '
            "la largeur ne lui a pas été donnée, et qu'il ne tient que réduit",
      );

      // La taille est choisie, pas subie : rien n'est écrasé après coup, donc
      // le bloc occupe la largeur de la carte au lieu d'une colonne étroite.
      // Deux centièmes de tolérance, et pas un : le filet ne reprend la main
      // que sur le mot le plus large, jamais sur la mise en page entière.
      expect(
        m.reduction,
        closeTo(1, 0.02),
        reason:
            'le texte est composé à '
            '${(100 * m.reduction).toStringAsFixed(0)} % de sa taille : '
            'la taille retenue ne tenait pas',
      );

      aucunTexteRogne(tester);
    });
  }

  testWidgets('un mot unique à la borne est réduit, pas rogné', (tester) async {
    // Le cas que le repli ne peut pas servir : soixante caractères sans un
    // seul point de coupure, ce que la saisie d'une carte personnalisée
    // autorise encore. On ne prétend pas le rendre lisible — on vérifie qu'il
    // reste **entier**, ce qui était déjà vrai et doit le rester.
    final texte = 'a' * maxCardTextLength;
    await pumpCarte(tester, game: partieAvec(texte));
    final m = mesurer(tester);

    expect(m.lignes, 1, reason: "un mot unique n'a aucun point de coupure");
    expect(
      m.reduction,
      lessThan(1),
      reason: "il ne tient que réduit, et c'est le seul cas où c'est normal",
    );
    aucunTexteRogne(tester);
  });
}
