# PartyBroc : mémo pour Claude

Appli de jeux de soirée multijoueur : la TV affiche (navigateur, `/tv`), chaque joueur joue sur son téléphone (navigateur, `/play`, via QR). Tout en français.

## Règles de travail

- **Ne jamais pousser sans un « pousse » explicite** : montrer les changements, attendre le feu vert.
- SQL : fichiers **relançables** (`IF NOT EXISTS`, `CREATE OR REPLACE`…) dans `sql/`, numérotés (`02_…`). Les donner **avant** de pousser le code qui en dépend ; l'utilisateur les lance lui-même.
- Après chaque push réussi : mettre à jour ce fichier (section « État »).
- Demander avant de faire une maquette HTML.
- **Ne jamais commiter la clé de signature Android** (`*.jks`, `key.properties`, déjà dans `.gitignore`).
- Les photos de profil ne vont **jamais** en base (mémoire du serveur seulement).

## Architecture

| Partie | Techno | Détails |
|---|---|---|
| `app/` | Flutter web (`--wasm --no-web-resources-cdn`, repli JS auto) | une seule appli : `/tv`, `/play?code=`, `/` accueil. Police Fredoka embarquée. |
| `server/` | Node 20+ (ES modules), `ws`, `pg` | sert le site (`PB_WEB_DIR`), les photos (`/a/CODE/pid/v`), `/health`, WebSocket `/ws`. Écoute 127.0.0.1:4100. |
| `sql/` | PostgreSQL 17 | base `party`, rôle `partybroc`, schéma `pb` (search_path par défaut du rôle). |
| Prod | PC serveur maison Windows | `D:\partybroc`, service NSSM `partybroc`, Caddy → `party.foclabroc.duckdns.org`. Même PC que Pixel Trade mais tout est séparé. |
| CI | `.github/workflows/web.yml` | compile le site à chaque push sur main → release `web-latest` (`partybroc-web.zip`). `deploy.ps1` sur le serveur le récupère. |
| Appli TV | `app/android`, `apk.yml` | **PartyBroc TV** : la même appli Flutter compilée en APK Android TV (`com.foclabroc.partybroc`, leanback, paysage, écran toujours allumé). Sur Android, `main.dart` ouvre directement `TvScreen` et `serverBase()` vaut `kServer` (`--dart-define=PB_SERVER`, défaut `https://party.foclabroc.duckdns.org`). `apk.yml` → release `tv-latest` (`partybroc-tv.apk`), seulement si les secrets `ANDROID_KEYSTORE_BASE64` / `ANDROID_KEYSTORE_PASSWORD` existent. Installation : `docs/TV.md`. |

Les salons vivent **en mémoire** du serveur (rapide). La base ne garde que l'historique : `pb_parties`, `pb_party_players`, `pb_games`. Si la base tombe, le jeu continue.

## Protocole WebSocket (JSON, champ `t`)

TV → serveur : `tv_hello {code?, tvToken?}` (retrouve son salon après rechargement, sinon en crée un), `tv_new`.
Téléphone → serveur : `join {code, name, emoji, color, photo(base64|'')}`, `resume {code, token}`, `profile {name?, emoji?, color?, photo?}`, `leave`, `ping`.
Hôte seulement : `kick {pid}`, `select_game {game}`, `start_game`.
Serveur → clients : `tv_ok`, `joined {code, pid, token}`, `room {room}` (diffusé à tous à chaque changement), `profile_ok`, `error {code, msg}` (`no_room`, `expired`, `refused`, `bad_profile`, `not_ready`, `not_enough`), `kicked`, `closed`, `replaced`, `left`, `pong`.

Règles du salon : code 4 consonnes, 10 joueurs max, pseudo 1–16 caractères unique (accents/majuscules ignorés), photo ≤ 60 Ko (JPEG/PNG/WebP vérifié par signature, l'appli envoie un JPEG 192×192). Le premier arrivé est l'hôte ; s'il se déconnecte, le suivant connecté prend la main. Joueur déconnecté : sa place est gardée 3 min (jeton dans le stockage du navigateur). Salon sans TV ni joueur : fermé après 15 min.

## Ajouter un jeu

Catalogue dans `server/src/games/index.js` (`ready: false` = affiché « Bientôt », `options` = réglages de l'hôte). Modèle : `games/quiz.js`.
- Classe avec `static async create(room, opts, hooks)` (charge le contenu en base), `start()`, `stop()`, `onMessage(player, m)`, `publicState()` (TV + tous), `playerState(pid)` (envoyé à chaque téléphone dans `you`), `onPlayerJoin(p)`, `onPlayerGone(p)`.
- `hooks.changed()` → rediffuse l'état ; `hooks.finished(results)` → retour au salon, points ajoutés au score de la soirée, ligne dans `pb_games`.
- Les téléphones envoient `game_msg {m: {...}}`, relayé au jeu. Messages hôte communs : `game_skip` (étape suivante / retour au salon depuis le podium), `game_end` (podium tout de suite).
- **Jamais de réponse dans `publicState()` avant la révélation.**
- Côté appli : `lib/games/<jeu>_state.dart` (lecture de l'état), `<jeu>_tv.dart`, `<jeu>_play.dart`, branchés dans `tv_screen.dart` et `play_screen.dart` selon `room.live['id']`.

## Tests

- `cd server && npm test` : salon (15 étapes) puis quiz (8 étapes, délais ×10 plus courts avec `PB_FAST=1`). Le quiz a besoin de `PB_DB_URL` (questions en base).
- `cd app && flutter analyze` : doit être propre.

## État

- **0.1.0** (27/10/2026, poussé sur main) : base `party`, serveur, salon TV + téléphone (pseudo, selfie/galerie ou emoji, couleur), hôte, expulsion, reconnexion. Les 5 jeux sont listés mais pas encore jouables.
- **0.2.0** (27/10/2026, poussé sur main) : Quiz culture G jouable (`sql/02_quiz.sql`, 150 questions / 10 catégories). 5, 10, 15 ou 20 questions, 20 s chacune, points = 500 + rapidité (jusqu'à 500) + série (100 par bonne réponse d'affilée, 300 max). Pas de question répétée dans la même soirée. Score de soirée affiché au salon.
- **0.2.1** (27/10/2026, poussé sur main) : démarrage plus robuste. CanvasKit servi par notre serveur (`--no-web-resources-cdn`, plus de gstatic), plus de service worker, écran « Chargement… » dans `index.html` avec un message clair si le navigateur ne peut pas lancer l'appli (sans WebAssembly, erreur, plus de 30 s) et l'agent utilisateur affiché. Sans WebGL (fréquent sur les navigateurs de TV), rendu logiciel automatique (`renderer: canvaskit`, `canvasKitForceCpuOnly`).
- **Modes de dessin** (`web/flutter_bootstrap.js`) : `?rendu=auto` (défaut : WebAssembly + WebGL, logiciel si pas de WebGL), `?rendu=gl` (JavaScript + WebGL), `?rendu=cpu` (JavaScript, dessin logiciel, le plus sûr). Le choix est retenu par le navigateur (localStorage `pb_rendu`). `?debug=1` affiche le mode, WebGL et l'agent utilisateur en bas de l'écran. Pour la TV (WebView 142, ARM 32 bits, Android 11), le mode `auto` donne un écran violet vide, à tester en `cpu` et `gl`.
- **0.3.0** (27/10/2026, poussé sur main) : appli Android TV « PartyBroc TV » (le navigateur de la TV de l'utilisateur, ARM 32 bits, n'affichait qu'un écran violet). Icône « PB » et bannière TV générées.
- Ordre validé : Quiz culture G ✅ → Qui de nous ? → Réponses drôles → Course de réflexes → Dessin à deviner. Puis soirée enchaînée.
