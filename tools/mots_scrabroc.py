"""Scrabroc : fabrique server/data/mots.txt.gz (dictionnaire des mots acceptés).

Source : le paquet npm « an-array-of-french-words » (licence MIT, ~336 000 mots,
dérivé de la liste de Letterpress). Les mots sont mis en majuscules sans accents
(Œ → OE, Æ → AE) ; on garde ceux de 2 à 15 lettres A-Z. On ajoute les petits mots
de 2 lettres admis au jeu de lettres qui manquent à la liste (QI, KA…).

    npm pack an-array-of-french-words && tar xzf an-array-of-french-words-*.tgz
    python3 tools/mots_scrabroc.py package/index.json
"""
import gzip
import json
import re
import sys
import unicodedata
from pathlib import Path

# Mots de 2 lettres admis en jeu de lettres en français
DEUX = """AA AH AI AN AS AU AY BA BE BI BU CA CE CI DA DE DO DU EH EN ES ET EU EX FA FI GO HA HE HI HO
IF IL IN JA JE KA LA LE LI LU MA ME MI MU NA NE NI NO NU OC OH OM ON OR OS OU PI PU QI RA RE RI RU
SA SE SI SU TA TE TU UN US UT VA VE VU WU XI""".split()


def norm(s):
    s = unicodedata.normalize('NFD', s)
    s = ''.join(c for c in s if unicodedata.category(c) != 'Mn')
    return s.upper().replace('Œ', 'OE').replace('Æ', 'AE')


def main(src):
    words = {n for n in map(norm, json.load(open(src, encoding='utf-8'))) if re.fullmatch('[A-Z]{2,15}', n)}
    words |= set(DEUX)
    out = Path(__file__).resolve().parent.parent / 'server' / 'data' / 'mots.txt.gz'
    with gzip.open(out, 'wt', encoding='ascii') as f:
        f.write('\n'.join(sorted(words)))
    print(f'{len(words)} mots → {out} ({out.stat().st_size // 1024} Ko)')


if __name__ == '__main__':
    main(sys.argv[1] if len(sys.argv) > 1 else 'package/index.json')
