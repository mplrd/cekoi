"""Fabrique les sons du jeu, en WAV, sans dépendance.

    python tool/make_sounds.py

Deux sons, et deux seulement :

* `tick.wav` — chacune des dix dernières secondes. Discret : il informe, il
  n'alarme pas. On l'entend dix fois de suite, un son marqué y deviendrait
  insupportable.
* `buzzer.wav` — la fin du tour. Franc, et surtout **d'un autre timbre** que le
  tic : deux sons de la même famille, l'un un peu plus fort que l'autre, ne se
  distinguent pas au milieu d'une table qui crie.

Pourquoi un fichier plutôt que `SystemSound.play` : sur Android, les sons
système passent par la couche de retour tactile, que l'interrupteur « sons des
touches » éteint — il l'est chez beaucoup de monde. Et `SystemSoundType.alert`
est documenté par Flutter comme ignoré sur Android **et** iOS. Un asset joué
sur le canal média suit le volume média, se coupe en mode silencieux, et existe
sur les deux plateformes.
"""

from __future__ import annotations

import math
import struct
import wave
from pathlib import Path

TAUX = 44_100
SORTIE = Path(__file__).resolve().parent.parent / "assets" / "audio"


def ecrire(nom: str, echantillons: list[float]) -> None:
    """Écrit un WAV mono 16 bits, avec une garde contre l'écrêtage."""
    crete = max(abs(e) for e in echantillons) or 1.0
    # 0,89 plutôt que 1,0 : un signal collé au maximum sature à la
    # reconversion des lecteurs, et le son devient sale sur petit haut-parleur.
    gain = 0.89 / crete

    SORTIE.mkdir(parents=True, exist_ok=True)
    chemin = SORTIE / nom
    with wave.open(str(chemin), "wb") as fichier:
        fichier.setnchannels(1)
        fichier.setsampwidth(2)
        fichier.setframerate(TAUX)
        fichier.writeframes(
            b"".join(
                struct.pack("<h", int(max(-1.0, min(1.0, e * gain)) * 32_767))
                for e in echantillons
            )
        )
    print(f"{chemin.relative_to(SORTIE.parent.parent)}  ({chemin.stat().st_size} octets)")


def enveloppe(i: int, total: int, attaque: float, chute: float) -> float:
    """Attaque courte puis décroissance exponentielle, en secondes."""
    t = i / TAUX
    reste = (total - i) / TAUX
    montee = min(1.0, t / attaque) if attaque > 0 else 1.0
    descente = math.exp(-t / chute)
    # Les cinq dernières millisecondes descendent à zéro : couper un signal en
    # pleine oscillation produit un claquement à la fin de chaque lecture.
    fermeture = min(1.0, reste / 0.005)
    return montee * descente * fermeture


def tick() -> list[float]:
    """Un blip court et clair. 40 ms, une sinusoïde et son octave."""
    duree = int(0.04 * TAUX)
    return [
        (
            math.sin(2 * math.pi * 1_200 * i / TAUX)
            + 0.3 * math.sin(2 * math.pi * 2_400 * i / TAUX)
        )
        * enveloppe(i, duree, attaque=0.001, chute=0.012)
        for i in range(duree)
    ]


def buzzer() -> list[float]:
    """Deux coups graves et carrés, à la manière d'un buzzer de plateau.

    Le carré plutôt que la sinusoïde : ses harmoniques impaires portent sur un
    haut-parleur de téléphone, là où une basse pure disparaît. Et deux coups
    plutôt qu'un long : au milieu du bruit, c'est le rythme qu'on reconnaît
    avant le timbre.
    """
    coup = int(0.16 * TAUX)
    silence = [0.0] * int(0.05 * TAUX)

    def frappe(frequence: float) -> list[float]:
        sortie = []
        for i in range(coup):
            phase = 2 * math.pi * frequence * i / TAUX
            # Carré adouci : la tangente hyperbolique arrondit les angles, ce
            # qui évite le grésillement d'un carré parfait.
            onde = math.tanh(3.0 * math.sin(phase))
            sortie.append(onde * enveloppe(i, coup, attaque=0.002, chute=0.09))
        return sortie

    return frappe(233.0) + silence + frappe(175.0)


if __name__ == "__main__":
    ecrire("tick.wav", tick())
    ecrire("buzzer.wav", buzzer())
