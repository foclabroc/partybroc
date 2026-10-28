-- PartyBroc : statistiques des salons permanents (par joueur et par jeu). Relançable.
-- À lancer dans la base party, avec le rôle partybroc, après 06_salons.sql :
--
--   psql -h localhost -U partybroc -d party -f 10_stats.sql
--
-- game = id du jeu (quiz, dessin…) ou « soiree » pour une soirée enchaînée.
-- wins = parties gagnées (1re place, ex aequo compris) ; best = meilleur score ; total = points cumulés.

\set ON_ERROR_STOP on
SET client_encoding = 'UTF8';
BEGIN;
SET search_path = pb;

CREATE TABLE IF NOT EXISTS pb_room_stats (
  code      text    NOT NULL,
  member_id text    NOT NULL,
  game      text    NOT NULL,
  played    integer NOT NULL DEFAULT 0,
  wins      integer NOT NULL DEFAULT 0,
  best      integer NOT NULL DEFAULT 0,
  total     bigint  NOT NULL DEFAULT 0,
  PRIMARY KEY (code, member_id, game),
  FOREIGN KEY (code, member_id) REFERENCES pb_room_members (code, member_id) ON DELETE CASCADE
);

COMMIT;

\echo 'Statistiques des salons permanents prêtes.'
