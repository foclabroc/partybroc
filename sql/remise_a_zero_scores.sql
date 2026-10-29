-- PartyBroc : remet TOUS les scores à zéro, en gardant les joueurs (pseudo, emoji, couleur).
-- À lancer à la main, quand tu veux repartir de zéro (ce n'est pas une étape d'installation),
-- SERVICE ARRÊTÉ : un salon ouvert garde les scores en mémoire et les réécrirait en base
-- à la fin de la partie suivante. PowerShell en administrateur, dans D:\partybroc :
--
--   nssm stop partybroc
--   psql -h localhost -U partybroc -d party -f sql\remise_a_zero_scores.sql
--   nssm start partybroc
--
-- Remis à zéro : score total et nombre de parties de chaque joueur des salons permanents,
-- statistiques par jeu (victoires, records, parties). Rien d'autre n'est supprimé.

\set ON_ERROR_STOP on
SET client_encoding = 'UTF8';
BEGIN;
SET search_path = pb;

UPDATE pb_room_members SET score = 0, games = 0;

DO $$
BEGIN
  IF to_regclass('pb.pb_room_stats') IS NOT NULL THEN
    DELETE FROM pb.pb_room_stats;
  END IF;
END $$;

COMMIT;

SELECT code AS salon, count(*) AS joueurs_gardes, sum(score) AS total_points FROM pb_room_members GROUP BY code ORDER BY code;
