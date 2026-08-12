import 'package:cekoi/services/ads/ad_frequency.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le plafond de fréquence de `MONETISATION.md`.
///
/// Logique pure : aucune pub, aucun SDK, aucune base. C'est la seule partie de
/// l'interstitiel qui décide quelque chose, et elle se vérifie en
/// millisecondes.
void main() {
  const policy = AdFrequencyPolicy();
  final now = DateTime.utc(2026, 8, 12, 20);

  DateTime ago(Duration d) => now.subtract(d);

  test('sans historique, la pub passe', () {
    expect(policy.allows(recent: const [], now: now), isTrue);
  });

  group('délai minimum de 5 minutes', () {
    test('une pub il y a 4 minutes bloque', () {
      expect(
        policy.allows(recent: [ago(const Duration(minutes: 4))], now: now),
        isFalse,
      );
    });

    test('une pub il y a 6 minutes laisse passer', () {
      expect(
        policy.allows(recent: [ago(const Duration(minutes: 6))], now: now),
        isTrue,
      );
    });

    test('la borne des 5 minutes exactes laisse passer', () {
      // Choix explicite plutôt qu'un hasard d'inégalité : « un délai minimum
      // de 5 minutes entre deux » est respecté à 5 minutes pile.
      expect(
        policy.allows(recent: [ago(const Duration(minutes: 5))], now: now),
        isTrue,
      );
    });
  });

  group('plafond de 3 par heure', () {
    test('trois pubs dans l heure bloquent la quatrième', () {
      expect(
        policy.allows(
          recent: [
            ago(const Duration(minutes: 10)),
            ago(const Duration(minutes: 30)),
            ago(const Duration(minutes: 50)),
          ],
          now: now,
        ),
        isFalse,
      );
    });

    test('une pub sortie de la fenêtre ne compte plus', () {
      // La plus ancienne a plus d'une heure : il ne reste que deux
      // impressions dans la fenêtre glissante.
      expect(
        policy.allows(
          recent: [
            ago(const Duration(minutes: 10)),
            ago(const Duration(minutes: 30)),
            ago(const Duration(minutes: 61)),
          ],
          now: now,
        ),
        isTrue,
      );
    });

    test('la fenêtre glisse, elle ne se remet pas à zéro à heure ronde', () {
      // Trois pubs très rapprochées il y a 40 minutes : l'heure calendaire a
      // pu changer entre-temps, la fenêtre non.
      final serrees = [
        ago(const Duration(minutes: 40)),
        ago(const Duration(minutes: 41)),
        ago(const Duration(minutes: 42)),
      ];

      expect(policy.allows(recent: serrees, now: now), isFalse);
    });
  });

  group('cas tordus', () {
    test('un historique dans le futur ne débloque rien', () {
      // Le joueur peut reculer l'horloge de son téléphone. Une impression
      // datée du futur ne doit pas devenir un laissez-passer : elle est dans
      // la fenêtre, et elle est plus proche que le délai minimum.
      expect(
        policy.allows(recent: [now.add(const Duration(hours: 2))], now: now),
        isFalse,
      );
    });

    test('un historique désordonné donne le même verdict', () {
      final desordre = [
        ago(const Duration(minutes: 50)),
        ago(const Duration(minutes: 10)),
        ago(const Duration(minutes: 30)),
      ];

      expect(policy.allows(recent: desordre, now: now), isFalse);
    });

    test('le fuseau n influe pas sur le verdict', () {
      // Les dates viennent de la base, où elles peuvent être relues en local.
      expect(
        policy.allows(
          recent: [ago(const Duration(minutes: 4)).toLocal()],
          now: now,
        ),
        isFalse,
      );
    });
  });

  group('nettoyage de l historique', () {
    test('ce qui sort de la fenêtre est jetable', () {
      // La base ne doit pas accumuler une ligne par pub depuis l'installation
      // pour répondre à une question qui ne regarde que la dernière heure.
      expect(
        policy.expiredBefore(now),
        now.subtract(const Duration(hours: 1)),
      );
    });
  });
}
