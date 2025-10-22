# =============================================================================
# SCRIPT DE FINALISATION COMPLÈTE AVEC PULL REBASE
# Mission : Synchronisation complète du dépôt principal et des sous-modules
# Date : 2025-10-20
# Auteur : Roo Code Mode
# =============================================================================

# Configuration
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

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

function Test-GitCommand {
    param([string]$Command)
    try {
        $null = Invoke-Expression $Command 2>$null
        return $LASTEXITCODE -eq 0
    }
    catch {
        return $false
    }
}

# =============================================================================
# ÉTAPE 1 : DIAGNOSTIC COMPLET DE L'ÉTAT ACTUEL
# =============================================================================

Write-Section "DIAGNOSTIC COMPLET : État actuel Git"

# Vérifier si on est dans un repo git
if (-not (Test-Path ".git")) {
    Write-Error "Ce n'est pas un dépôt Git!"
    exit 1
}

Write-SubSection "État du repo principal"
$mainStatus = git status --porcelain --branch
$mainLog = git log --oneline -5
$originLog = git log --oneline origin/main -5 2>$null

Write-Host "Status principal :"
$mainStatus

Write-Host "`nDerniers commits locaux :"
$mainLog

if ($originLog) {
    Write-Host "`nDerniers commits origin/main :"
    $originLog
}

# Vérifier les commits non poussés
$unpushed = git log --oneline origin/main..HEAD 2>$null
if ($unpushed) {
    Write-Host "`nCommits non poussés :"
    $unpushed
    Write-Host "Total : $($unpushed.Count) commits"
} else {
    Write-Success "Aucun commit non poussé sur le repo principal"
}

# État des sous-modules
Write-SubSection "État des sous-modules"
$submoduleStatus = git submodule status --recursive
Write-Host "Status des sous-modules :"
$submoduleStatus

# Analyse détaillée de chaque sous-module
$submoduleSummary = @()
git submodule foreach '
    echo "=== $name ==="
    git status --porcelain --branch 2>/dev/null || echo "Erreur de status"
    git log --oneline -3 2>/dev/null || echo "Erreur de log"
    echo ""
' 2>$null | ForEach-Object {
    if ($_ -match "^=== (.+) ===") {
        $currentSubmodule = $matches[1]
        $submoduleSummary += [PSCustomObject]@{
            Name = $currentSubmodule
            Status = ""
            Commits = ""
        }
    } elseif ($currentSubmodule -and $_) {
        if ($submoduleSummary[-1].Status -eq "") {
            $submoduleSummary[-1].Status = $_
        } elseif ($submoduleSummary[-1].Commits -eq "") {
            $submoduleSummary[-1].Commits = $_
        }
    }
}

# Vérifier les divergences des sous-modules
Write-SubSection "Vérification des divergences"
$submoduleDivergences = @()
git submodule foreach '
    echo "--- Divergences pour $name ---"
    AHEAD=$(git log origin/main..HEAD 2>/dev/null | wc -l)
    BEHIND=$(git log HEAD..origin/main 2>/dev/null | wc -l)
    echo "AHEAD: $AHEAD, BEHIND: $BEHIND"
    if [ $AHEAD -gt 0 ]; then
        echo "Commits en avance sur origin/main pour $name :"
        git log --oneline origin/main..HEAD
    fi
    if [ $BEHIND -gt 0 ]; then
        echo "Commits en retard sur origin/main pour $name :"
        git log --oneline HEAD..origin/main
    fi
    echo ""
' 2>$null

# =============================================================================
# ÉTAPE 2 : PULL REBASE DU DÉPÔT PRINCIPAL
# =============================================================================

Write-Section "PULL REBASE DÉPÔT PRINCIPAL"

# Fetch pour mettre à jour les informations du remote
Write-SubSection "Fetch des dernières modifications"
Write-Host "Récupération des dernières modifications depuis origin..."
git fetch origin

if ($LASTEXITCODE -ne 0) {
    Write-Error "Erreur lors du fetch depuis origin"
    exit 1
}

Write-Success "Fetch réussi"

# Vérifier s'il y a des modifications à récupérer
$localCommit = git rev-parse HEAD
$remoteCommit = git rev-parse origin/main 2>$null

Write-Host "Local : $localCommit"
Write-Host "Remote : $remoteCommit"

if ($localCommit -ne $remoteCommit) {
    Write-Warning "Divergence détectée, pull rebase nécessaire..."
    
    # Créer un backup avant le rebase
    $backupBranch = "backup-before-rebase-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    git branch $backupBranch
    Write-Success "Backup créé : $backupBranch"
    
    # Pull avec rebase
    Write-SubSection "Exécution du pull rebase"
    Write-Host "Exécution de git pull --rebase origin main..."
    
    $rebaseOutput = git pull --rebase origin main 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Pull rebase réussi"
        Write-Host "Output : $rebaseOutput"
    } else {
        Write-Error "Conflits lors du rebase - Résolution manuelle nécessaire"
        git status
        Write-Host "Fichiers en conflit :"
        $conflictFiles = git diff --name-only --diff-filter=U
        $conflictFiles
        
        # Instructions pour résoudre les conflits
        Write-Host "`n--- Instructions de resolution des conflits ---" -ForegroundColor Yellow
        Write-Host "1. Resoudre les conflits manuellement dans les fichiers listes"
        Write-Host "2. git add fichiers resolus"
        Write-Host "3. git rebase --continue"
        Write-Host "4. Si necessaire : git rebase --abort pour annuler"
        
        # Sortir en cas de conflit
        Write-Error "Arrêt du script dû à des conflits de rebase"
        exit 1
    }
} else {
    Write-Success "Dépôt principal déjà synchronisé"
}

# =============================================================================
# ÉTAPE 3 : SYNCHRONISATION DES SOUS-MODULES AVEC REBASE
# =============================================================================

Write-Section "SYNCHRONISATION DES SOUS-MODULES AVEC REBASE"

# Mettre à jour les sous-modules
Write-SubSection "Mise à jour des sous-modules"
Write-Host "Mise à jour des sous-modules avec --remote --merge..."
git submodule update --remote --merge

if ($LASTEXITCODE -ne 0) {
    Write-Warning "Erreur lors de la mise à jour des sous-modules, continuation manuelle..."
}

# Pour chaque sous-module, faire un pull rebase si nécessaire
Write-SubSection "Pull rebase des sous-modules nécessitant une synchronisation"

$submoduleSyncResults = @()
git submodule foreach '
    echo "=== Traitement du sous-module $name ==="
    
    # Aller dans le sous-module
    cd "$name"
    
    # Fetch des dernières modifications
    git fetch origin 2>/dev/null
    
    # Vérifier les divergences
    LOCAL=$(git rev-parse HEAD 2>/dev/null)
    REMOTE=$(git rev-parse origin/main 2>/dev/null)
    
    if [ "$LOCAL" != "$REMOTE" ] && [ -n "$REMOTE" ]; then
        echo "Divergence détectée pour $name"
        echo "Local : $LOCAL"
        echo "Remote : $REMOTE"
        
        # Pull avec rebase
        echo "Pull rebase pour $name..."
        git pull --rebase origin/main 2>&1
        
        if [ $? -eq 0 ]; then
            echo "✅ Pull rebase réussi pour $name"
            echo "SYNC_RESULT:SUCCESS:$name"
        else
            echo "❌ Conflits lors du rebase pour $name"
            git status
            echo "SYNC_RESULT:CONFLICT:$name"
        fi
    else
        echo "✅ $name déjà synchronisé"
        echo "SYNC_RESULT:SYNCED:$name"
    fi
    
    echo ""
' 2>$null | Tee-Object -Variable submoduleOutput

# Analyser les résultats de synchronisation
foreach ($line in $submoduleOutput) {
    if ($line -match "SYNC_RESULT:(.+):(.+)") {
        $status = $matches[1]
        $name = $matches[2]
        $submoduleSyncResults += [PSCustomObject]@{
            Name = $name
            Status = $status
        }
    }
}

# Afficher le résumé de synchronisation
Write-Host "`n--- Résumé de synchronisation des sous-modules ---" -ForegroundColor Yellow
foreach ($result in $submoduleSyncResults) {
    switch ($result.Status) {
        "SUCCESS" { Write-Success "$($result.Name) : Pull rebase réussi" }
        "CONFLICT" { Write-Error "$($result.Name) : Conflits détectés" }
        "SYNCED" { Write-Success "$($result.Name) : Déjà synchronisé" }
        default { Write-Warning "$($result.Name) : État inconnu" }
    }
}

# Mettre à jour les références des sous-modules dans le repo principal
Write-SubSection "Mise à jour des références des sous-modules"
git add mcps/ 2>$null
$commitResult = git commit -m "Update submodule references after rebase sync - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Success "Références des sous-modules mises à jour"
} else {
    Write-Host "Pas de mise à jour nécessaire pour les références des sous-modules"
}

# =============================================================================
# ÉTAPE 4 : VÉRIFICATION ET PUSH FINAL
# =============================================================================

Write-Section "VÉRIFICATION ET PUSH FINAL"

# Vérifier l'état final du repo principal
Write-SubSection "État final du repo principal"
$finalStatus = git status --branch
$finalLog = git log --oneline -5

Write-Host "Status final :"
$finalStatus

Write-Host "`nDerniers commits :"
$finalLog

# Vérifier les commits à pousser
$toPush = git log --oneline origin/main..HEAD 2>$null
if ($toPush) {
    Write-Host "`nCommits à pousser : $($toPush.Count)"
    $toPush
    
    # Push des modifications
    Write-SubSection "Push final"
    Write-Host "Push des modifications vers origin/main..."
    
    $pushOutput = git push origin main 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Push réussi"
    } else {
        Write-Error "Erreur lors du push"
        Write-Host "Output : $pushOutput"
    }
} else {
    Write-Success "Aucun commit à pousser"
}

# Vérifier l'état final des sous-modules
Write-SubSection "État final des sous-modules"
$finalSubmoduleStatus = git submodule status
Write-Host "Status final des sous-modules :"
$finalSubmoduleStatus

git submodule foreach '
    echo "=== $name ==="
    git status --branch 2>/dev/null || echo "Erreur de status"
    AHEAD=$(git log origin/main..HEAD 2>/dev/null | wc -l)
    if [ $AHEAD -gt 0 ]; then
        echo "⚠️ Commits non poussés pour $name :"
        git log --oneline origin/main..HEAD
    else
        echo "✅ $name synchronisé"
    fi
' 2>$null

# =============================================================================
# ÉTAPE 5 : VALIDATION COMPLÈTE
# =============================================================================

Write-Section "VALIDATION COMPLÈTE"

# État final global
Write-SubSection "État final global"
$globalStatus = git status
$globalLog = git log --oneline -3

Write-Host "Status global :"
$globalStatus

Write-Host "`nDerniers commits globaux :"
$globalLog

# Vérification que tout est propre
$workingTreeClean = -not (git status --porcelain)
if ($workingTreeClean) {
    Write-Success "Working tree clean"
} else {
    Write-Error "Working tree pas clean"
    git status --porcelain
}

# Vérification de la synchronisation avec origin/main
$localCommit = git rev-parse HEAD
$remoteCommit = git rev-parse origin/main 2>$null

if ($localCommit -eq $remoteCommit) {
    Write-Success "Repo principal synchronisé avec origin/main"
} else {
    Write-Error "Repo principal non synchronisé"
    Write-Host "Local : $localCommit"
    Write-Host "Remote : $remoteCommit"
}

# Vérification des sous-modules
Write-SubSection "Validation des sous-modules"
$allSubmodulesSynced = $true
$submoduleValidation = @()

git submodule foreach '
    cd "$name"
    LOCAL=$(git rev-parse HEAD 2>/dev/null)
    REMOTE=$(git rev-parse origin/main 2>/dev/null)
    if [ "$LOCAL" != "$REMOTE" ] && [ -n "$REMOTE" ]; then
        echo "VALIDATION_RESULT:NOT_SYNCED:$name"
    else
        echo "VALIDATION_RESULT:SYNCED:$name"
    fi
' 2>$null | ForEach-Object {
    if ($_ -match "VALIDATION_RESULT:(.+):(.+)") {
        $status = $matches[1]
        $name = $matches[2]
        $submoduleValidation += [PSCustomObject]@{
            Name = $name
            Status = $status
        }
        
        if ($status -eq "NOT_SYNCED") {
            $allSubmodulesSynced = $false
        }
    }
}

# Afficher les résultats de validation
foreach ($result in $submoduleValidation) {
    if ($result.Status -eq "SYNCED") {
        Write-Success "$($result.Name) synchronisé"
    } else {
        Write-Error "$($result.Name) non synchronisé"
    }
}

# Résultat final
Write-Section "RÉSULTAT FINAL DE SYNCHRONISATION"

if ($workingTreeClean -and $localCommit -eq $remoteCommit -and $allSubmodulesSynced) {
    Write-Success "🎉 SYNCHRONISATION COMPLÈTE ET FINALE RÉUSSIE"
    
    # Générer un rapport de succès
    $rapport = @"
# RAPPORT DE SYNCHRONISATION COMPLETE - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

## Etat Final
Repo principal synchronise avec origin/main
Working tree clean
Tous les sous-modules synchronises

## Commits pousses
$($toPush -join "`n")

## Sous-modules valides
$($submoduleValidation | Where-Object { $_.Status -eq 'SYNCED' } | ForEach-Object { "$($_.Name)" } | Out-String)

## Validation
Local: $localCommit
Remote: $remoteCommit
Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

"@
    
    $rapportPath = "scripts/git/rapport-synchronisation-complete-$(Get-Date -Format 'yyyyMMdd-HHmmss').md"
    $rapport | Out-File -FilePath $rapportPath -Encoding UTF8
    Write-Host "Rapport sauvegardé dans : $rapportPath"
    
} else {
    Write-Warning "⚠️ SYNCHRONISATION INCOMPLÈTE - Actions supplémentaires nécessaires"
    
    # Générer un rapport d'erreurs
    $problemes = @()
    if (-not $workingTreeClean) { $problemes += "Working tree pas clean" }
    if ($localCommit -ne $remoteCommit) { $problemes += "Repo principal non synchronise" }
    if (-not $allSubmodulesSynced) { $problemes += "Sous-modules non synchronises" }
    
    $rapportErreurs = @"
# RAPPORT D'ERREURS DE SYNCHRONISATION - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

## Problemes detectes
$($problemes -join "`n")

## Sous-modules non synchronises
$($submoduleValidation | Where-Object { $_.Status -eq 'NOT_SYNCED' } | ForEach-Object { "$($_.Name)" } | Out-String)

## Actions recommandees
1. Resoudre les problemes listes ci-dessus
2. Relancer le script de synchronisation
3. Verifier manuellement l'etat de chaque sous-module

## Etat actuel
Local: $localCommit
Remote: $remoteCommit
Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

"@
    
    $rapportErreursPath = "scripts/git/rapport-erreurs-synchronisation-$(Get-Date -Format 'yyyyMMdd-HHmmss').md"
    $rapportErreurs | Out-File -FilePath $rapportErreursPath -Encoding UTF8
    Write-Host "Rapport d'erreurs sauvegardé dans : $rapportErreursPath"
}

Write-Host "`n=== FIN DU SCRIPT DE SYNCHRONISATION ===" -ForegroundColor Cyan