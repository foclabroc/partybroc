# Installer PartyBroc sur le serveur maison

Même PC que Pixel Trade (PostgreSQL 17, NSSM, Node.js 24, Caddy). Rien de Pixel Trade n'est touché : base, rôle, service et sous-domaine sont séparés.

| Rôle | Quoi | Où |
|---|---|---|
| Base | base `party`, rôle `partybroc`, schéma `pb` | PostgreSQL 17 existant |
| Serveur temps réel + site | service NSSM `partybroc` (Node) | `D:\partybroc\server`, port local **4100** |
| Site compilé | Flutter web | `D:\partybroc\web` |
| HTTPS public | Caddy | `https://party.foclabroc.duckdns.org` |

## 1. Récupérer le dépôt

```powershell
cd D:\
git clone https://github.com/foclabroc/partybroc.git
cd D:\partybroc
```

## 2. Base de données

Choisis un mot de passe pour le rôle `partybroc` (garde-le, il sert à l'étape 3).

```powershell
cd D:\partybroc\sql
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
Remove-Item Env:PGPASSWORD
```

Tous les fichiers sont relançables. Chaque nouveau jeu apportera son fichier (`03_…`) : il suffit de le lancer de la même façon.

## 3. Service Node

```powershell
cd D:\partybroc\server
npm.cmd ci --omit=dev

nssm install partybroc "C:\Program Files\nodejs\node.exe" "D:\partybroc\server\src\index.js"
nssm set partybroc AppDirectory D:\partybroc\server
nssm set partybroc AppEnvironmentExtra `
  PB_PORT=4100 `
  PB_WEB_DIR=D:\partybroc\web `
  "PB_DB_URL=postgresql://partybroc:MOT_DE_PASSE@localhost:5432/party"
nssm set partybroc AppStdout D:\partybroc\partybroc.log
nssm set partybroc AppStderr D:\partybroc\partybroc.log
nssm set partybroc AppRotateFiles 1
nssm set partybroc AppRotateBytes 5000000
nssm set partybroc Start SERVICE_AUTO_START
```

Si le mot de passe contient des caractères spéciaux (`@`, `:`, `/`, `#`…), il faut les encoder dans l'URL (`@` → `%40`, etc.).

## 4. Site web

Le site est compilé par GitHub (workflow `web`) à chaque push et déposé dans la release `web-latest`. Le script suivant le télécharge, met à jour le serveur et redémarre le service :

```powershell
cd D:\partybroc
.\deploy.ps1
```

Le même script sert pour **chaque mise à jour**. Plus simple : double-clique sur **`Mettre a jour.cmd`** dans `D:\partybroc` (il demande les droits administrateur, lance `deploy.ps1` et laisse la fenêtre ouverte à la fin pour lire le résultat). À la fin, `/health` doit répondre `ok: True, db: True`.

## 5. Caddy

Ajoute ce bloc dans le Caddyfile (à côté de Jellyfin et de l'API Pixel Trade), puis recharge Caddy :

```
party.foclabroc.duckdns.org {
	encode zstd gzip
	reverse_proxy 127.0.0.1:4100
}
```

```powershell
caddy reload --config C:\caddy\Caddyfile
```

Comme pour `api.foclabroc.duckdns.org`, le sous-domaine `party.` suit automatiquement l'IP de DuckDNS, et Caddy fait le certificat tout seul. Le WebSocket (`/ws`) passe par le même bloc.

## 6. Essayer

- TV : ouvrir `https://party.foclabroc.duckdns.org/tv` dans le navigateur de la TV.
- Téléphone : scanner le QR affiché.

## Ce qui reste privé

- Les **photos de profil ne sont jamais enregistrées** : elles restent en mémoire du serveur tant que le salon est ouvert, puis disparaissent.
- La base ne garde que l'historique : soirées, pseudos, scores.
- Le mot de passe de la base est seulement dans la config NSSM, jamais dans le dépôt.
