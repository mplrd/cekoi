"""Les parties pures du test de fumée, contre de vrais dumps d'appareil.

Le script lui-même pilote `adb` et ne peut donc pas tourner en CI. Mais ce
qu'il a de fragile n'est pas le pilotage : ce sont les motifs qui décident si
l'application va bien. Ils se testent très bien sans téléphone, et c'est là
qu'étaient ses deux faux positifs — un test qui annonce OK sur une
application cassée est pire que pas de test du tout.

Les dumps ci-dessous sont tronqués mais authentiques : capturés sur un Xiaomi
23076RN8DY sous Android 15, sauf ceux des cas d'erreur, reconstruits d'après
le format que produit `com.android.server.am`.

Lancer : `python -m unittest discover -s tool -t tool`
"""

import unittest

from fumee import (
    PAQUET,
    appareils_par_etat,
    bloc_de_crash,
    ecran_est_allume,
    est_au_premier_plan,
    lignes_dart,
    nombre_de_frames,
)

# Ce que `dumpsys activity activities` rend sur Android 15, application au
# premier plan. Le champ s'appelle `topResumedActivity` ici ; s'être accroché
# au seul `mResumedActivity` d'une version antérieure a fait échouer ce test
# sur une application parfaitement saine.
ACTIVITES_SAINES = f"""
    topResumedActivity=ActivityRecord{{184973d u0 {PAQUET}/.MainActivity t7105}}
  ResumedActivity: ActivityRecord{{184973d u0 {PAQUET}/.MainActivity t7105}}
"""

FENETRES_SAINES = (
    f"  mCurrentFocus=Window{{47a5f5c u0 {PAQUET}/{PAQUET}.MainActivity}}\n"
    f"  mFocusedApp=ActivityRecord{{184973d u0 {PAQUET}/.MainActivity t7105}}\n"
)


class PremierPlan(unittest.TestCase):
    def test_activite_reprise(self):
        ok, _ = est_au_premier_plan(FENETRES_SAINES, ACTIVITES_SAINES)
        self.assertTrue(ok)

    def test_le_champ_a_change_de_nom_selon_les_versions(self):
        for champ in ("mResumedActivity", "ResumedActivity:", "topResumedActivity"):
            dump = f"  {champ}=ActivityRecord{{1 u0 {PAQUET}/.MainActivity t1}}"
            ok, _ = est_au_premier_plan("", dump)
            self.assertTrue(ok, msg=f"Champ {champ}")

    def test_repli_sur_la_fenetre_au_focus(self):
        ok, _ = est_au_premier_plan(FENETRES_SAINES, "")
        self.assertTrue(ok)

    def test_une_application_qui_ne_repond_pas_ne_passe_pas(self):
        """Le faux positif le plus grave.

        Le titre de la fenêtre système d'ANR contient le nom du paquet. Une
        regex qui ne cherchait que le paquet répondait vrai, si bien qu'une
        application figée au démarrage — processus vivant, « Cékoi ne répond
        pas » à l'écran — cochait les trois contrôles du script.
        """
        fenetres = f"  mCurrentFocus=Window{{a u0 Application Not Responding: {PAQUET}}}"
        ok, pourquoi = est_au_premier_plan(fenetres, "")
        self.assertFalse(ok)
        self.assertIn("Not Responding", pourquoi)

    def test_une_application_qui_s_est_arretee_ne_passe_pas(self):
        fenetres = f"  mCurrentFocus=Window{{a u0 Application Error: {PAQUET}}}"
        ok, pourquoi = est_au_premier_plan(fenetres, "")
        self.assertFalse(ok)
        self.assertIn("Application Error", pourquoi)

    def test_une_autre_activite_du_paquet_ne_suffit_pas(self):
        """Le paquet seul ne prouve rien : c'est `MainActivity` qu'on attend."""
        dump = f"  topResumedActivity=ActivityRecord{{1 u0 {PAQUET}/.AutreEcran t1}}"
        ok, _ = est_au_premier_plan("", dump)
        self.assertFalse(ok)

    def test_une_autre_application_au_premier_plan(self):
        dump = "  topResumedActivity=ActivityRecord{1 u0 com.android.settings/.Main t1}"
        ok, _ = est_au_premier_plan("", dump)
        self.assertFalse(ok)


class Appareils(unittest.TestCase):
    def test_un_appareil_pret(self):
        sortie = "List of devices attached\n7c2c10c678fa\tdevice\n\n"
        self.assertEqual(appareils_par_etat(sortie), {"device": ["7c2c10c678fa"]})

    def test_appareil_non_autorise(self):
        """Le cas le plus fréquent en vrai : la clé RSA n'a pas été acceptée."""
        sortie = "List of devices attached\n7c2c10c678fa\tunauthorized\n"
        self.assertEqual(appareils_par_etat(sortie), {"unauthorized": ["7c2c10c678fa"]})

    def test_aucun_appareil(self):
        self.assertEqual(appareils_par_etat("List of devices attached\n\n"), {})

    def test_plusieurs_appareils(self):
        sortie = "List of devices attached\naaa\tdevice\nbbb\tdevice\nccc\toffline\n"
        branches = appareils_par_etat(sortie)
        self.assertEqual(branches["device"], ["aaa", "bbb"])
        self.assertEqual(branches["offline"], ["ccc"])


class Crash(unittest.TestCase):
    JOURNAL = (
        "--------- beginning of crash\n"
        "E AndroidRuntime: FATAL EXCEPTION: main\n"
        f"E AndroidRuntime: Process: {PAQUET}, PID: 20036\n"
        "E AndroidRuntime: java.lang.RuntimeException: Unable to get provider\n"
    )

    def test_le_crash_du_processus_courant_est_rendu(self):
        trace = bloc_de_crash(self.JOURNAL, "20036")
        self.assertIn("FATAL EXCEPTION", trace)
        self.assertIn("Unable to get provider", trace)

    def test_un_crash_d_un_autre_processus_est_ignore(self):
        """`logcat -c` est refusé par certaines ROM.

        Sans le filtre sur le pid, un crash de la veille encore dans le tampon
        faisait échouer un build parfaitement sain.
        """
        self.assertEqual(bloc_de_crash(self.JOURNAL, "99999"), "")

    def test_journal_vide(self):
        self.assertEqual(bloc_de_crash("", "20036"), "")


class ExceptionsDart(unittest.TestCase):
    def test_une_exception_non_interceptee_est_vue(self):
        """La panne que la survie du processus ne voit pas.

        Une exception Dart ne tue pas le processus et n'écrit rien dans le
        tampon `crash` : elle sort en `E/flutter` sur le tampon principal. Sans
        cette lecture, une application dont `main()` explose avant `runApp`
        passait tous les contrôles.
        """
        journal = (
            "I Ads     : Updating ad debug logging enablement.\n"
            "E flutter : [ERROR:flutter/runtime/dart_vm_initializer.cc(40)]\n"
            "E/flutter ( 1234): Unhandled Exception: Bad state: mutation\n"
        )
        lignes = lignes_dart(journal)
        self.assertEqual(len(lignes), 1)
        self.assertIn("Unhandled Exception", lignes[0])

    def test_un_journal_sain_ne_rend_rien(self):
        journal = (
            "I Ads     : Updating ad debug logging enablement.\n"
            "D ProfileInstaller: Skipping profile installation\n"
        )
        self.assertEqual(lignes_dart(journal), [])


class Rendu(unittest.TestCase):
    def test_compteur_lu(self):
        self.assertEqual(nombre_de_frames("Total frames rendered: 31\n"), 31)

    def test_compteur_a_zero(self):
        self.assertEqual(nombre_de_frames("Total frames rendered: 0\n"), 0)

    def test_section_absente_n_est_pas_zero(self):
        """Zéro veut dire « rien composé » ; l'absence de section ne dit rien.

        Les confondre annonçait « rien n'a été composé » sur un appareil dont
        le format de dump diffère, c'est-à-dire un échec sur une application
        saine.
        """
        self.assertIsNone(nombre_de_frames("** Graphics info **\n"))


class Ecran(unittest.TestCase):
    def test_allume(self):
        self.assertTrue(ecran_est_allume("  mScreenState=ON\n"))

    def test_eteint(self):
        self.assertFalse(ecran_est_allume("  mScreenState=OFF\n"))


if __name__ == "__main__":
    unittest.main()
