-- PartyBroc : scores du jour des salons permanents (classement du jour). Relançable.
-- À lancer dans la base party, avec le rôle partybroc, après 10_stats.sql :
--
--   psql -h localhost -U partybroc -d party -f 15_jours.sql
--
-- day = jour de jeu (heure de Paris, la journée commence à 6 h : une soirée qui passe minuit compte pour la veille).
-- score = points du jour ; games = parties jouées ; wins = parties gagnées ce jour-là.

\set ON_ERROR_STOP on
SET client_encoding = 'UTF8';
BEGIN;
SET search_path = pb;

CREATE TABLE IF NOT EXISTS pb_room_days (
  code      text    NOT NULL,
  member_id text    NOT NULL,
  day       date    NOT NULL,
  score     bigint  NOT NULL DEFAULT 0,
  games     integer NOT NULL DEFAULT 0,
  wins      integer NOT NULL DEFAULT 0,
  PRIMARY KEY (code, member_id, day),
  FOREIGN KEY (code, member_id) REFERENCES pb_room_members (code, member_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS pb_room_days_day ON pb_room_days (code, day);

COMMIT;

\echo 'Scores du jour des salons permanents prêts.'
