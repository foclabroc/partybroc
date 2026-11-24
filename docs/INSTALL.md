# Installer PartyBroc sur un PC Windows

Il faut un PC Windows qui reste allumé avec PostgreSQL 17, Node.js 20 ou plus, [NSSM](https://nssm.cc/), [Caddy](https://caddyserver.com/) et Git, et un nom de domaine qui pointe vers ta box (par exemple un sous-domaine [DuckDNS](https://www.duckdns.org/) gratuit, avec les ports 80 et 443 redirigés vers le PC). PartyBroc a sa propre base, son propre rôle et son propre service : il peut cohabiter avec d'autres services sur le même PC.

Dans ce guide, le dossier est `C:\partybroc` et le domaine `party.ton-domaine.fr` : remplace-les par les tiens.

| Rôle | Quoi | Où |
|---|---|---|
| Base | base `party`, rôle `partybroc`, schéma `pb` | PostgreSQL 17 existant |
| Serveur temps réel + site | service NSSM `partybroc` (Node) | `C:\partybroc\server`, port local **4100** |
| Site compilé | Flutter web | `C:\partybroc\web` |
| HTTPS public | Caddy | `https://party.ton-domaine.fr` |

## 1. Récupérer le dépôt

```powershell
cd C:\
git clone https://github.com/foclabroc/partybroc.git
cd C:\partybroc
```

## 2. Base de données

Choisis un mot de passe pour le rôle `partybroc` (garde-le, il sert à l'étape 3).

```powershell
cd C:\partybroc\sql
psql -U postgres -d postgres -v pw="MOT_DE_PASSE" -f 00_creer_base.sql
$env:PGPASSWORD = "MOT_DE_PASSE"
psql -h localhost -U partybroc -d party -f 01_schema.sql
psql -h localhost -U partybroc -d party -f 02_quiz.sql
psql -h localhost -U partybroc -d party -f 03_quidenous.sql
psql -h localhost -U partybroc -d party -f 04_droles.sql
psql -h localhost -U partybroc -d party -f 05_dessin.sql
psql -h localhost -U partybroc -d party -f 06_salons.sql
psql -h localhost -U partybroc -d party -f 07_justeprix.sql
psql -h localhost -U partybroc -d party -f 08_quiadit.sql
psql -h localhost -U partybroc -d party -f 09_vraifaux.sql
psql -h localhost -U partybroc -d party -f 10_stats.sql
psql -h localhost -U partybroc -d party -f 11_quiadit_plus.sql
psql -h localhost -U partybroc -d party -f 12_rebus.sql
psql -h localhost -U partybroc -d party -f 13_quiz_plus.sql
psql -h localhost -U partybroc -d party -f 14_expressions.sql
psql -h localhost -U partybroc -d party -f 15_jours.sql
Remove-Item Env:PGPASSWORD
```

Tous les fichiers sont relançables. Quand une nouvelle version apporte un fichier SQL (`16_…`), il suffit de le lancer de la même façon.

En une seule commande, dans l'ordre :

```powershell
$env:PGPASSWORD = "MOT_DE_PASSE"
Get-ChildItem C:\partybroc\sql\[0-9][0-9]_*.sql | Where-Object Name -ne '00_creer_base.sql' | Sort-Object Name | ForEach-Object { psql -h localhost -U partybroc -d party -f $_.FullName }
Remove-Item Env:PGPASSWORD
```

## 3. Service Node

```powershell
cd C:\partybroc\server
npm.cmd ci --omit=dev

nssm install partybroc "C:\Program Files\nodejs\node.exe" "C:\partybroc\server\src\index.js"
nssm set partybroc AppDirectory C:\partybroc\server
nssm set partybroc AppEnvironmentExtra `
  PB_PORT=4100 `
  PB_WEB_DIR=C:\partybroc\web `
  "PB_DB_URL=postgresql://partybroc:MOT_DE_PASSE@localhost:5432/party"
nssm set partybroc AppStdout C:\partybroc\partybroc.log
nssm set partybroc AppStderr C:\partybroc\partybroc.log
nssm set partybroc AppRotateFiles 1
nssm set partybroc AppRotateBytes 5000000
nssm set partybroc Start SERVICE_AUTO_START
```

Si le mot de passe contient des caractères spéciaux (`@`, `:`, `/`, `#`…), il faut les encoder dans l'URL (`@` → `%40`, etc.).

## 4. Site web

Le site est compilé par GitHub (workflow `web`) à chaque push et déposé dans la release `web-latest`. Le script suivant le télécharge, met à jour le serveur et redémarre le service :

```powershell
cd C:\partybroc
.\deploy.ps1
```

Le même script sert pour **chaque mise à jour**. Plus simple : double-clique sur **`Mettre a jour.cmd`** dans `C:\partybroc` (il demande les droits administrateur, lance `deploy.ps1` et laisse la fenêtre ouverte à la fin pour lire le résultat). À la fin, `/health` doit répondre `ok: True, db: True`.

## 5. Caddy

Ajoute ce bloc dans le Caddyfile, puis recharge Caddy :

```
party.ton-domaine.fr {
	encode zstd gzip
	reverse_proxy 127.0.0.1:4100
}
```

```powershell
caddy reload --config CHEMIN\VERS\Caddyfile
```

Caddy fait le certificat HTTPS tout seul. Le WebSocket (`/ws`) passe par le même bloc.

## 6. Quiz cinéma et Blind test (accès Internet du serveur)

- **Blind test** : le serveur interroge l'API publique de Deezer (`api.deezer.com`, sans compte ni clé). Il suffit que le PC ait accès à Internet.
- **Quiz cinéma** : il faut une clé gratuite de [TMDB](https://www.themoviedb.org/settings/api) (créer un compte, puis « API » → clé de type v3). Mets-la seule dans le fichier `C:\partybroc\tmdb.key` (ou dans la variable `PB_TMDB_KEY` du service). Elle est relue à chaque partie : pas besoin de redémarrer. Ce fichier n'est jamais envoyé sur GitHub.

## 7. Essayer

- TV : ouvrir `https://party.ton-domaine.fr/tv` dans le navigateur de la TV, ou installer l'appli **PartyBroc TV** ([TV.md](TV.md)).
- Téléphone : scanner le QR affiché. Sur Android, le site propose « Installer la version Android » (appli **PartyBroc**, publiée par GitHub dans la release `tv-latest`).
- Écran vide sur un vieux navigateur de TV : essayer `/tv?rendu=cpu` (dessin logiciel) ou `/tv?rendu=gl`.

## Mises à jour

Double-clic sur **`Mettre a jour.cmd`** dans `C:\partybroc`. Le script :

1. récupère le code du dépôt GitHub (`git`),
2. installe les dépendances du serveur (`npm ci`),
3. télécharge le site compilé (release `web-latest`) et le fichier `assetlinks.json` des applis Android,
4. redémarre le service `partybroc` et vérifie `/health`.

Si la version apporte un fichier SQL, lance-le ensuite avec `psql` (voir l'étape 2). Les applis Android (TV et téléphone) voient la nouvelle version toutes seules et proposent de l'installer.

## Salon permanent

Sur l'écran TV, bouton **« Salon permanent »** : choisis un nom (5 à 12 lettres, ex. `MAISON`) et un mot de passe. Les joueurs entrent avec le nom du salon et le mot de passe (une seule fois par téléphone), même à distance. Pour changer le mot de passe ou supprimer un salon, voir la section « Salons permanents » de [CLAUDE.md](../CLAUDE.md).

## Ce qui reste privé

- Les **photos de profil ne sont jamais enregistrées** : elles restent en mémoire du serveur tant que le salon est ouvert, puis disparaissent.
- La base ne garde que l'historique : soirées, pseudos, scores.
- Le mot de passe de la base est seulement dans la config NSSM, jamais dans le dépôt.
