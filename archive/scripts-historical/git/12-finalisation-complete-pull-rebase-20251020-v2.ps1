# SCRIPT DE FINALISATION COMPLÈTE AVEC PULL REBASE
# Mission : Synchronisation complète du dépôt principal et des sous-modules
# Date : 2025-10-20

$ErrorActionPreference = "Stop"

function Write-Section {
    param([string]$Title)
    Write-Host "`n=== $Title ===" -ForegroundColor Cyan
}

function Write-SubSection {
    param([string]$Title)
    Write-Host "`n--- $Title ---" -ForegroundColor Yellow
}

function Write-Success {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor Red
}

# ETAPE 1 : DIAGNOSTIC
Write-Section "DIAGNOSTIC COMPLET"

if (-not (Test-Path ".git")) {
    Write-Error "Ce n'est pas un depot Git!"
    exit 1
}

Write-SubSection "Etat du repo principal"
git status --porcelain --branch
git log --oneline -5

$unpushed = git log --oneline origin/main..HEAD 2>$null
if ($unpushed) {
    Write-Host "Commits non pousses :"
    $unpushed
    Write-Host "Total : $($unpushed.Count) commits"
} else {
    Write-Success "Aucun commit non pousse"
}

Write-SubSection "Etat des sous-modules"
git submodule status --recursive

# ETAPE 2 : PULL REBASE PRINCIPAL
Write-Section "PULL REBASE DEPOT PRINCIPAL"

Write-SubSection "Fetch des modifications"
git fetch origin

if ($LASTEXITCODE -ne 0) {
    Write-Error "Erreur lors du fetch"
    exit 1
}

Write-Success "Fetch reussi"

$localCommit = git rev-parse HEAD
$remoteCommit = git rev-parse origin/main 2>$null

Write-Host "Local : $localCommit"
Write-Host "Remote : $remoteCommit"

if ($localCommit -ne $remoteCommit) {
    Write-Host "Divergence detectee, pull rebase necessaire..."
    
    $backupBranch = "backup-before-rebase-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    git branch $backupBranch
    Write-Success "Backup cree : $backupBranch"
    
    Write-Host "Execution du pull rebase..."
    git pull --rebase origin main
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Pull rebase reussi"
    } else {
        Write-Error "Conflits lors du rebase"
        git status
        exit 1
    }
} else {
    Write-Success "Depot principal deja synchronise"
}

# ETAPE 3 : SYNCHRONISATION SOUS-MODULES
Write-Section "SYNCHRONISATION DES SOUS-MODULES"

Write-SubSection "Mise a jour des sous-modules"
git submodule update --remote --merge

Write-SubSection "Pull rebase des sous-modules"
git submodule foreach '
    echo "=== Traitement de $name ==="
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
            echo "❌ Conflits pour $name"
        fi
    else
        echo "✅ $name deja synchronise"
    fi
' 2>$null

Write-SubSection "Mise a jour des references"
git add mcps/ 2>$null
git commit -m "Update submodule references after rebase sync - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" 2>$null

# ETAPE 4 : PUSH FINAL
Write-Section "PUSH FINAL"

$toPush = git log --oneline origin/main..HEAD 2>$null
if ($toPush) {
    Write-Host "Commits a pousser : $($toPush.Count)"
    $toPush
    
    Write-Host "Push des modifications..."
    git push origin main
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Push reussi"
    } else {
        Write-Error "Erreur lors du push"
    }
} else {
    Write-Success "Aucun commit a pousser"
}

# ETAPE 5 : VALIDATION
Write-Section "VALIDATION FINALE"

Write-SubSection "Etat final global"
git status
git log --oneline -3

$workingTreeClean = -not (git status --porcelain)
if ($workingTreeClean) {
    Write-Success "Working tree clean"
} else {
    Write-Error "Working tree pas clean"
}

$localCommit = git rev-parse HEAD
$remoteCommit = git rev-parse origin/main 2>$null

if ($localCommit -eq $remoteCommit) {
    Write-Success "Repo principal synchronise avec origin/main"
} else {
    Write-Error "Repo principal non synchronise"
}

Write-SubSection "Validation des sous-modules"
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

# RESULTAT FINAL
Write-Section "RESULTAT FINAL"

if ($workingTreeClean -and $localCommit -eq $remoteCommit) {
    Write-Success "SYNCHRONISATION COMPLETE REUSSIE"
    
    $rapport = "RAPPORT DE SYNCHRONISATION - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"
    $rapport += "Repo principal synchronise avec origin/main`n"
    $rapport += "Working tree clean`n"
    $rapport += "Local: $localCommit`n"
    $rapport += "Remote: $remoteCommit`n"
    
    $rapportPath = "scripts/git/rapport-synchronisation-complete-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
    $rapport | Out-File -FilePath $rapportPath -Encoding UTF8
    Write-Host "Rapport sauvegarde dans : $rapportPath"
} else {
    Write-Error "SYNCHRONISATION INCOMPLETE"
    
    $rapportErreurs = "RAPPORT D'ERREURS - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n"
    if (-not $workingTreeClean) { $rapportErreurs += "Working tree pas clean`n" }
    if ($localCommit -ne $remoteCommit) { $rapportErreurs += "Repo principal non synchronise`n" }
    $rapportErreurs += "Local: $localCommit`n"
    $rapportErreurs += "Remote: $remoteCommit`n"
    
    $rapportErreursPath = "scripts/git/rapport-erreurs-synchronisation-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
    $rapportErreurs | Out-File -FilePath $rapportErreursPath -Encoding UTF8
    Write-Host "Rapport d'erreurs sauvegarde dans : $rapportErreursPath"
}

Write-Host "FIN DU SCRIPT" -ForegroundColor Cyan