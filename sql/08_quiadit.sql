-- PartyBroc : « Qui a dit ça ? » (questions perso, chacun y répond en secret). Relançable.
-- À lancer dans la base party, avec le rôle partybroc :
--
--   psql -h localhost -U partybroc -d party -f 08_quiadit.sql
--
-- Questions gentilles, faites pour jouer en famille (enfants compris).
-- Pour en ajouter : ajoute des lignes dans le VALUES et relance (pas de doublon).

\set ON_ERROR_STOP on
SET client_encoding = 'UTF8';
BEGIN;
SET search_path = pb;

CREATE TABLE IF NOT EXISTS pb_qad_prompts (
  id     integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  prompt text    NOT NULL UNIQUE,
  active boolean NOT NULL DEFAULT true
);

INSERT INTO pb_qad_prompts (prompt) VALUES
  ('Ton plat préféré'),
  ('Le plat que tu détestes le plus'),
  ('Ton rêve d’enfant (le métier que tu voulais faire)'),
  ('Le pays où tu rêves d’aller'),
  ('Ton superpouvoir idéal'),
  ('Ton dessin animé préféré quand tu étais petit'),
  ('Ta pire peur'),
  ('Le prénom que tu aurais aimé avoir'),
  ('Ton animal préféré'),
  ('L’animal que tu serais'),
  ('Ta chanson pour danser'),
  ('Ton film culte'),
  ('Ta matière préférée à l’école'),
  ('La matière que tu détestais à l’école'),
  ('Ton dessert préféré'),
  ('Ce que tu emportes sur une île déserte'),
  ('Ta plus grosse bêtise quand tu étais petit'),
  ('Ton plus beau souvenir de vacances'),
  ('Ton jeu préféré'),
  ('Un objet dont tu ne peux pas te passer'),
  ('Ce que tu fais en premier le matin'),
  ('Ta saison préférée et pourquoi'),
  ('Ton sport préféré (à faire ou à regarder)'),
  ('Le personnage de fiction que tu aimerais être'),
  ('Ta couleur préférée'),
  ('Ton petit plaisir du dimanche'),
  ('Ce que tu ferais si tu gagnais au loto'),
  ('Un talent caché que tu as'),
  ('Le surnom qu’on te donnait petit'),
  ('Ton fruit préféré'),
  ('Ta glace préférée'),
  ('Le métier que tu ne ferais jamais'),
  ('La chose qui t’énerve le plus'),
  ('Ce qui te fait toujours rire'),
  ('Ton émission de télé préférée'),
  ('L’époque où tu aimerais vivre'),
  ('La célébrité que tu aimerais rencontrer'),
  ('Ton plus gros caprice d’enfant'),
  ('Ta tenue préférée'),
  ('Le mot que tu dis tout le temps'),
  ('Ton parfum de bonbon préféré'),
  ('Ce que tu cuisines le mieux'),
  ('Le premier truc que tu achètes avec 100 €'),
  ('La ville où tu aimerais habiter'),
  ('Ton jouet préféré quand tu étais petit'),
  ('Ta boisson préférée'),
  ('Un truc que tu n’as jamais osé faire'),
  ('Le livre ou la BD que tu as le plus aimé'),
  ('Ton héros ou ton héroïne'),
  ('Ce que tu fais quand tu t’ennuies'),
  ('Le cadeau que tu as préféré recevoir'),
  ('Ton activité préférée en famille'),
  ('Ta qualité principale (sois honnête !)'),
  ('Ton petit défaut'),
  ('L’invention qui manque au monde'),
  ('Ce que tu changerais à l’école'),
  ('Ton moment préféré de la journée'),
  ('Le bruit que tu ne supportes pas'),
  ('Ton émoji préféré (et pourquoi)'),
  ('Ce que tu mettrais dans un sandwich géant')
ON CONFLICT (prompt) DO NOTHING;

COMMIT;

\echo 'Qui a dit ça ? : questions prêtes.'
