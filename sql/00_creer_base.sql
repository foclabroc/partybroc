-- PartyBroc : création de la base « party » et de son rôle.
-- Relançable. À lancer en superutilisateur (postgres), depuis la base postgres :
--
--   psql -U postgres -d postgres -v pw="UN_MOT_DE_PASSE" -f 00_creer_base.sql
--
-- Le mot de passe est celui que le serveur PartyBroc utilisera (variable PB_DB_URL).
-- Pixel Trade n'est pas touché : base, rôle et tables sont séparés.

\set ON_ERROR_STOP on

\if :{?pw}
\else
  \echo 'Il manque le mot de passe : ajoute -v pw="..." à la commande.'
  \quit
\endif

-- Rôle de l'application (pas superutilisateur, pas de création de base ni de rôle)
SELECT format('CREATE ROLE partybroc LOGIN PASSWORD %L NOSUPERUSER NOCREATEDB NOCREATEROLE', :'pw')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'partybroc')
\gexec

-- Si le rôle existait déjà, on remet le mot de passe donné
SELECT format('ALTER ROLE partybroc PASSWORD %L', :'pw')
\gexec

-- Base dédiée, appartenant au rôle
SELECT 'CREATE DATABASE party OWNER partybroc ENCODING ''UTF8'' TEMPLATE template0'
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'party')
\gexec

-- Personne d'autre ne s'y connecte
REVOKE ALL ON DATABASE party FROM PUBLIC;
GRANT CONNECT, TEMPORARY ON DATABASE party TO partybroc;
ALTER ROLE partybroc IN DATABASE party SET search_path = pb, public;

\echo 'Base party prête. Lance maintenant 01_schema.sql dans la base party.'
