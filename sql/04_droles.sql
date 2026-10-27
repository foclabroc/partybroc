-- PartyBroc : « Réponses drôles » (phrases à compléter). Relançable.
-- À lancer dans la base party, avec le rôle partybroc :
--
--   psql -h localhost -U partybroc -d party -f sql\04_droles.sql
--
-- Pour en ajouter : ajoute des lignes dans le VALUES et relance (pas de doublon).
-- Pour en retirer une sans la supprimer : update pb_drl_prompts set active = false where ...

\set ON_ERROR_STOP on
SET client_encoding = 'UTF8';
BEGIN;
SET search_path = pb;

CREATE TABLE IF NOT EXISTS pb_drl_prompts (
  id     integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  prompt text    NOT NULL UNIQUE,   -- ___ marque le trou à compléter
  active boolean NOT NULL DEFAULT true
);

INSERT INTO pb_drl_prompts (prompt) VALUES
  ('Le pire cadeau d''anniversaire : ___'),
  ('La première chose que je fais en me réveillant : ___'),
  ('Le nom parfait pour un hamster : ___'),
  ('Une excuse pour arriver en retard au travail : ___'),
  ('Ce que les chats pensent vraiment des humains : ___'),
  ('La pire idée de parfum de glace : ___'),
  ('Le titre du prochain tube de l''été : ___'),
  ('Ce qu''il ne faut jamais dire à un premier rendez-vous : ___'),
  ('Le slogan d''une salle de sport pour paresseux : ___'),
  ('Une nouvelle épreuve aux Jeux olympiques : ___'),
  ('Le pire métier du monde : ___'),
  ('Ce que le Père Noël fait le reste de l''année : ___'),
  ('Un super-pouvoir complètement inutile : ___'),
  ('La phrase préférée des parents : ___'),
  ('Le pire nom pour un restaurant : ___'),
  ('Ce qu''on trouve vraiment au fond du sac de mamie : ___'),
  ('Une invention qui changerait ma vie : ___'),
  ('Le pire message à recevoir à 3 h du matin : ___'),
  ('Ce que dit le GPS quand il en a marre : ___'),
  ('La règle secrète de cette soirée : ___'),
  ('Ce que mon chien raconte à ses copains : ___'),
  ('Une matière à ajouter à l''école : ___'),
  ('Le pire conseil de vie : ___'),
  ('Ce qu''il y a vraiment dans les nuggets : ___'),
  ('Le prochain emoji à inventer : ___'),
  ('Une bonne raison de ne pas faire la vaisselle : ___'),
  ('Ce que pensent les poissons rouges : ___'),
  ('La pire chanson pour un mariage : ___'),
  ('Le titre de mon autobiographie : ___'),
  ('Une appli que personne ne téléchargerait : ___'),
  ('Ce que les extraterrestres pensent de nous : ___'),
  ('Le pire endroit pour éternuer : ___'),
  ('Le prochain plat à la mode : ___'),
  ('Ce que je ferais avec un million d''euros : ___'),
  ('Une tradition familiale bizarre : ___'),
  ('La pire idée de déguisement : ___'),
  ('Ce que le chef cuisinier crie en cuisine : ___'),
  ('Le mot de passe du wifi de Dieu : ___'),
  ('Le pire moment pour se mettre à chanter : ___'),
  ('Ce qu''on ne devrait jamais mettre sur une pizza : ___'),
  ('Une phrase pour rompre avec élégance : ___'),
  ('Ce que dit le dentiste juste avant de commencer : ___'),
  ('La pire excuse pour ne pas aller à une soirée : ___'),
  ('Un nouveau sport extrême : ___'),
  ('Ce que les plantes disent quand on part en vacances : ___'),
  ('Le pire nom pour un bateau : ___'),
  ('Ce que contient le coffre-fort de la Banque de France : ___'),
  ('Le cri de guerre de cette soirée : ___'),
  ('Ce que le prof dit en salle des profs : ___'),
  ('La meilleure façon de réveiller quelqu''un : ___'),
  ('Le pire prénom pour un bébé : ___'),
  ('Une loi que je voterais demain : ___'),
  ('Ce qui se passe vraiment la nuit au musée : ___'),
  ('Le pire jeu de société : ___'),
  ('Ce que je mettrais dans une capsule temporelle : ___'),
  ('La raison secrète des bouchons sur l''autoroute : ___'),
  ('Le prochain film de super-héros : ___'),
  ('Ce que dit la tour Eiffel la nuit : ___'),
  ('Un truc à ne jamais faire en réunion : ___'),
  ('La meilleure réponse à « tu fais quoi dans la vie ? » : ___'),
  ('Ce que pense le micro-ondes : ___'),
  ('Le pire souvenir à rapporter de vacances : ___'),
  ('La suite de « Il était une fois… » : ___'),
  ('Un défi pour la prochaine soirée : ___'),
  ('Ce qui rendrait les lundis supportables : ___'),
  ('Le dessert parfait : ___'),
  ('Une phrase à dire en entrant dans une pièce : ___'),
  ('Le pire talent caché : ___'),
  ('Ce qu''il faut emporter sur une île déserte : ___'),
  ('Le surnom de l''hôte de ce soir : ___')
ON CONFLICT (prompt) DO NOTHING;

COMMIT;

SELECT count(*) AS phrases_reponses_droles FROM pb_drl_prompts WHERE active;
