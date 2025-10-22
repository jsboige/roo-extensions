# =============================================================================
# SCRIPT DE FINALISATION COMPLÈTE AVEC PULL REBASE - VERSION SIMPLIFIÉE
# Mission : Synchronisation complète du dépôt principal et des sous-modules
# Date : 2025-10-20
# =============================================================================

# Configuration
$ErrorActionPreference = "Stop"

# Fonctions utilitaires
function Write-Section {
    param([string]$Title, [string]$Color = "Cyan")
    Write-Host "`n=== $Title ===" -ForegroundColor $Color
}

function Write-SubSection {
    param([string]$Title, [string]$Color = "Yellow")
    Write-Host "`n--- $Title ---" -ForegroundColor $Color
}

function Write-Success {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠️ $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor Red
}

# =============================================================================
# ÉTAPE 1 : DIAGNOSTIC COMPLET
# =============================================================================

Write-Section "DIAGNOSTIC COMPLET : Etat actuel Git"

# Vérifier si on est dans un repo git
if (-not (Test-Path ".git")) {
    Write-Error "Ce n'est pas un depot Git!"
    exit 1
}

Write-SubSection "Etat du repo principal"
git status --porcelain --branch
git log --oneline -5

# Vérifier les commits non poussés
$unpushed = git log --oneline origin/main..HEAD 2>$null
if ($unpushed) {
    Write-Host "Commits non pousses :"
    $unpushed
    Write-Host "Total : $($unpushed.Count) commits"
} else {
    Write-Success "Aucun commit non pousse sur le repo principal"
}

# État des sous-modules
Write-SubSection "Etat des sous-modules"
git submodule status --recursive

# =============================================================================
# ÉTAPE 2 : PULL REBASE DU DÉPÔT PRINCIPAL
# =============================================================================

Write-Section "PULL REBASE DEPÔT PRINCIPAL"

# Fetch pour mettre à jour les informations du remote
Write-SubSection "Fetch des dernieres modifications"
git fetch origin

if ($LASTEXITCODE -ne 0) {
    Write-Error "Erreur lors du fetch depuis origin"
    exit 1
}

Write-Success "Fetch reussi"

# Vérifier s'il y a des modifications à récupérer
$localCommit = git rev-parse HEAD
$remoteCommit = git rev-parse origin/main 2>$null

Write-Host "Local : $localCommit"
Write-Host "Remote : $remoteCommit"

if ($localCommit -ne $remoteCommit) {
    Write-Warning "Divergence detectee, pull rebase necessaire..."
    
    # Créer un backup avant le rebase
    $backupBranch = "backup-before-rebase-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    git branch $backupBranch
    Write-Success "Backup cree : $backupBranch"
    
    # Pull avec rebase
    Write-SubSection "Execution du pull rebase"
    git pull --rebase origin main
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Pull rebase reussi"
    } else {
        Write-Error "Conflits lors du rebase"
        git status
        Write-Host "Fichiers en conflit :"
        git diff --name-only --diff-filter=U
        exit 1
    }
} else {
    Write-Success "Depot principal deja synchronise"
}

# =============================================================================
# ÉTAPE 3 : SYNCHRONISATION DES SOUS-MODULES
# =============================================================================

Write-Section "SYNCHRONISATION DES SOUS-MODULES"

# Mettre à jour les sous-modules
Write-SubSection "Mise a jour des sous-modules"
git submodule update --remote --merge

# Pour chaque sous-module, faire un pull rebase si nécessaire
Write-SubSection "Pull rebase des sous-modules"

git submodule foreach '
    echo "=== Traitement du sous-module $name ==="
    cd "$name"
    git fetch origin 2>/dev/null
    LOCAL=$(git rev-parse HEAD 2>/dev/null)
    REMOTE=$(git rev-parse origin/main 2>/dev/null)
    if [ "$LOCAL" != "$REMOTE" ] && [ -n "$REMOTE" ]; then
        echo "Divergence detectee pour $name"
        git pull --rebase origin/main 2>&1
        if [ $? -eq 0 ]; then
            echo "✅ Pull rebase reussi pour $name"
        else
            echo "❌ Conflits lors du rebase pour $name"
        fi
    else
        echo "✅ $name deja synchronise"
    fi
' 2>$null

# Mettre à jour les références des sous-modules dans le repo principal
Write-SubSection "Mise a jour des references des sous-modules"
git add mcps/ 2>$null
git commit -m "Update submodule references after rebase sync - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" 2>$null

# =============================================================================
# ÉTAPE 4 : PUSH FINAL
# =============================================================================

Write-Section "PUSH FINAL"

# Vérifier les commits à pousser
$toPush = git log --oneline origin/main..HEAD 2>$null
if ($toPush) {
    Write-Host "Commits a pousser : $($toPush.Count)"
    $toPush
    
    # Push des modifications
    Write-SubSection "Push final"
    git push origin main
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Push reussi"
    } else {
        Write-Error "Erreur lors du push"
    }
} else {
    Write-Success "Aucun commit a pousser"
}

# =============================================================================
# ÉTAPE 5 : VALIDATION FINALE
# =============================================================================

Write-Section "VALIDATION FINALE"

# État final global
Write-SubSection "Etat final global"
git status
git log --oneline -3

# Vérification que tout est propre
$workingTreeClean = -not (git status --porcelain)
if ($workingTreeClean) {
    Write-Success "Working tree clean"
} else {
    Write-Error "Working tree pas clean"
}

# Vérification de la synchronisation avec origin/main
$localCommit = git rev-parse HEAD
$remoteCommit = git rev-parse origin/main 2>$null

if ($localCommit -eq $remoteCommit) {
    Write-Success "Repo principal synchronise avec origin/main"
} else {
    Write-Error "Repo principal non synchronise"
}

# Vérification des sous-modules
Write-SubSection "Validation des sous-modules"
$allSubmodulesSynced = $true

git submodule foreach '
    cd "$name"
    LOCAL=$(git rev-parse HEAD 2>/dev/null)
    REMOTE=$(git rev-parse origin/main 2>/dev/null)
    if [ "$LOCAL" != "$REMOTE" ] && [ -n "$REMOTE" ]; then
        echo "❌ $name non synchronise"
    else
        echo "✅ $name synchronise"
    fi
' 2>$null

# Résultat final
Write-Section "RESULTAT FINAL"

if ($workingTreeClean -and $localCommit -eq $remoteCommit) {
    Write-Success "SYCHRONISATION COMPLETE REUSSIE"
    
    $rapport = "RAPPORT DE SYNCHRONISATION - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"
    $rapport += "Repo principal synchronise avec origin/main`n"
    $rapport += "Working tree clean`n"
    $rapport += "Local: $localCommit`n"
    $rapport += "Remote: $remoteCommit`n"
    
    $rapportPath = "scripts/git/rapport-synchronisation-complete-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
    $rapport | Out-File -FilePath $rapportPath -Encoding UTF8
    Write-Host "Rapport sauvegarde dans : $rapportPath"
    
} else {
    Write-Warning "SYNCHRONISATION INCOMPLETE - Actions supplementaires necessaires"
    
    $rapportErreurs = "RAPPORT D'ERREURS - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"
    $rapportErreurs += "Problemes detectes`n"
    if (-not $workingTreeClean) { $rapportErreurs += "Working tree pas clean`n" }
    if ($localCommit -ne $remoteCommit) { $rapportErreurs += "Repo principal non synchronise`n" }
    $rapportErreurs += "Local: $localCommit`n"
    $rapportErreurs += "Remote: $remoteCommit`n"
    
    $rapportErreursPath = "scripts/git/rapport-erreurs-synchronisation-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
    $rapportErreurs | Out-File -FilePath $rapportErreursPath -Encoding UTF8
    Write-Host "Rapport d'erreurs sauvegarde dans : $rapportErreursPath"
}

# Fin du script