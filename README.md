# PartyBroc 🎉

Jeux de soirée façon Jackbox : **la TV affiche, les téléphones jouent**.

La TV ouvre un salon et affiche un code et un QR. Jusqu'à 15 joueurs. Chaque joueur scanne avec son téléphone, choisit un pseudo et une photo de profil (selfie, galerie ou emoji), et rejoint. Rien à installer : tout se passe dans le navigateur.

## Jeux

| | Jeu | État |
|---|---|---|
| 🎨 | Dessin à deviner | ✅ 220 mots, dessin en direct sur la TV |
| 🧠 | Quiz culture G | ✅ 150 questions, 10 catégories |
| 👀 | Qui de nous ? | ✅ 80 questions, votes anonymes |
| ⚡ | Course de réflexes | ✅ 8 épreuves éclair (feu vert, taps, couleur, cibles, flèches…) |
| 😂 | Réponses drôles | ✅ 70 phrases à compléter, votes |
| 💶 | Le juste prix | ✅ 60 objets du quotidien, le prix le plus proche gagne |
| 💬 | Qui a dit ça ? | ✅ 110 questions perso, réponses secrètes, on devine l'auteur |
| ➗ | Course de calcul | ✅ 3 niveaux, le plus rapide gagne |
| 🧩 | Mémoire | ✅ une grille d'emojis à retenir |
| ✍️ | Petit bac | ✅ une lettre, 5 catégories, « Stop ! » |
| 🔍 | Zoom mystère | ✅ une image très zoomée qui se dévoile |
| 🏁 | Le dernier debout | ✅ vrai ou faux, une erreur et on sort |
| 📸 | Photo roulette | ✅ les photos des téléphones : à qui est celle-ci ? |
| 🏃 | Course au tap | ✅ gauche/droite en alternance, haies à sauter, turbos |

Musique sur l'écran TV (morceaux [Mixkit](https://mixkit.co/free-stock-music/), licence gratuite) : 5 morceaux au salon en lecture aléatoire, un pendant les jeux. Remplaçables par d'autres `.ogg` dans `app/assets/music/` (liste dans `app/lib/music.dart`).

## Organisation

```
app/      appli Flutter web : /tv (écran TV) et /play (téléphone)
server/   serveur Node : WebSocket temps réel + site + photos de profil
sql/      scripts PostgreSQL relançables (base « party »)
docs/     installation sur le serveur maison
```

Installation : [docs/INSTALL.md](docs/INSTALL.md). Appli Android TV : [docs/TV.md](docs/TV.md).

## Développement

```bash
# serveur (sans base : l'historique est simplement désactivé)
cd server && npm install && npm start          # http://127.0.0.1:4100
npm test                                        # test du salon de bout en bout

# appli
cd app && flutter build web --wasm --no-web-resources-cdn   # le serveur sert app/build/web
# ou contre un autre serveur :  /tv?server=https://party.foclabroc.duckdns.org
```
