# PartyBroc : mise à jour sur le serveur maison (PowerShell, en administrateur).
#   cd D:\partybroc ; .\deploy.ps1
# 1. récupère le code du serveur (git pull)
# 2. installe les dépendances Node
# 3. télécharge le site compilé (release web-latest) dans D:\partybroc\web
# 4. redémarre le service partybroc
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$repo = 'foclabroc/partybroc'

# Le redémarrage du service demande les droits administrateur : on vérifie avant de commencer
$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) { throw "Lance ce script dans un PowerShell ouvert en administrateur (clic droit > Exécuter en tant qu'administrateur)." }

# Arrête tout si une commande externe (git, npm, nssm) échoue
function Check($what) { if ($LASTEXITCODE -ne 0) { throw "$what a échoué (code $LASTEXITCODE), mise à jour arrêtée." } }

Write-Host '== Code du serveur' -ForegroundColor Cyan
git -C $root pull --ff-only
Check 'git pull'

Write-Host '== Dépendances Node' -ForegroundColor Cyan
Push-Location "$root\server"
npm.cmd ci --omit=dev
Check 'npm ci'
Pop-Location

Write-Host '== Site web' -ForegroundColor Cyan
$zip = Join-Path $env:TEMP 'partybroc-web.zip'
Invoke-WebRequest "https://github.com/$repo/releases/download/web-latest/partybroc-web.zip" -OutFile $zip
$web = Join-Path $root 'web'
$tmp = Join-Path $root 'web_new'
if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
Expand-Archive $zip -DestinationPath $tmp
if (Test-Path $web) { Remove-Item $web -Recurse -Force }
Rename-Item $tmp 'web'
Remove-Item $zip

Write-Host '== Redémarrage du service' -ForegroundColor Cyan
nssm restart partybroc
Check 'nssm restart'
Start-Sleep 2
Invoke-RestMethod http://127.0.0.1:4100/health
