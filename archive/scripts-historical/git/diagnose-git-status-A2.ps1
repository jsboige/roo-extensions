# Diagnostic Git - Action A.2
# Date: 2025-10-13
# But: Analyser l'état Git complet avant commit/sync

[CmdletBinding()]
param()

$ErrorActionPreference = "Continue"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

Write-Host "=== DIAGNOSTIC GIT COMPLET - Action A.2 ===" -ForegroundColor Cyan
Write-Host "Timestamp: $timestamp" -ForegroundColor Gray
Write-Host ""

# 1. Status du dépôt principal
Write-Host "=== 1. STATUS DEPOT PRINCIPAL ===" -ForegroundColor Yellow
try {
    git status
    Write-Host ""
    Write-Host "Branche actuelle:" -ForegroundColor Cyan
    git branch --show-current
    Write-Host ""
    Write-Host "Dernier commit:" -ForegroundColor Cyan
    git log -1 --oneline
} catch {
    Write-Host "Erreur lors de git status: $_" -ForegroundColor Red
}

# 2. Fichiers modifiés non commités
Write-Host ""
Write-Host "=== 2. FICHIERS MODIFIES (NON COMMITES) ===" -ForegroundColor Yellow
try {
    $modified = git diff --name-only
    if ($modified) {
        Write-Host "Fichiers modifies ($($modified.Count)):" -ForegroundColor Cyan
        $modified | ForEach-Object { Write-Host "  M $_" -ForegroundColor Yellow }
    } else {
        Write-Host "Aucun fichier modifie" -ForegroundColor Green
    }
} catch {
    Write-Host "Erreur lors de git diff: $_" -ForegroundColor Red
}

# 3. Fichiers non suivis
Write-Host ""
Write-Host "=== 3. FICHIERS NON SUIVIS ===" -ForegroundColor Yellow
try {
    $untracked = git ls-files --others --exclude-standard
    if ($untracked) {
        Write-Host "Fichiers non suivis ($($untracked.Count)):" -ForegroundColor Cyan
        $untracked | ForEach-Object { Write-Host "  ? $_" -ForegroundColor Magenta }
    } else {
        Write-Host "Aucun fichier non suivi" -ForegroundColor Green
    }
} catch {
    Write-Host "Erreur lors de git ls-files: $_" -ForegroundColor Red
}

# 4. Fichiers en staging
Write-Host ""
Write-Host "=== 4. FICHIERS EN STAGING ===" -ForegroundColor Yellow
try {
    $staged = git diff --cached --name-only
    if ($staged) {
        Write-Host "Fichiers en staging ($($staged.Count)):" -ForegroundColor Cyan
        $staged | ForEach-Object { Write-Host "  A $_" -ForegroundColor Green }
    } else {
        Write-Host "Aucun fichier en staging" -ForegroundColor Green
    }
} catch {
    Write-Host "Erreur lors de git diff --cached: $_" -ForegroundColor Red
}

# 5. Sous-modules
Write-Host ""
Write-Host "=== 5. SOUS-MODULES ===" -ForegroundColor Yellow
try {
    $submodules = git submodule status
    if ($submodules) {
        Write-Host "Sous-modules detectes:" -ForegroundColor Cyan
        $submodules | ForEach-Object { Write-Host "  $_" }
        
        Write-Host ""
        Write-Host "Verification des modifications dans les sous-modules..." -ForegroundColor Cyan
        git submodule foreach 'echo "=== $name ===" && git status --short'
    } else {
        Write-Host "Aucun sous-module configure" -ForegroundColor Green
    }
} catch {
    Write-Host "Erreur lors de git submodule: $_" -ForegroundColor Red
}

# 6. Comparaison avec remote
Write-Host ""
Write-Host "=== 6. COMPARAISON AVEC REMOTE ===" -ForegroundColor Yellow
try {
    Write-Host "Remote actuel:" -ForegroundColor Cyan
    git remote -v
    
    Write-Host ""
    Write-Host "Fetch des dernieres modifications..." -ForegroundColor Cyan
    git fetch --dry-run 2>&1
    
    Write-Host ""
    Write-Host "Commits en avance/retard:" -ForegroundColor Cyan
    $branch = git branch --show-current
    $ahead = git rev-list --count "origin/$branch..$branch" 2>$null
    $behind = git rev-list --count "$branch..origin/$branch" 2>$null
    
    if ($ahead) {
        Write-Host "  Commits en avance: $ahead" -ForegroundColor Yellow
    }
    if ($behind) {
        Write-Host "  Commits en retard: $behind" -ForegroundColor Yellow
    }
    if (-not $ahead -and -not $behind) {
        Write-Host "  Synchronise avec remote" -ForegroundColor Green
    }
} catch {
    Write-Host "Erreur lors de la comparaison remote: $_" -ForegroundColor Red
}

# 7. Statistiques détaillées
Write-Host ""
Write-Host "=== 7. STATISTIQUES DETAILLEES ===" -ForegroundColor Yellow
try {
    Write-Host "Nombre de lignes modifiees:" -ForegroundColor Cyan
    git diff --stat
} catch {
    Write-Host "Erreur lors de git diff --stat: $_" -ForegroundColor Red
}

# 8. Résumé des actions recommandées
Write-Host ""
Write-Host "=== 8. RESUME ET RECOMMANDATIONS ===" -ForegroundColor Cyan

$hasModified = (git diff --name-only) -ne $null
$hasUntracked = (git ls-files --others --exclude-standard) -ne $null
$hasStaged = (git diff --cached --name-only) -ne $null

Write-Host ""
Write-Host "Etat actuel:" -ForegroundColor Yellow
Write-Host "  Fichiers modifies: $(if ($hasModified) { 'OUI' } else { 'NON' })" -ForegroundColor $(if ($hasModified) { 'Yellow' } else { 'Green' })
Write-Host "  Fichiers non suivis: $(if ($hasUntracked) { 'OUI' } else { 'NON' })" -ForegroundColor $(if ($hasUntracked) { 'Magenta' } else { 'Green' })
Write-Host "  Fichiers en staging: $(if ($hasStaged) { 'OUI' } else { 'NON' })" -ForegroundColor $(if ($hasStaged) { 'Green' } else { 'Gray' })

Write-Host ""
Write-Host "Actions recommandees:" -ForegroundColor Cyan
if ($hasModified) {
    Write-Host "  1. Examiner les diffs: git diff" -ForegroundColor Yellow
    Write-Host "  2. Ajouter les fichiers: git add [fichiers]" -ForegroundColor Yellow
}
if ($hasUntracked) {
    Write-Host "  1. Verifier les fichiers non suivis" -ForegroundColor Magenta
    Write-Host "  2. Ajouter si necessaire: git add [fichiers]" -ForegroundColor Magenta
}
if ($hasStaged -or $hasModified) {
    Write-Host "  3. Creer un commit: git commit -m 'message'" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Timestamp fin: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host ""
Write-Host "=== FIN DU DIAGNOSTIC ===" -ForegroundColor Cyan