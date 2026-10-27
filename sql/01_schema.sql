-- PartyBroc : tables de base (soirées et joueurs). Relançable.
-- À lancer dans la base party, avec le rôle partybroc :
--
--   psql -U partybroc -d party -f 01_schema.sql
--
-- Les photos de profil ne sont JAMAIS enregistrées en base :
-- elles restent en mémoire du serveur le temps du salon.
-- Le contenu des jeux (mots, questions…) arrivera dans des fichiers 02_, 03_…

\set ON_ERROR_STOP on
SET client_encoding = 'UTF8';
BEGIN;

CREATE SCHEMA IF NOT EXISTS pb AUTHORIZATION CURRENT_USER;
SET search_path = pb;

-- Une soirée = un salon ouvert sur la TV
CREATE TABLE IF NOT EXISTS pb_parties (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  code        text        NOT NULL,              -- code du salon (4 lettres)
  created_at  timestamptz NOT NULL DEFAULT now(),
  closed_at   timestamptz,
  max_players smallint    NOT NULL DEFAULT 0     -- record de joueurs présents en même temps
);
CREATE INDEX IF NOT EXISTS pb_parties_created_idx ON pb_parties (created_at DESC);

-- Les joueurs passés dans une soirée (pseudo seulement, pas de photo)
CREATE TABLE IF NOT EXISTS pb_party_players (
  party_id   bigint      NOT NULL REFERENCES pb_parties(id) ON DELETE CASCADE,
  player_id  text        NOT NULL,               -- identifiant interne du joueur dans le salon
  name       text        NOT NULL CHECK (char_length(name) BETWEEN 1 AND 16),
  joined_at  timestamptz NOT NULL DEFAULT now(),
  score      integer     NOT NULL DEFAULT 0,     -- score cumulé de la soirée
  PRIMARY KEY (party_id, player_id)
);

-- Chaque partie jouée pendant une soirée (un jeu, un podium)
CREATE TABLE IF NOT EXISTS pb_games (
  id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  party_id   bigint      NOT NULL REFERENCES pb_parties(id) ON DELETE CASCADE,
  game       text        NOT NULL,               -- dessin, quiz, quidenous, reflexes, droles
  started_at timestamptz NOT NULL DEFAULT now(),
  ended_at   timestamptz,
  results    jsonb       NOT NULL DEFAULT '[]'   -- [{player_id, name, score}]
);
CREATE INDEX IF NOT EXISTS pb_games_party_idx ON pb_games (party_id);

COMMIT;

\echo 'Schéma pb prêt.'
