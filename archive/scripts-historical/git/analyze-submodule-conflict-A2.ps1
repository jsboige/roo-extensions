# Script d'analyse exhaustive du conflit de sous-module Git
# Analyse UNIQUEMENT, aucune modification

$ErrorActionPreference = "Continue"
$OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "ANALYSE EXHAUSTIVE DU CONFLIT DE SOUS-MODULE" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Configuration
$repoRoot = "c:/dev/roo-extensions"
$submodulePath = "mcps/internal"
$submoduleFullPath = Join-Path $repoRoot $submodulePath

# Commits à analyser
$localCommit = "f4e5870"
$remoteCommit = "f724301"
$localBase1 = "a5770dc"
$localBase2 = "584810d"

Write-Host "================================================" -ForegroundColor Yellow
Write-Host "SECTION 1 : ÉTAT ACTUEL DES RÉFÉRENCES" -ForegroundColor Yellow
Write-Host "================================================" -ForegroundColor Yellow
Write-Host ""

# 1.1 - Vérifier .gitmodules dans le repo principal
Write-Host "--- 1.1 : Contenu de .gitmodules ---" -ForegroundColor Green
Set-Location $repoRoot
if (Test-Path ".gitmodules") {
    Get-Content ".gitmodules" | Write-Host
} else {
    Write-Host "ATTENTION: .gitmodules n'existe pas!" -ForegroundColor Red
}
Write-Host ""

# 1.2 - État du sous-module dans le repo principal
Write-Host "--- 1.2 : État du sous-module dans le repo principal ---" -ForegroundColor Green
git ls-files -s $submodulePath | Write-Host
Write-Host ""

# 1.3 - Référence actuelle dans le sous-module
Write-Host "--- 1.3 : Référence actuelle dans le sous-module ---" -ForegroundColor Green
Set-Location $submoduleFullPath
$currentHead = git rev-parse HEAD
Write-Host "HEAD actuel du sous-module: $currentHead"
Write-Host ""

# 1.4 - État Git du sous-module
Write-Host "--- 1.4 : État Git du sous-module ---" -ForegroundColor Green
git status --short --branch | Write-Host
Write-Host ""

Write-Host "================================================" -ForegroundColor Yellow
Write-Host "SECTION 2 : ANALYSE DES COMMITS CLÉS" -ForegroundColor Yellow
Write-Host "================================================" -ForegroundColor Yellow
Write-Host ""

# 2.1 - Analyser f4e5870 (notre commit de merge local)
Write-Host "--- 2.1 : Analyse de f4e5870 (notre merge local) ---" -ForegroundColor Green
if (git rev-parse --verify "$localCommit^{commit}" 2>$null) {
    Write-Host "Type:" -ForegroundColor Cyan
    git cat-file -t $localCommit | Write-Host
    Write-Host "`nMessage:" -ForegroundColor Cyan
    git log -1 --pretty=format:"%s%n%b" $localCommit | Write-Host
    Write-Host "`nParents:" -ForegroundColor Cyan
    git log -1 --pretty=format:"%P" $localCommit | Write-Host
    Write-Host "`nDétails:" -ForegroundColor Cyan
    git show --stat --oneline $localCommit | Write-Host
} else {
    Write-Host "ERREUR: Commit $localCommit introuvable!" -ForegroundColor Red
}
Write-Host ""

# 2.2 - Analyser f724301 (commit demandé par le remote)
Write-Host "--- 2.2 : Analyse de f724301 (commit remote) ---" -ForegroundColor Green
if (git rev-parse --verify "$remoteCommit^{commit}" 2>$null) {
    Write-Host "Type:" -ForegroundColor Cyan
    git cat-file -t $remoteCommit | Write-Host
    Write-Host "`nMessage:" -ForegroundColor Cyan
    git log -1 --pretty=format:"%s%n%b" $remoteCommit | Write-Host
    Write-Host "`nParents:" -ForegroundColor Cyan
    git log -1 --pretty=format:"%P" $remoteCommit | Write-Host
    Write-Host "`nDétails:" -ForegroundColor Cyan
    git show --stat --oneline $remoteCommit | Write-Host
} else {
    Write-Host "ERREUR: Commit $remoteCommit introuvable!" -ForegroundColor Red
    Write-Host "Tentative de récupération depuis les remotes..." -ForegroundColor Yellow
    git fetch --all 2>&1 | Write-Host
    if (git rev-parse --verify "$remoteCommit^{commit}" 2>$null) {
        Write-Host "`nCommit trouvé après fetch:" -ForegroundColor Green
        git show --stat --oneline $remoteCommit | Write-Host
    } else {
        Write-Host "Commit toujours introuvable après fetch" -ForegroundColor Red
    }
}
Write-Host ""

# 2.3 - Analyser les commits de base du merge local
Write-Host "--- 2.3 : Analyse de a5770dc (base locale 1) ---" -ForegroundColor Green
if (git rev-parse --verify "$localBase1^{commit}" 2>$null) {
    git show --stat --oneline $localBase1 | Write-Host
} else {
    Write-Host "ERREUR: Commit $localBase1 introuvable!" -ForegroundColor Red
}
Write-Host ""

Write-Host "--- 2.4 : Analyse de 584810d (base locale 2) ---" -ForegroundColor Green
if (git rev-parse --verify "$localBase2^{commit}" 2>$null) {
    git show --stat --oneline $localBase2 | Write-Host
} else {
    Write-Host "ERREUR: Commit $localBase2 introuvable!" -ForegroundColor Red
}
Write-Host ""

Write-Host "================================================" -ForegroundColor Yellow
Write-Host "SECTION 3 : RELATIONS ENTRE COMMITS" -ForegroundColor Yellow
Write-Host "================================================" -ForegroundColor Yellow
Write-Host ""

# 3.1 - Merge-base entre f4e5870 et f724301
Write-Host "--- 3.1 : Merge-base entre f4e5870 et f724301 ---" -ForegroundColor Green
if ((git rev-parse --verify "$localCommit^{commit}" 2>$null) -and (git rev-parse --verify "$remoteCommit^{commit}" 2>$null)) {
    $mergeBase = git merge-base $localCommit $remoteCommit 2>$null
    if ($mergeBase) {
        Write-Host "Merge-base trouvé: $mergeBase" -ForegroundColor Green
        Write-Host "`nDétails du merge-base:" -ForegroundColor Cyan
        git show --stat --oneline $mergeBase | Write-Host
    } else {
        Write-Host "AUCUN merge-base trouvé entre $localCommit et $remoteCommit" -ForegroundColor Red
        Write-Host "Cela signifie que les historiques sont complètement divergents!" -ForegroundColor Red
    }
} else {
    Write-Host "Impossible de calculer le merge-base (un ou plusieurs commits manquants)" -ForegroundColor Red
}
Write-Host ""

# 3.2 - Vérifier si f724301 est un ancêtre de f4e5870
Write-Host "--- 3.2 : f724301 est-il un ancêtre de f4e5870? ---" -ForegroundColor Green
if ((git rev-parse --verify "$localCommit^{commit}" 2>$null) -and (git rev-parse --verify "$remoteCommit^{commit}" 2>$null)) {
    if (git merge-base --is-ancestor $remoteCommit $localCommit 2>$null) {
        Write-Host "OUI: f724301 est un ancêtre de f4e5870" -ForegroundColor Green
        Write-Host "=> Notre merge inclut déjà le commit remote" -ForegroundColor Green
    } else {
        Write-Host "NON: f724301 n'est PAS un ancêtre de f4e5870" -ForegroundColor Red
        Write-Host "=> Les commits sont sur des branches divergentes" -ForegroundColor Red
    }
} else {
    Write-Host "Impossible de vérifier (un ou plusieurs commits manquants)" -ForegroundColor Red
}
Write-Host ""

# 3.3 - Vérifier si f4e5870 est un ancêtre de f724301
Write-Host "--- 3.3 : f4e5870 est-il un ancêtre de f724301? ---" -ForegroundColor Green
if ((git rev-parse --verify "$localCommit^{commit}" 2>$null) -and (git rev-parse --verify "$remoteCommit^{commit}" 2>$null)) {
    if (git merge-base --is-ancestor $localCommit $remoteCommit 2>$null) {
        Write-Host "OUI: f4e5870 est un ancêtre de f724301" -ForegroundColor Green
        Write-Host "=> Le commit remote inclut notre merge (fast-forward possible)" -ForegroundColor Green
    } else {
        Write-Host "NON: f4e5870 n'est PAS un ancêtre de f724301" -ForegroundColor Red
        Write-Host "=> Un nouveau merge est nécessaire" -ForegroundColor Red
    }
} else {
    Write-Host "Impossible de vérifier (un ou plusieurs commits manquants)" -ForegroundColor Red
}
Write-Host ""

Write-Host "================================================" -ForegroundColor Yellow
Write-Host "SECTION 4 : HISTORIQUE GRAPHIQUE" -ForegroundColor Yellow
Write-Host "================================================" -ForegroundColor Yellow
Write-Host ""

# 4.1 - Vue d'ensemble de l'historique récent
Write-Host "--- 4.1 : Historique récent (20 derniers commits) ---" -ForegroundColor Green
git log --graph --oneline --decorate -20 | Write-Host
Write-Host ""

# 4.2 - Historique incluant les commits spécifiques
Write-Host "--- 4.2 : Historique des commits analysés ---" -ForegroundColor Green
$commitsToShow = @($localCommit, $remoteCommit, $localBase1, $localBase2) | Where-Object { 
    git rev-parse --verify "$_^{commit}" 2>$null 
}
if ($commitsToShow.Count -gt 0) {
    git log --graph --oneline --decorate $commitsToShow -20 | Write-Host
} else {
    Write-Host "Aucun commit valide à afficher" -ForegroundColor Red
}
Write-Host ""

# 4.3 - Branches disponibles
Write-Host "--- 4.3 : Branches locales et remotes ---" -ForegroundColor Green
Write-Host "Branches locales:" -ForegroundColor Cyan
git branch -v | Write-Host
Write-Host "`nBranches remotes:" -ForegroundColor Cyan
git branch -rv | Write-Host
Write-Host ""

Write-Host "================================================" -ForegroundColor Yellow
Write-Host "SECTION 5 : ÉTAT DES REMOTES" -ForegroundColor Yellow
Write-Host "================================================" -ForegroundColor Yellow
Write-Host ""

# 5.1 - Liste des remotes
Write-Host "--- 5.1 : Remotes configurés ---" -ForegroundColor Green
git remote -v | Write-Host
Write-Host ""

# 5.2 - Références des remotes
Write-Host "--- 5.2 : Références des remotes ---" -ForegroundColor Green
git for-each-ref refs/remotes/ --format="%(refname:short) -> %(objectname:short) %(subject)" | Write-Host
Write-Host ""

Write-Host "================================================" -ForegroundColor Yellow
Write-Host "SECTION 6 : DIFFÉRENCES DE CONTENU" -ForegroundColor Yellow
Write-Host "================================================" -ForegroundColor Yellow
Write-Host ""

# 6.1 - Différences entre f4e5870 et f724301
Write-Host "--- 6.1 : Différences entre notre merge et le commit remote ---" -ForegroundColor Green
if ((git rev-parse --verify "$localCommit^{commit}" 2>$null) -and (git rev-parse --verify "$remoteCommit^{commit}" 2>$null)) {
    Write-Host "Statistiques des différences:" -ForegroundColor Cyan
    git diff --stat $remoteCommit..$localCommit | Write-Host
    Write-Host "`nFichiers modifiés:" -ForegroundColor Cyan
    git diff --name-status $remoteCommit..$localCommit | Write-Host
} else {
    Write-Host "Impossible de calculer les différences (un ou plusieurs commits manquants)" -ForegroundColor Red
}
Write-Host ""

Write-Host "================================================" -ForegroundColor Yellow
Write-Host "SECTION 7 : ÉTAT DU REPO PRINCIPAL" -ForegroundColor Yellow
Write-Host "================================================" -ForegroundColor Yellow
Write-Host ""

# 7.1 - Retour au repo principal
Set-Location $repoRoot

# 7.2 - État du conflit dans le repo principal
Write-Host "--- 7.1 : État du conflit dans le repo principal ---" -ForegroundColor Green
git status | Write-Host
Write-Host ""

# 7.3 - Différence d'index pour le sous-module
Write-Host "--- 7.2 : Différence d'index pour le sous-module ---" -ForegroundColor Green
git diff $submodulePath | Write-Host
Write-Host ""

# 7.4 - Références du sous-module dans différentes sources
Write-Host "--- 7.3 : Références du sous-module ---" -ForegroundColor Green
Write-Host "Index actuel:" -ForegroundColor Cyan
git ls-files -s $submodulePath | Write-Host
Write-Host "`nHEAD:" -ForegroundColor Cyan
git ls-tree HEAD $submodulePath | Write-Host
Write-Host "`nMERGE_HEAD (si existe):" -ForegroundColor Cyan
if (Test-Path ".git/MERGE_HEAD") {
    $mergeHead = Get-Content ".git/MERGE_HEAD"
    git ls-tree $mergeHead $submodulePath 2>$null | Write-Host
} else {
    Write-Host "Pas de MERGE_HEAD actif" -ForegroundColor Yellow
}
Write-Host ""

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "ANALYSE TERMINÉE" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Rapport généré avec succès" -ForegroundColor Green