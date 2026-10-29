-- PartyBroc : « Qui a dit ça ? », 50 questions de plus. Relançable.
-- À lancer dans la base party, avec le rôle partybroc (après 08_quiadit.sql) :
--
--   psql -h localhost -U partybroc -d party -f 11_quiadit_plus.sql
--
-- Questions gentilles, tout public.

\set ON_ERROR_STOP on
SET client_encoding = 'UTF8';
BEGIN;
SET search_path = pb;

INSERT INTO pb_qad_prompts (prompt) VALUES
  ('Ton petit-déjeuner idéal'),
  ('Le dernier truc qui t’a fait pleurer de rire'),
  ('Ta manie bizarre'),
  ('L’appli que tu ouvres le plus sur ton téléphone'),
  ('Ta chanson qui te reste dans la tête'),
  ('Le cadeau dont tu es le plus fier'),
  ('Ce que tu collectionnes (ou collectionnais)'),
  ('Ton endroit préféré dans la maison'),
  ('Le légume que tu ne peux pas avaler'),
  ('Ton héros quand tu étais petit'),
  ('Le jeu de société où tu es imbattable'),
  ('Ta plus grosse gaffe'),
  ('Ta plus longue sieste'),
  ('Le prénom que tu donnerais à un dragon'),
  ('Ce que tu ferais si tu étais invisible une journée'),
  ('Le métier que tu ferais dans une autre vie'),
  ('Ton record personnel (n’importe lequel)'),
  ('La chose que tu fais mieux que tout le monde ici'),
  ('Ta phrase quand tu es en retard'),
  ('Ce que tu commandes toujours au restaurant'),
  ('Ta garniture de pizza préférée'),
  ('Le pire cadeau que tu as reçu'),
  ('Ton souvenir de Noël préféré'),
  ('Ton goûter préféré quand tu étais petit'),
  ('La chose que tu perds tout le temps'),
  ('Le dernier compliment qu’on t’a fait'),
  ('Le son qui te rend heureux'),
  ('Ton moyen de transport préféré'),
  ('La planète où tu partirais en vacances'),
  ('Le dernier rêve bizarre dont tu te souviens'),
  ('La tâche ménagère que tu fuis'),
  ('L’objet le plus inutile que tu as acheté'),
  ('Ton jeu vidéo préféré'),
  ('L’animal que tu aimerais avoir comme compagnon'),
  ('Le dernier fou rire que tu as eu'),
  ('Ta façon de te détendre'),
  ('Le pays dont tu aimes le plus la cuisine'),
  ('Le plat de ton enfance'),
  ('L’odeur que tu adores'),
  ('Le surnom que tu donnerais à la personne à ta gauche'),
  ('La première chose que tu ferais en étant roi ou reine'),
  ('Ton mot préféré de la langue française'),
  ('Ce que tu fais toujours en vacances'),
  ('Le sport que tu aimerais essayer'),
  ('Ta sauce préférée'),
  ('Le moment préféré de ta journée'),
  ('Une chose que tu as apprise récemment'),
  ('Ce qui te rend de bonne humeur'),
  ('Ta devise dans la vie'),
  ('Le super-héros que tu inviterais à dîner')
ON CONFLICT (prompt) DO NOTHING;

COMMIT;

SELECT count(*) AS questions_qui_a_dit_ca FROM pb_qad_prompts WHERE active;
