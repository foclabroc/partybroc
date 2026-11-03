# Fabrique sql/14_expressions.sql à partir de expressions_data.py :  python3 tools/expressions_sql.py
# Vérifie : un seul « ___ », 4 mots différents, pas deux fois la même expression.
import os, sys
here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
from expressions_data import E

def q(s): return "'" + s.replace("'", "''") + "'"

rows, seen, errors = [], set(), []
for d, text, good, w1, w2, w3, meaning in E:
    full = text.replace('___', good)
    if text.count('___') != 1: errors.append(f'« ___ » : {text}')
    if full.lower() in seen or text.lower() in seen: errors.append(f'doublon : {text}')
    seen.add(full.lower()); seen.add(text.lower())
    if len({x.strip().lower() for x in (good, w1, w2, w3)}) != 4: errors.append(f'mots : {text}')
    if d not in (1, 2, 3) or not meaning: errors.append(f'difficulté / sens : {text}')
    rows.append(f"  ({q(text)}, {q(good)}, {q(w1)}, {q(w2)}, {q(w3)}, {q(meaning)}, {d})")
if errors:
    sys.exit('\n'.join(errors))

body = ',\n'.join(rows)
sql = f"""-- PartyBroc : « Expressions à trous » ({len(rows)} expressions françaises). Relançable.
-- À lancer dans la base party, avec le rôle partybroc :
--
--   psql -h localhost -U partybroc -d party -f 14_expressions.sql
--
-- Fabriqué par tools/expressions_sql.py depuis tools/expressions_data.py.
-- « ___ » marque le mot caché. Relancer met à jour les expressions existantes et ajoute les nouvelles.

\\set ON_ERROR_STOP on
SET client_encoding = 'UTF8';
BEGIN;
SET search_path = pb;

CREATE TABLE IF NOT EXISTS pb_expressions (
  id         integer  GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  text       text     NOT NULL UNIQUE,   -- l'expression avec ___ à la place du mot caché
  answer     text     NOT NULL,
  wrong1     text     NOT NULL,
  wrong2     text     NOT NULL,
  wrong3     text     NOT NULL,
  meaning    text     NOT NULL,          -- ce que veut dire l'expression
  difficulty smallint NOT NULL DEFAULT 1 CHECK (difficulty BETWEEN 1 AND 3),
  active     boolean  NOT NULL DEFAULT true
);

INSERT INTO pb_expressions (text, answer, wrong1, wrong2, wrong3, meaning, difficulty) VALUES
{body}
ON CONFLICT (text) DO UPDATE SET answer = EXCLUDED.answer, wrong1 = EXCLUDED.wrong1, wrong2 = EXCLUDED.wrong2,
  wrong3 = EXCLUDED.wrong3, meaning = EXCLUDED.meaning, difficulty = EXCLUDED.difficulty;

COMMIT;

SELECT count(*) AS expressions FROM pb_expressions WHERE active;
"""
open(os.path.join(here, '..', 'sql', '14_expressions.sql'), 'w', encoding='utf-8').write(sql)
print(f'{len(rows)} expressions écrites dans sql/14_expressions.sql')
