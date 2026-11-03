# Fabrique sql/13_quiz_plus.sql à partir de quiz_plus_data.py :  python3 tools/quiz_plus_sql.py
# Refuse les doublons (avec sql/02_quiz.sql et entre elles) et les réponses répétées.
import os, re, sys, unicodedata
here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
from quiz_plus_data import Q

def fold(s):
    s = unicodedata.normalize('NFD', s.lower())
    return re.sub(r'[^a-z0-9]', '', ''.join(c for c in s if unicodedata.category(c) != 'Mn'))

def q(s): return "'" + s.replace("'", "''") + "'"

old = open(os.path.join(here, '..', 'sql', '02_quiz.sql'), encoding='utf-8').read()
seen = {fold(m.replace("''", "'")) for m in re.findall(r"^  \('[^']+', \d, '((?:[^']|'')*)'", old, re.M)}
assert len(seen) == 150, len(seen)

rows, errors = [], []
for cat, items in Q.items():
    for d, question, good, *bad in items:
        k = fold(question)
        if k in seen: errors.append(f'doublon : {question}')
        seen.add(k)
        if d not in (1, 2, 3): errors.append(f'difficulté : {question}')
        if len(bad) != 3 or len({x.strip().lower() for x in [good, *bad]}) != 4: errors.append(f'réponses : {question}')
        if not question.endswith('?'): errors.append(f'pas de « ? » : {question}')
        if max(len(x) for x in [good, *bad]) > 48: errors.append(f'réponse trop longue : {question}')
        rows.append(f"  ({q(cat)}, {d}, {q(question)}, {q(good)}, ARRAY[{', '.join(q(b) for b in bad)}])")
if errors:
    sys.exit('\n'.join(errors))

body = ',\n'.join(rows)
sql = f"""-- PartyBroc : Quiz culture G, {len(rows)} questions de plus (0.16). Relançable.
-- À lancer APRÈS 02_quiz.sql, dans la base party, avec le rôle partybroc :
--
--   psql -h localhost -U partybroc -d party -f 13_quiz_plus.sql
--
-- Fabriqué par tools/quiz_plus_sql.py depuis tools/quiz_plus_data.py.
-- Une question déjà présente (même texte) est mise à jour, pas dupliquée.

\\set ON_ERROR_STOP on
SET client_encoding = 'UTF8';
BEGIN;
SET search_path = pb;

INSERT INTO pb_quiz_questions (category, difficulty, question, good, bad) VALUES
{body}
ON CONFLICT (question) DO UPDATE
  SET category = excluded.category, difficulty = excluded.difficulty,
      good = excluded.good, bad = excluded.bad;

COMMIT;

SELECT category, count(*) AS questions FROM pb_quiz_questions WHERE active GROUP BY category ORDER BY category;
"""
open(os.path.join(here, '..', 'sql', '13_quiz_plus.sql'), 'w', encoding='utf-8').write(sql)
print(f'{len(rows)} questions écrites dans sql/13_quiz_plus.sql')
