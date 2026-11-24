# PartyBroc 🎉

Jeux de soirée à la maison : **la TV affiche, les téléphones jouent**.

La TV ouvre un salon et affiche un QR code. Chaque invité le scanne avec son téléphone, choisit un pseudo et une photo (selfie, galerie ou emoji), et joue. Jusqu'à 15 joueurs, 30 jeux, rien à installer : tout marche dans le navigateur. Pour plus de confort, il existe aussi une appli Android pour la TV et une pour les téléphones.

![Le salon : la TV (à gauche) et le téléphone de l'hôte (à droite)](docs/captures/salon.jpg)

## Sommaire

- [Comment se passe une soirée](#comment-se-passe-une-soirée)
- [Captures d'écran](#captures-décran)
- [Les 30 jeux](#les-30-jeux)
- [Fonctions](#fonctions)
- [Installation](#installation)
- [Fonctionnement technique](#fonctionnement-technique)
- [Développement](#développement)
- [Crédits](#crédits)

## Comment se passe une soirée

1. **La TV** ouvre `https://<ton-domaine>/tv` (ou l'appli **PartyBroc TV**) : un salon se crée avec un code de 4 lettres et un QR code.
2. **Chaque joueur** scanne le QR (ou tape le code, ou touche le salon dans « Salons disponibles » s'il est sur le même Wi-Fi), choisit son pseudo, sa photo et sa couleur.
3. **Le premier arrivé est l'hôte** : sur son téléphone, il choisit le jeu, règle les options (nombre de questions, temps, playlist…), ajoute des robots s'il manque du monde, puis lance la partie.
4. **Pendant le jeu**, la TV montre les questions, le plateau, les réponses des autres ; chacun répond ou joue sur son téléphone. Un animateur vocal lit les questions et annonce les résultats.
5. **Podium** avec feu d'artifice, puis retour au salon : les points s'ajoutent au **score de la soirée**, et on enchaîne avec un autre jeu.

Un joueur qui perd la connexion garde sa place 3 minutes et revient là où il en était.

## Captures d'écran

Chaque image montre l'écran de la TV (à gauche) et un téléphone de joueur (à droite).

| | |
|---|---|
| **Quiz culture G** : 613 questions, la plus rapide des bonnes réponses gagne le plus de points | **Petits chevaux** : le plateau français, un 6 pour sortir, on choisit son cheval sur le téléphone |
| ![Quiz](docs/captures/quiz.jpg) | ![Petits chevaux](docs/captures/chevaux.jpg) |
| **Vrai ou Bluff** : l'auteur défend son anecdote, les autres votent | **Chiffres et lettres** : le compte est bon, on combine les plaques sur le téléphone |
| ![Vrai ou Bluff](docs/captures/bluff.jpg) | ![Chiffres et lettres](docs/captures/chiffres.jpg) |
| **Blind test** : vrais extraits musicaux, artiste à gauche, titre à droite | **Yams** : les dés roulent sur la piste en bois, la feuille de tout le monde sur la TV |
| ![Blind test](docs/captures/blindtest.jpg) | ![Yams](docs/captures/yams.jpg) |
| **Scrabroc** : plateau sur la TV, chevalet et aperçu des points sur le téléphone | **Bataille de méninges** : 60 épreuves, chacun à son rythme, la course en direct sur la TV |
| ![Scrabroc](docs/captures/scrabroc.jpg) | ![Bataille de méninges](docs/captures/meninges.jpg) |
| **Jeu de l'oie** : oies, pont, puits, prison… et des cases Défi avec une question | |
| ![Jeu de l'oie](docs/captures/oie.jpg) | |

## Les 30 jeux

Le choix des jeux est rangé en deux onglets.

### 🎲 Jeux de société (11)

Ils se jouent aussi avec des **robots** (Facile ou Malin) quand il manque des joueurs. Un bouton « 📖 Règles » sur le téléphone donne les règles détaillées pendant la partie, et le téléphone sonne et vibre quand c'est ton tour.

| | Jeu | En bref |
|---|---|---|
| 🃏 | Broc-Pioche | Jeu de cartes type UNO : cumul des +2/+4, « Dernière carte ! » à annoncer |
| 📸 | Photo roulette | Chacun choisit des photos de sa galerie : à qui est celle-ci ? |
| 🪿 | Jeu de l'oie | Les 63 cases classiques, plus des cases Défi avec une question de quiz |
| 🎱 | Loto | Cartons français 3 × 9, boulier sur la TV ; ou mode « cartons papier » |
| 🐍 | Serpents et échelles | 100 cases, 8 échelles et 8 serpents |
| 🐴 | Petits chevaux | Plateau français, escalier de 1 à 6, équipes par couleur au-delà de 4 joueurs |
| 🎲 | Yams | 5 dés, 3 lancers, 13 cases à remplir |
| 🌈 | Skip-Broc | Jeu de cartes type Skip-Bo : vider son talon le premier |
| 🔤 | Scrabroc | Jeu de lettres type Scrabble, dictionnaire de 311 000 mots |
| 🂫 | Le Pouilleux | Faire des paires et ne pas finir avec le valet de pique |
| 💩 | Le tas de merde | Jeu de rapidité : un carré, et tout le monde tape |

### 🎉 Jeux fun (19)

| | Jeu | En bref |
|---|---|---|
| 🎨 | Dessin à deviner | Un joueur dessine sur son téléphone, le dessin apparaît en direct sur la TV (220 mots) |
| 🧠 | Quiz culture G | 613 questions dans 10 catégories |
| 👀 | Qui de nous ? | « Qui est le plus susceptible de… ? », votes anonymes (80 questions) |
| ⚡ | Course de réflexes | 8 épreuves éclair : feu vert, taps, couleurs, cibles, flèches… |
| 😂 | Réponses drôles | Compléter une phrase, puis voter pour la plus drôle (70 phrases) |
| 💶 | Le juste prix | Le prix le plus proche d'objets du quotidien (60 objets, en photo) |
| 💬 | Qui a dit ça ? | Réponses secrètes à des questions perso, on devine l'auteur (110 questions) |
| ➗ | Course de calcul | 3 niveaux, le plus rapide gagne |
| 🧩 | Mémoire | Une grille de photos à retenir |
| 💖 | Qui préfère… ? | Chacun dit sa couleur, son plat, sa saison préférés… puis on devine qui |
| 🔍 | Zoom mystère | Une photo très zoomée qui se dévoile petit à petit |
| 🏁 | Le dernier debout | Vrai ou faux : une erreur et on sort (164 affirmations) |
| 🧐 | Emoji rébus | Des emojis à décoder : film, expression, objet… (230 rébus) |
| 🗣️ | Expressions à trous | 428 expressions françaises à compléter, ou à expliquer |
| 🎵 | Blind test | Vrais extraits Deezer, 15 playlists (années 70 à 2020, Disney, rock, génériques…) |
| 🎬 | Quiz cinéma | Une image de film à reconnaître (images TMDB, tout public) |
| 🧠 | Bataille de méninges | 60 épreuves dans 7 catégories, chacun à son rythme, le cerveau le plus lourd gagne |
| 🤥 | Vrai ou Bluff | Une anecdote vraie ou inventée ? Le téléphone dit en secret s'il faut bluffer |
| 🔢 | Chiffres et lettres | Le mot le plus long et le compte est bon, comme à la télé |

Tous les contenus sont **tout public** (pas de questions osées, musiques à paroles explicites écartées, films classés tout public).

## Fonctions

- **Profil** : pseudo, selfie pris dans la page, photo de la galerie ou emoji, couleur.
- **Score de la soirée** et **classement sur la TV** à la demande de l'hôte.
- **Équipes** (2 à 4, renommables) : les points des membres s'additionnent.
- **Soirée enchaînée** : 2 à 6 jeux d'affilée avec un classement général entre chaque jeu et un grand podium final.
- **Salons permanents** protégés par un mot de passe (ex. `MAISON`) : la famille peut jouer à distance, chacun garde son profil, avec scores du jour, classements de tous les temps et statistiques par jeu. Dans ces salons, l'écran du jeu peut aussi s'afficher en petit sur chaque téléphone.
- **Robots** pour les jeux de société.
- **Animateur vocal**, **musique** au salon, **bruitages** (le tout réglable dans le menu « Sons » de la TV).
- **Inviter des joueurs** par SMS, WhatsApp, Messenger… depuis le téléphone.
- **Appli Android TV** « PartyBroc TV » (télécommande, mise à jour automatique) et **appli Android téléphone** « PartyBroc » (scan du QR, selfie, plein écran, mise à jour automatique). Sur iPhone, le site s'ajoute à l'écran d'accueil.

## Installation

PartyBroc s'installe sur un PC Windows qui reste allumé : base PostgreSQL, serveur Node.js lancé comme un service Windows (NSSM), et Caddy pour le HTTPS (avec un nom de domaine, par exemple un sous-domaine DuckDNS gratuit). Le site est compilé par GitHub, le serveur le télécharge tout seul.

| Étape | Résumé |
|---|---|
| 1. Prérequis | PostgreSQL 17, Node.js 20 ou plus, NSSM, Caddy, Git |
| 2. Dépôt | `git clone https://github.com/foclabroc/partybroc.git C:\partybroc` |
| 3. Base | créer la base `party` et le rôle `partybroc` (`sql/00_creer_base.sql`), puis lancer les fichiers `sql/01_` à `15_` |
| 4. Service | `npm ci --omit=dev` dans `server/`, puis service NSSM `partybroc` (port 4100, `PB_WEB_DIR`, `PB_DB_URL`) |
| 5. Site | double-clic sur **`Mettre a jour.cmd`** : télécharge le site compilé, met à jour le code, redémarre le service |
| 6. HTTPS | un bloc `reverse_proxy 127.0.0.1:4100` dans le Caddyfile |
| 7. Facultatif | clé TMDB gratuite dans `C:\partybroc\tmdb.key` pour le Quiz cinéma |

Pas à pas complet : **[docs/INSTALL.md](docs/INSTALL.md)**. Appli Android TV : **[docs/TV.md](docs/TV.md)**.

**Mettre à jour** : double-clic sur `Mettre a jour.cmd` dans le dossier de PartyBroc. Si une version apporte un nouveau fichier SQL, il est indiqué dans les notes de version ; on le lance avec `psql` comme les autres (tous les fichiers SQL sont relançables). Les applis Android proposent leur mise à jour toutes seules.

## Fonctionnement technique

```mermaid
flowchart LR
  TV["📺 TV<br/>navigateur /tv<br/>ou appli PartyBroc TV"] <-- WebSocket --> S
  P1["📱 Téléphones<br/>navigateur /play<br/>ou appli PartyBroc"] <-- WebSocket --> S
  S["Serveur Node<br/>salons et jeux en mémoire"] --> DB[("PostgreSQL<br/>contenus, historique,<br/>salons permanents")]
  S -. extraits, images .-> EXT["Deezer · TMDB"]
  C["Caddy (HTTPS)"] --- S
```

- **Une seule appli Flutter** pour tout : `/tv` (écran TV), `/play` (téléphone), compilée en site web (WebAssembly, avec repli automatique) et en deux APK Android (variantes `tv` et `phone`).
- **Le serveur Node** sert le site et garde les salons **en mémoire** : il fait tourner chaque jeu (minuteurs, dés, cartes, points) et envoie l'état à tout le monde par WebSocket. La TV reçoit l'état public, chaque téléphone reçoit en plus son état perso (sa main de cartes, sa consigne secrète…). **Les réponses ne quittent jamais le serveur avant la révélation.**
- **PostgreSQL** garde les contenus des jeux (questions, mots, phrases…), l'historique des soirées et les salons permanents. Si la base tombe, les parties continuent.
- **Vie privée** : les photos de profil restent dans la mémoire du serveur et disparaissent à la fermeture du salon, elles ne vont jamais en base. Les photos de Photo roulette sont effacées à la fin de la partie.

```
app/      appli Flutter : écran TV, téléphone, applis Android
server/   serveur Node : WebSocket, jeux, site, photos
sql/      scripts PostgreSQL relançables (base « party »)
tools/    scripts de fabrication (contenus, sons, icônes, photos)
docs/     installation, appli TV, captures d'écran
```

À chaque push sur `main`, GitHub Actions compile le site (release `web-latest`) et les APK (release `tv-latest`).

## Développement

```bash
# serveur (sans base : les jeux sans contenu en base marchent, l'historique est désactivé)
cd server && npm install && npm start            # http://127.0.0.1:4100
PB_DB_URL=postgres://partybroc:MOT_DE_PASSE@localhost/party npm start   # avec la base
PB_ROOMS_PER_IP=100 npm test                      # tous les tests (base nécessaire pour certains)
PB_FAST=1 node test/chevaux.test.js               # un seul jeu, délais ÷ 10

# appli
cd app && flutter build web --wasm --no-web-resources-cdn   # le serveur sert app/build/web
flutter analyze
# écran TV contre le vrai serveur :  /tv?server=https://<ton-domaine>
# en cas d'écran vide sur une vieille TV :  /tv?rendu=cpu
```

Le mémo détaillé du projet (protocole, chaque jeu, historique des versions) est dans [CLAUDE.md](CLAUDE.md).

## Crédits

- Musiques : [Mixkit](https://mixkit.co/free-stock-music/) (licence gratuite). Bruitages : fabriqués par `tools/bruitages.py`.
- Blind test : extraits de 30 secondes de l'API publique [Deezer](https://developers.deezer.com/).
- Quiz cinéma : images de [TMDB](https://www.themoviedb.org/) (ce produit utilise l'API TMDB mais n'est ni approuvé ni certifié par TMDB).
- Photos des jeux : [Pixabay](https://pixabay.com/) (`server/images/credits.csv`).
- Dictionnaire : paquet [an-array-of-french-words](https://www.npmjs.com/package/an-array-of-french-words) (licence MIT).
- Police : [Fredoka](https://fonts.google.com/specimen/Fredoka).
