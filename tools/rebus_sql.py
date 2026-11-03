# Fabrique sql/12_rebus.sql à partir de rebus_data.py :  python3 tools/rebus_sql.py
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
from rebus_data import REBUS

def q(s): return "'" + s.replace("'", "''") + "'"

rows = ",\n".join(
    f"  ({q(e)}, {q(a)}, {q(c)}, {q(w1)}, {q(w2)}, {q(w3)}, {q(h)})" for e, a, c, w1, w2, w3, h in REBUS)
sql = f"""-- PartyBroc : « Emoji rébus » ({len(REBUS)} rébus). Relançable.
-- À lancer dans la base party, avec le rôle partybroc :
--
--   psql -h localhost -U partybroc -d party -f 12_rebus.sql
--
-- Fabriqué par tools/rebus_sql.py depuis tools/rebus_data.py (la réponse est unique :
-- relancer met à jour les rébus existants et ajoute les nouveaux).

\\set ON_ERROR_STOP on
SET client_encoding = 'UTF8';
BEGIN;
SET search_path = pb;

CREATE TABLE IF NOT EXISTS pb_rebus (
  id       integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  emojis   text    NOT NULL,
  answer   text    NOT NULL UNIQUE,
  category text    NOT NULL,
  wrong1   text    NOT NULL,
  wrong2   text    NOT NULL,
  wrong3   text    NOT NULL,
  hint     text    NOT NULL DEFAULT '',
  active   boolean NOT NULL DEFAULT true
);

INSERT INTO pb_rebus (emojis, answer, category, wrong1, wrong2, wrong3, hint) VALUES
{rows}
ON CONFLICT (answer) DO UPDATE SET emojis = EXCLUDED.emojis, category = EXCLUDED.category,
  wrong1 = EXCLUDED.wrong1, wrong2 = EXCLUDED.wrong2, wrong3 = EXCLUDED.wrong3, hint = EXCLUDED.hint;

COMMIT;
SELECT count(*) AS rebus FROM pb.pb_rebus;
"""
out = os.path.join(os.path.dirname(__file__), '..', 'sql', '12_rebus.sql')
open(out, 'w', encoding='utf-8').write(sql)
print(len(REBUS), 'rébus →', os.path.normpath(out))
