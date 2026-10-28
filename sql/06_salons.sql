-- PartyBroc : salons permanents (avec mot de passe, toujours accessibles). Relançable.
-- À lancer dans la base party, avec le rôle partybroc :
--
--   psql -h localhost -U partybroc -d party -f 06_salons.sql
--
-- On garde les joueurs (pseudo, emoji, couleur, score total), JAMAIS leur photo :
-- elle reste sur leur téléphone, qui la renvoie en entrant dans le salon.
-- Mots de passe et jetons : seulement leur empreinte (scrypt / sha256), jamais en clair.
--
-- Supprimer un salon permanent (avec ses joueurs) :
--   DELETE FROM pb.pb_rooms WHERE code = 'FAMILLE';

\set ON_ERROR_STOP on
SET client_encoding = 'UTF8';
BEGIN;

SET search_path = pb;

CREATE TABLE IF NOT EXISTS pb_rooms (
  code         text        PRIMARY KEY CHECK (code ~ '^[A-Z]{5,12}$'),  -- ex. FAMILLE
  pass_hash    text        NOT NULL,                                     -- scrypt$sel$empreinte
  created_at   timestamptz NOT NULL DEFAULT now(),
  last_used_at timestamptz NOT NULL DEFAULT now()
);

-- Les joueurs déjà venus dans un salon permanent
CREATE TABLE IF NOT EXISTS pb_room_members (
  code         text        NOT NULL REFERENCES pb_rooms(code) ON DELETE CASCADE,
  member_id    text        NOT NULL,                 -- identifiant stable du joueur dans ce salon
  name         text        NOT NULL CHECK (char_length(name) BETWEEN 1 AND 16),
  emoji        text        NOT NULL DEFAULT '🙂',
  color        smallint    NOT NULL DEFAULT 0,
  score        bigint      NOT NULL DEFAULT 0,       -- score total depuis la création du salon
  games        integer     NOT NULL DEFAULT 0,       -- parties jouées
  token_hash   text,                                 -- sha256 du jeton gardé par son téléphone
  created_at   timestamptz NOT NULL DEFAULT now(),
  last_seen_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (code, member_id)
);
CREATE INDEX IF NOT EXISTS pb_room_members_token_idx ON pb_room_members (token_hash);

-- Écrans (TV, PC…) déjà autorisés à afficher un salon permanent : plus besoin du mot de passe
CREATE TABLE IF NOT EXISTS pb_room_screens (
  code         text        NOT NULL REFERENCES pb_rooms(code) ON DELETE CASCADE,
  key_hash     text        NOT NULL,                 -- sha256 de la clé gardée par l'écran
  created_at   timestamptz NOT NULL DEFAULT now(),
  last_used_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (code, key_hash)
);

COMMIT;

\echo 'Salons permanents prêts.'
