-- PartyBroc : « Qui de nous ? » (questions). Relançable.
-- À lancer dans la base party, avec le rôle partybroc :
--
--   psql -h localhost -U partybroc -d party -f sql\03_quidenous.sql
--
-- Pour en ajouter : ajoute des lignes dans le VALUES et relance (pas de doublon).
-- Pour en retirer une sans la supprimer : update pb_qdn_prompts set active = false where ...

\set ON_ERROR_STOP on
SET client_encoding = 'UTF8';
BEGIN;
SET search_path = pb;

CREATE TABLE IF NOT EXISTS pb_qdn_prompts (
  id     integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  prompt text    NOT NULL UNIQUE,   -- suite de « Qui est le plus susceptible de… »
  active boolean NOT NULL DEFAULT true
);

INSERT INTO pb_qdn_prompts (prompt) VALUES
  ('oublier l''anniversaire de son meilleur ami'),
  ('se perdre avec un GPS'),
  ('pleurer devant un dessin animé'),
  ('manger le dernier morceau sans demander'),
  ('devenir célèbre sur Internet'),
  ('survivre seul sur une île déserte'),
  ('se faire arrêter par erreur'),
  ('rire à un enterrement'),
  ('devenir millionnaire'),
  ('adopter dix chats'),
  ('gagner à un jeu télé'),
  ('dormir pendant un film au cinéma'),
  ('s''endormir en premier à une soirée'),
  ('parler à ses plantes'),
  ('chanter sous la douche à tue-tête'),
  ('se tromper de prénom à un mariage'),
  ('partir en vacances sans valise'),
  ('finir la soirée en dansant sur la table'),
  ('envoyer un message au mauvais destinataire'),
  ('rater son train de justesse'),
  ('commander trois desserts'),
  ('devenir président de la République'),
  ('se perdre dans un supermarché'),
  ('avoir un tatouage secret'),
  ('appeler sa mère tous les jours'),
  ('répondre « c''est pas moi » alors que si'),
  ('acheter un objet inutile en promo'),
  ('tomber amoureux en vacances'),
  ('casser son téléphone dans la semaine'),
  ('oublier ses clés à l''intérieur'),
  ('faire un discours émouvant'),
  ('raconter une blague que personne ne comprend'),
  ('se lever avant tout le monde'),
  ('regarder une série entière en un week-end'),
  ('arriver en retard à son propre mariage'),
  ('faire semblant d''avoir lu le livre'),
  ('manger une pizza à l''ananas fièrement'),
  ('gagner une compétition de karaoké'),
  ('tricher au Monopoly'),
  ('se faire piquer par une guêpe en premier'),
  ('parler à un inconnu pendant une heure'),
  ('partir faire le tour du monde demain'),
  ('écrire un livre'),
  ('ouvrir un restaurant'),
  ('avoir peur dans un train fantôme'),
  ('crier pendant un film d''horreur'),
  ('ramener un animal trouvé dans la rue'),
  ('se déguiser sans raison'),
  ('porter des chaussettes dépareillées'),
  ('connaître toutes les paroles d''un vieux tube'),
  ('retrouver ses copains d''école sur Internet'),
  ('devenir youtubeur'),
  ('garder un secret toute sa vie'),
  ('dévoiler un secret en moins d''une heure'),
  ('finir le dernier verre'),
  ('gagner au loto et ne rien dire'),
  ('se battre avec un distributeur de boissons'),
  ('négocier le prix d''une baguette'),
  ('prendre trois cents photos en vacances'),
  ('oublier où il a garé sa voiture'),
  ('mettre trop de sel dans le gâteau'),
  ('appeler le service client pour râler'),
  ('tomber en glissant sur la neige'),
  ('devenir le chouchou du prof'),
  ('parler tout seul en conduisant'),
  ('finir un marathon'),
  ('manger un insecte pour un pari'),
  ('avoir une collection bizarre'),
  ('savoir réparer n''importe quoi'),
  ('lancer une mode'),
  ('se réveiller sans avoir entendu le réveil'),
  ('faire une sieste au travail'),
  ('trouver un trésor'),
  ('se faire passer pour un touriste'),
  ('avoir déjà oublié ce qu''on vient de dire'),
  ('gagner une bataille de boules de neige'),
  ('se faire draguer au supermarché'),
  ('rire tellement fort que tout le monde se retourne'),
  ('ranger ses chaussettes par couleur'),
  ('arriver en avance de deux heures à l''aéroport')
ON CONFLICT (prompt) DO NOTHING;

COMMIT;

SELECT count(*) AS questions_qui_de_nous FROM pb_qdn_prompts WHERE active;
