# PartyBroc : mise à jour sur le serveur maison (PowerShell, en administrateur).
#   cd D:\partybroc ; .\deploy.ps1
# 1. récupère le code du serveur (git pull)
# 2. installe les dépendances Node
# 3. télécharge le site compilé (release web-latest) dans D:\partybroc\web
# 4. redémarre le service partybroc
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$repo = 'foclabroc/partybroc'

Write-Host '== Code du serveur' -ForegroundColor Cyan
git -C $root pull --ff-only

Write-Host '== Dépendances Node' -ForegroundColor Cyan
Push-Location "$root\server"
npm.cmd ci --omit=dev
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
Start-Sleep 2
Invoke-RestMethod http://127.0.0.1:4100/health
