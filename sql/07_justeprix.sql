-- PartyBroc : « Le juste prix » (objets et prix moyens indicatifs en France). Relançable.
-- À lancer dans la base party, avec le rôle partybroc :
--
--   psql -h localhost -U partybroc -d party -f 07_justeprix.sql
--
-- Les prix sont des ordres de grandeur (2025-2026), pas des relevés officiels :
-- corrige-les à ta guise (update pb_jp_items set price = … where name = …).
-- Pour en ajouter : ajoute des lignes dans le VALUES et relance (pas de doublon, le nom est unique).

\set ON_ERROR_STOP on
SET client_encoding = 'UTF8';
BEGIN;
SET search_path = pb;

CREATE TABLE IF NOT EXISTS pb_jp_items (
  id     integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  emoji  text          NOT NULL,
  name   text          NOT NULL UNIQUE,
  detail text          NOT NULL DEFAULT '',
  price  numeric(10,2) NOT NULL CHECK (price > 0),
  active boolean       NOT NULL DEFAULT true
);

INSERT INTO pb_jp_items (emoji, name, detail, price) VALUES
  ('🥖', 'Une baguette de pain', 'à la boulangerie', 1.20),
  ('🥐', 'Un croissant au beurre', 'à la boulangerie', 1.30),
  ('🥪', 'Un sandwich jambon-beurre', 'à la boulangerie', 4.50),
  ('🍰', 'Une part de tarte aux fraises', 'à la pâtisserie', 4.00),
  ('🥚', 'Une boîte de 6 œufs', 'de poules élevées en plein air, au supermarché', 2.30),
  ('🥛', 'Une bouteille de lait demi-écrémé', '1 litre, au supermarché', 1.10),
  ('🧈', 'Une plaquette de beurre', '250 g, au supermarché', 2.60),
  ('🍫', 'Une tablette de chocolat noir', '100 g, une grande marque', 2.20),
  ('🍝', 'Un paquet de spaghettis', '500 g, une grande marque', 1.40),
  ('☕', 'Un expresso', 'au comptoir d’un café', 1.90),
  ('🛒', 'Un paquet de café moulu', '250 g, une grande marque', 4.00),
  ('🍌', 'Un kilo de bananes', 'au supermarché', 2.00),
  ('🍎', 'Un kilo de pommes', 'au supermarché', 2.50),
  ('🧀', 'Un camembert', '250 g, au lait cru, au supermarché', 3.50),
  ('🍕', 'Une pizza surgelée', 'une grande marque', 4.00),
  ('🍔', 'Un menu burger + frites + boisson', 'dans un fast-food', 11.00),
  ('🥤', 'Une canette de soda', '33 cl, au supermarché', 0.90),
  ('💧', 'Un pack de 6 bouteilles d’eau', '6 × 1,5 litre, au supermarché', 3.00),
  ('🍷', 'Une bouteille de vin rouge de table', '75 cl, au supermarché', 5.00),
  ('🍾', 'Une bouteille de champagne', 'premier prix, au supermarché', 25.00),
  ('🍬', 'Un sachet de bonbons', '250 g, une grande marque', 2.50),
  ('🍦', 'Deux boules de glace en cornet', 'chez un glacier', 5.00),
  ('🍯', 'Un pot de miel', '500 g, au supermarché', 6.00),
  ('🥫', 'Une boîte de petits pois', '400 g, au supermarché', 1.20),
  ('🍣', 'Une barquette de 12 sushis', 'au rayon traiteur', 9.00),
  ('🖊️', 'Un stylo bille bleu', 'à l’unité', 0.60),
  ('📓', 'Un grand cahier', '96 pages, grands carreaux', 2.00),
  ('📄', 'Une ramette de papier', '500 feuilles A4', 5.00),
  ('🧻', 'Un paquet de 12 rouleaux de papier toilette', 'au supermarché', 6.00),
  ('🪥', 'Une brosse à dents', 'manuelle, une grande marque', 2.50),
  ('🧴', 'Un tube de dentifrice', '75 ml, une grande marque', 2.50),
  ('💡', 'Une ampoule LED', 'culot classique, au magasin de bricolage', 3.00),
  ('🔋', 'Un lot de 4 piles AA', 'une grande marque', 6.00),
  ('☂️', 'Un parapluie pliant', 'tout simple', 10.00),
  ('🧦', 'Une paire de chaussettes', 'en grande surface', 4.00),
  ('👕', 'Un t-shirt blanc', 'basique, dans une grande enseigne', 8.00),
  ('👖', 'Un jean', 'dans une grande enseigne de vêtements', 40.00),
  ('👟', 'Une paire de baskets de marque', 'modèle classique', 100.00),
  ('⚽', 'Un ballon de foot', 'premier prix, au magasin de sport', 8.00),
  ('🎲', 'Un jeu de 54 cartes', 'classique', 3.00),
  ('🧸', 'Un ours en peluche', '30 cm, au magasin de jouets', 20.00),
  ('🚲', 'Un vélo de ville neuf', 'premier prix, au magasin de sport', 250.00),
  ('🛴', 'Une trottinette électrique', 'premier prix', 300.00),
  ('📱', 'Un smartphone haut de gamme', 'neuf, dernier modèle', 1100.00),
  ('🎮', 'Une console de jeux de salon', 'neuve, modèle standard', 500.00),
  ('📺', 'Une télévision 55 pouces 4K', 'premier prix', 400.00),
  ('🎧', 'Un casque audio sans fil', 'à réduction de bruit, une grande marque', 300.00),
  ('🎬', 'Une place de cinéma', 'plein tarif, en ville', 12.00),
  ('🚇', 'Un ticket de métro à Paris', 'à l’unité', 2.50),
  ('⛽', 'Un litre d’essence sans plomb 95', 'à la pompe', 1.80),
  ('💇', 'Une coupe homme chez le coiffeur', 'shampoing compris', 22.00),
  ('🌹', 'Un bouquet de 12 roses rouges', 'chez le fleuriste', 40.00),
  ('🐕', 'Un sac de croquettes pour chien', '10 kg, une grande marque', 40.00),
  ('🎂', 'Un gâteau d’anniversaire pour 8', 'à la pâtisserie', 30.00),
  ('🍽️', 'Un menu entrée-plat-dessert', 'dans une brasserie', 25.00),
  ('🧳', 'Une valise cabine', 'à roulettes, premier prix', 50.00),
  ('🕶️', 'Une paire de lunettes de soleil', 'de marque, chez l’opticien', 150.00),
  ('🪴', 'Une plante verte en pot', 'moyenne, en jardinerie', 20.00),
  ('🧽', 'Un lot de 3 éponges', 'au supermarché', 1.50),
  ('🎈', 'Un sachet de 20 ballons de baudruche', 'au supermarché', 3.00)
ON CONFLICT (name) DO NOTHING;

COMMIT;

\echo 'Juste prix : objets prêts.'
