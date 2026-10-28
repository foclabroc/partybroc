# PartyBroc TV : l'appli Android TV

Même écran que `https://party.foclabroc.duckdns.org/tv`, mais en appli native : pas de navigateur, donc pas de souci de WebGL ou de WebView. Elle se connecte toute seule au serveur `party.foclabroc.duckdns.org`, garde l'écran allumé et apparaît dans le launcher avec sa bannière.

Les téléphones, eux, restent sur le navigateur (QR affiché par la TV).

## Installer (ou mettre à jour) par ADB

Depuis le dossier `platform-tools` sur le PC :

```powershell
adb connect IP_DE_LA_TV
adb install -r partybroc-tv.apk
```

`-r` remplace l'ancienne version en gardant les réglages. La même commande sert pour chaque mise à jour.

Lancer sans passer par le launcher :

```powershell
adb shell monkey -p com.foclabroc.partybroc -c android.intent.category.LEANBACK_LAUNCHER 1
```

## Mise à jour automatique (depuis la 0.5.0)

L'appli vérifie au démarrage, au retour sur l'appli et toutes les 6 heures s'il existe une version plus récente dans la release **`tv-latest`** (fichier `tv-version.json`). Si oui, au salon (jamais pendant une partie) :

1. « Nouvelle version x.y.z » → **Mettre à jour** (ou bouton **Mise à jour** en haut du salon) ;
2. la première fois seulement : Android demande d'autoriser « PartyBroc TV » à installer des applis (« Sources inconnues ») → **Ouvrir les réglages**, autoriser, revenir avec Retour ;
3. téléchargement, puis l'installateur Android s'ouvre → **Installer** (cette confirmation est obligatoire sur Android, impossible de l'éviter sans être une appli système).

Pour que ça marche, GitHub doit pouvoir compiler et signer l'APK : il faut les deux secrets décrits plus bas. Ensuite, chaque push qui touche `app/` publie la nouvelle version.

## Où trouver l'APK

- Release **`tv-latest`** du dépôt (`partybroc-tv.apk`), recompilée à chaque push qui touche `app/`, une fois la clé de signature ajoutée dans les secrets (voir plus bas).

## Clé de signature

Android n'accepte une mise à jour que si elle est signée avec **la même clé** que la version installée. La clé `partybroc-tv.jks` (alias `partybroc`) n'est **jamais** dans le dépôt :

- garde une copie du fichier `.jks` et de son mot de passe en lieu sûr ;
- pour la compilation automatique, ajoute dans GitHub → Settings → Secrets and variables → Actions :
  - `ANDROID_KEYSTORE_BASE64` : le fichier encodé en base64 (PowerShell : `[Convert]::ToBase64String([IO.File]::ReadAllBytes("partybroc-tv.jks"))`)
  - `ANDROID_KEYSTORE_PASSWORD` : son mot de passe

Si la clé est perdue : désinstaller l'appli de la TV (`adb uninstall com.foclabroc.partybroc`), puis installer la nouvelle.

## Télécommande

- **OK** sur « Nouveau salon » (en haut à droite) : ouvre un salon neuf.
- **Retour** : quitte l'appli.
