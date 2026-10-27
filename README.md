# PartyBroc 🎉

Jeux de soirée façon Jackbox : **la TV affiche, les téléphones jouent**.

La TV ouvre un salon et affiche un code et un QR. Chaque joueur scanne avec son téléphone, choisit un pseudo et une photo de profil (selfie, galerie ou emoji), et rejoint. Rien à installer : tout se passe dans le navigateur.

## Jeux

| | Jeu | État |
|---|---|---|
| 🎨 | Dessin à deviner | à venir |
| 🧠 | Quiz culture G | ✅ 150 questions, 10 catégories |
| 👀 | Qui de nous ? | à venir |
| ⚡ | Course de réflexes | à venir |
| 😂 | Réponses drôles | à venir |

## Organisation

```
app/      appli Flutter web : /tv (écran TV) et /play (téléphone)
server/   serveur Node : WebSocket temps réel + site + photos de profil
sql/      scripts PostgreSQL relançables (base « party »)
docs/     installation sur le serveur maison
```

Installation : [docs/INSTALL.md](docs/INSTALL.md).

## Développement

```bash
# serveur (sans base : l'historique est simplement désactivé)
cd server && npm install && npm start          # http://127.0.0.1:4100
npm test                                        # test du salon de bout en bout

# appli
cd app && flutter build web --wasm --no-web-resources-cdn   # le serveur sert app/build/web
# ou contre un autre serveur :  /tv?server=https://party.foclabroc.duckdns.org
```
