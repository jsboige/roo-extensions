#Requires -Version 5.1

<#
.SYNOPSIS
    Recette end-to-end (#3712) : simule un deploy "git clean + rebuild" sur un
    working tree de test, et verifie que le garde-fou empeche la destruction d'un
    fichier protege.

.DESCRIPTION
    Ce script reproduit le scenario du 17/09 :
      1. Working tree de test SANS .git, SANS .gitignore (= git-aveugle absolu).
      2. Creer .env + build/index.js (les deux fichiers qui ont disparu chez ai-01).
      3. Simuler un "deploy" : tentative de Remove-Item en passant par le garde.
      4. Verifier :
         a. Mode Block   : .env et build/ sont PRESERVES (compte bytes identique).
         b. Mode Backup  : backup cree, originaux laisses intacts.

    Cette recette est la preuve d'execution demandee par l'issue : "Recette
    executee sur un siege de test, pas seulement en unitaire".

.NOTES
    Issue #3712
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$scriptPath    = $PSScriptRoot
$guard         = Join-Path $scriptPath '..\..\mcp\deploy-preop-guard.ps1'
# GetTempPath() : cross-platform — $env:TEMP est null sur le runner CI Ubuntu
# (defaut deja corrige dans la suite de tests, ce site avait ete oublie, review #3714).
$tmpRoot       = Join-Path ([System.IO.Path]::GetTempPath()) "preop-guard-recette-$([Guid]::NewGuid().ToString('N').Substring(0,8))"

# --- Setup : creer un working tree simule ---
New-Item -ItemType Directory -Path $tmpRoot -Force | Out-Null
$envFile   = Join-Path $tmpRoot '.env'
$buildDir  = Join-Path $tmpRoot 'build'
$buildIdx  = Join-Path $buildDir  'index.js'

New-Item -ItemType Directory -Path $buildDir -Force | Out-Null

$envContent = "API_KEY=sk-recette-cle-secrete-1234`nDB_URL=postgres://x/y"
'module.exports = { runtime: "node", v: "20" }' | Set-Content -LiteralPath $buildIdx
$envContent | Set-Content -LiteralPath $envFile

$envBefore     = (Get-Content -LiteralPath $envFile -Raw).Trim()
$buildBefore   = (Get-Content -LiteralPath $buildIdx -Raw).Trim()

Write-Host "=== RECETTE #3712 : simulation deploy destructeur ===" -ForegroundColor Cyan
Write-Host "Tmp root   : $tmpRoot"
Write-Host ".env avant : $($envBefore.Substring(0, [Math]::Min(40, $envBefore.Length)))..."
Write-Host "build avant: $buildBefore"
Write-Host ""

# Charger le guard
. $guard

# --- (a) Mode Block : tentative de Remove-Item sur .env doit etre REFUSEE ---
Write-Host "--- (a) Mode Block sur .env ---" -ForegroundColor Yellow
$result = Invoke-DeployPreOpGuard -Operation "Remove-Item .env (deploy destructeur)" -LiteralPath $envFile -Mode Block -RepoRoot $tmpRoot
if ($result.Action -ne 'Blocked') {
    Write-Host "FAIL: attendu Blocked, obtenu $($result.Action)" -ForegroundColor Red
    exit 1
}
$envAfter = (Get-Content -LiteralPath $envFile -Raw).Trim()
if ($envAfter -ne $envBefore) {
    Write-Host "FAIL: .env modifie malgre Block !" -ForegroundColor Red
    exit 1
}
Write-Host "OK: Block a refuse, .env intact." -ForegroundColor Green
Write-Host ""

# --- (b) Mode Backup : le backup doit etre cree, l'original reste ---
Write-Host "--- (b) Mode Backup sur build/ ---" -ForegroundColor Yellow
$result = Invoke-DeployPreOpGuard -Operation "Remove-Item build/ (deploy clean)" -LiteralPath $buildDir -Mode Backup -RepoRoot $tmpRoot
if ($result.Action -ne 'BackedUp') {
    Write-Host "FAIL: attendu BackedUp, obtenu $($result.Action)" -ForegroundColor Red
    exit 1
}
if (-not $result.BackupDir -or -not (Test-Path -LiteralPath $result.BackupDir)) {
    Write-Host "FAIL: BackupDir absent ou introuvable : $($result.BackupDir)" -ForegroundColor Red
    exit 1
}
# Verifier que le backup contient bien index.js
$backupIdx = Get-ChildItem -LiteralPath $result.BackupDir -Recurse -Filter 'index.js' -File -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $backupIdx) {
    Write-Host "FAIL: index.js absent du backup" -ForegroundColor Red
    exit 1
}
$buildAfter = (Get-Content -LiteralPath $buildIdx -Raw).Trim()
if ($buildAfter -ne $buildBefore) {
    Write-Host "FAIL: build/index.js modifie malgre Backup (original doit rester)" -ForegroundColor Red
    exit 1
}
Write-Host "OK: Backup cree dans $($result.BackupDir), build/ original intact." -ForegroundColor Green
Write-Host ""

# --- (c) Mode Block sur build/ : on simule un deploy qui voudrait tout supprimer ---
Write-Host "--- (c) Mode Block sur build/ (simul 'git clean -fdx') ---" -ForegroundColor Yellow
$result = Invoke-DeployPreOpGuard -Operation "git clean -fdx (deploy destructeur)" -LiteralPath $buildDir -Mode Block -RepoRoot $tmpRoot
if ($result.Action -ne 'Blocked') {
    Write-Host "FAIL: attendu Blocked, obtenu $($result.Action)" -ForegroundColor Red
    exit 1
}
$buildAfter = (Get-Content -LiteralPath $buildIdx -Raw).Trim()
if ($buildAfter -ne $buildBefore) {
    Write-Host "FAIL: build/index.js modifie malgre Block !" -ForegroundColor Red
    exit 1
}
Write-Host "OK: Block a refuse 'git clean -fdx', build/ intact." -ForegroundColor Green
Write-Host ""

# --- (d) Volet racine : cible = le WORKTREE ROOT lui-meme (volet #3712 restant) ---
# Avant la detection d'ancetre, la cible root n'etant pas elle-meme protegee, le
# garde rendait Proceeded SANS backup : l'exemple CLI documente etait decoratif.
# scenarios :
#   d1. Block sur le root (le vrai "git clean -fdx .") doit etre REFUSE et ne rien detruire.
#   d2. Backup sur le root doit snapshotter .env ET build/ AVANT le clean simule.
Write-Host "--- (d) Volet racine : Block puis Backup sur le worktree ROOT ---" -ForegroundColor Yellow

# d1 : Block sur le root
$result = Invoke-DeployPreOpGuard -Operation "git clean -fdx" -LiteralPath $tmpRoot -Mode Block -RepoRoot $tmpRoot
if ($result.Action -ne 'Blocked') {
    Write-Host "FAIL (d1): attendu Blocked sur cible racine, obtenu $($result.Action)" -ForegroundColor Red
    exit 1
}
$envAfter   = (Get-Content -LiteralPath $envFile -Raw).Trim()
$buildAfter = (Get-Content -LiteralPath $buildIdx -Raw).Trim()
if ($envAfter -ne $envBefore -or $buildAfter -ne $buildBefore) {
    Write-Host "FAIL (d1): un protege a ete modifie malgre Block racine !" -ForegroundColor Red
    exit 1
}
Write-Host "OK (d1): Block a refuse le clean racine, .env et build/ intacts." -ForegroundColor Green

# d2 : Backup sur le root — .env ET build/index.js dans le snapshot
$result = Invoke-DeployPreOpGuard -Operation "git clean -fdx" -LiteralPath $tmpRoot -Mode Backup -RepoRoot $tmpRoot
if ($result.Action -ne 'BackedUp') {
    Write-Host "FAIL (d2): attendu BackedUp sur cible racine, obtenu $($result.Action)" -ForegroundColor Red
    exit 1
}
if (-not $result.BackupDir -or -not (Test-Path -LiteralPath $result.BackupDir)) {
    Write-Host "FAIL (d2): BackupDir absent ou introuvable : $($result.BackupDir)" -ForegroundColor Red
    exit 1
}
# -Force : dotfiles caches sur Unix (lecon #3714)
$snapped = @(Get-ChildItem -LiteralPath $result.BackupDir -Recurse -File -Force -ErrorAction SilentlyContinue |
             Select-Object -ExpandProperty Name)
if ($snapped -notcontains '.env') {
    Write-Host "FAIL (d2): .env absent du snapshot racine (contenu: $($snapped -join ', '))" -ForegroundColor Red
    exit 1
}
if ($snapped -notcontains 'index.js') {
    Write-Host "FAIL (d2): build/index.js absent du snapshot racine (contenu: $($snapped -join ', '))" -ForegroundColor Red
    exit 1
}
Write-Host "OK (d2): snapshot racine complet (.env + build/) dans $($result.BackupDir)." -ForegroundColor Green
Write-Host ""

# --- Cleanup ---
Remove-Item -LiteralPath $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "=== RECETTE REUSSIE : tous les scenarios bloques/backupes comme attendu ===" -ForegroundColor Green
exit 0
