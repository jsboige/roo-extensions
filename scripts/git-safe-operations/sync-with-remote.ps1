#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Script de synchronisation Git sécurisée avec dépôt distant et sous-modules

.DESCRIPTION
    Automatise la synchronisation Git complète :
    - Commits des changements locaux
    - Pull sécurisé avec gestion des conflits
    - Synchronisation des sous-modules
    - Push final avec validation

.PARAMETER DryRun
    Mode simulation sans modifications réelles

.PARAMETER NoSubmodules
    Ignorer la synchronisation des sous-modules

.PARAMETER AutoCommit
    Commiter automatiquement les changements sans demander confirmation

.PARAMETER MergeStrategy
    Stratégie de merge : "merge" (défaut) ou "rebase"

.EXAMPLE
    .\sync-with-remote.ps1 -DryRun
    
.EXAMPLE
    .\sync-with-remote.ps1 -AutoCommit -MergeStrategy rebase
#>

param(
    [switch]$DryRun,
    [switch]$NoSubmodules,
    [switch]$AutoCommit,
    [ValidateSet("merge", "rebase")]
    [string]$MergeStrategy = "merge"
)

$ErrorActionPreference = "Stop"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logFile = "outputs/git-sync-$timestamp.log"

# Fonction de logging
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $logMessage = "[$timestamp] [$Level] $Message"
    Add-Content -Path $logFile -Value $logMessage
    
    switch ($Level) {
        "ERROR" { Write-Host $Message -ForegroundColor Red }
        "WARN" { Write-Host $Message -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $Message -ForegroundColor Green }
        "PHASE" { Write-Host $Message -ForegroundColor Cyan }
        default { Write-Host $Message }
    }
}

# Fonction de confirmation
function Confirm-Action {
    param([string]$Message)
    if ($AutoCommit -or $DryRun) { return $true }
    $response = Read-Host "$Message (o/N)"
    return $response -eq 'o'
}

# Initialisation
Write-Log "=== 🚀 SYNCHRONISATION GIT SÉCURISÉE ===" -Level "PHASE"
Write-Log "Timestamp: $timestamp"
Write-Log "Mode: $(if ($DryRun) { 'DRY-RUN' } else { 'RÉEL' })"
Write-Log "Stratégie merge: $MergeStrategy"
Write-Log "Log: $logFile"

try {
    # =============================================================================
    # PHASE 1 : DIAGNOSTIC ÉTAT INITIAL
    # =============================================================================
    Write-Log "`n=== 📊 PHASE 1 : DIAGNOSTIC ÉTAT INITIAL ===" -Level "PHASE"
    
    # État dépôt principal
    Write-Log "`n📍 Dépôt principal :" -Level "INFO"
    $mainStatus = git status --porcelain
    git status
    Write-Log "Fichiers modifiés: $($mainStatus.Count)"
    
    $mainBranch = git rev-parse --abbrev-ref HEAD
    Write-Log "Branche actuelle: $mainBranch"
    
    # Fetch remote
    Write-Log "`n🔄 Fetch remote..." -Level "INFO"
    git fetch origin
    
    # Comparaison avec remote
    $behind = git rev-list --count HEAD..origin/$mainBranch 2>$null
    $ahead = git rev-list --count origin/$mainBranch..HEAD 2>$null
    
    Write-Log "Commits en retard (remote → local): $behind" -Level "WARN"
    Write-Log "Commits en avance (local → remote): $ahead" -Level "INFO"
    
    if (-not $NoSubmodules) {
        Write-Log "`n📦 État sous-modules :" -Level "INFO"
        git submodule status
        
        # Identifier sous-modules avec changements
        $submoduleChanges = git submodule foreach --quiet 'git status --porcelain'
        if ($submoduleChanges) {
            Write-Log "⚠️ Sous-modules avec changements détectés" -Level "WARN"
        }
    }
    
    if (-not (Confirm-Action "`n⚠️ Continuer avec la synchronisation ?")) {
        Write-Log "❌ Synchronisation annulée par l'utilisateur" -Level "WARN"
        exit 0
    }
    
    # =============================================================================
    # PHASE 2 : COMMITS CHANGEMENTS LOCAUX (Dépôt Principal)
    # =============================================================================
    Write-Log "`n=== 💾 PHASE 2 : COMMITS CHANGEMENTS LOCAUX (Dépôt Principal) ===" -Level "PHASE"
    
    if ($mainStatus) {
        Write-Log "⚠️ Changements non commités détectés dans dépôt principal" -Level "WARN"
        git status --short
        
        if (Confirm-Action "`nCommiter ces changements maintenant ?") {
            $commitMsg = Read-Host "Message de commit"
            
            if (-not $DryRun) {
                git add -A
                git commit -m $commitMsg
                Write-Log "✅ Commit créé: $commitMsg" -Level "SUCCESS"
            } else {
                Write-Log "🔍 [DRY-RUN] Commit simulé: $commitMsg" -Level "INFO"
            }
        }
    } else {
        Write-Log "✅ Pas de changements non commités dans dépôt principal" -Level "SUCCESS"
    }
    
    # =============================================================================
    # PHASE 3 : COMMITS SOUS-MODULES
    # =============================================================================
    if (-not $NoSubmodules) {
        Write-Log "`n=== 📦 PHASE 3 : COMMITS SOUS-MODULES ===" -Level "PHASE"
        
        # Pour chaque sous-module avec changements
        git submodule foreach --quiet '
            if [ -n "$(git status --porcelain)" ]; then
                echo "⚠️ Sous-module avec changements : $name"
                git status --short
            fi
        ' | ForEach-Object {
            if ($_ -match "Sous-module avec changements : (.+)") {
                $submoduleName = $Matches[1]
                Write-Log "Traitement sous-module: $submoduleName" -Level "INFO"
                
                if (Confirm-Action "`nCommiter changements dans $submoduleName ?") {
                    $subCommitMsg = Read-Host "Message de commit pour $submoduleName"
                    
                    if (-not $DryRun) {
                        Push-Location $submoduleName
                        git add -A
                        git commit -m $subCommitMsg
                        Pop-Location
                        Write-Log "✅ Commit créé dans $submoduleName" -Level "SUCCESS"
                    } else {
                        Write-Log "🔍 [DRY-RUN] Commit simulé dans $submoduleName" -Level "INFO"
                    }
                }
            }
        }
    }
    
    # =============================================================================
    # PHASE 4 : PULL SÉCURISÉ (Dépôt Principal)
    # =============================================================================
    Write-Log "`n=== ⬇️ PHASE 4 : PULL SÉCURISÉ (Dépôt Principal) ===" -Level "PHASE"
    
    if ($behind -gt 0) {
        Write-Log "⚠️ $behind commits en retard sur origin/$mainBranch" -Level "WARN"
        
        # Afficher les commits distants
        Write-Log "`n📜 Commits distants à intégrer :" -Level "INFO"
        git log --oneline HEAD..origin/$mainBranch
        
        if (Confirm-Action "`nPuller maintenant avec stratégie '$MergeStrategy' ?") {
            if (-not $DryRun) {
                try {
                    if ($MergeStrategy -eq "rebase") {
                        git pull origin $mainBranch --rebase
                    } else {
                        git pull origin $mainBranch --no-rebase
                    }
                    Write-Log "✅ Pull réussi" -Level "SUCCESS"
                } catch {
                    Write-Log "❌ CONFLIT DÉTECTÉ durant le pull" -Level "ERROR"
                    Write-Log "Fichiers en conflit :" -Level "ERROR"
                    git status | Select-String "both modified"
                    
                    Write-Log @"
`n🛠️ RÉSOLUTION MANUELLE REQUISE :
1. Ouvrir fichiers en conflit dans éditeur
2. Chercher markers <<<<<<< ======= >>>>>>>
3. Résoudre manuellement les conflits
4. git add <fichiers_résolus>
5. $(if ($MergeStrategy -eq 'rebase') { 'git rebase --continue' } else { 'git commit' })
"@ -Level "WARN"
                    
                    throw "Conflits nécessitent résolution manuelle"
                }
            } else {
                Write-Log "🔍 [DRY-RUN] Pull simulé" -Level "INFO"
            }
        }
    } else {
        Write-Log "✅ Déjà à jour avec origin/$mainBranch" -Level "SUCCESS"
    }
    
    # =============================================================================
    # PHASE 5 : PULL SOUS-MODULES
    # =============================================================================
    if (-not $NoSubmodules) {
        Write-Log "`n=== 📦 PHASE 5 : PULL SOUS-MODULES ===" -Level "PHASE"
        
        if (-not $DryRun) {
            Write-Log "Mise à jour sous-modules..." -Level "INFO"
            git submodule update --remote --merge
            
            # Vérifier si sous-modules ont changé
            $submoduleChanges = git status --porcelain | Select-String "modified:"
            if ($submoduleChanges) {
                Write-Log "⚠️ Sous-modules mis à jour, commit nécessaire" -Level "WARN"
                git status --short
                
                if (Confirm-Action "`nCommiter mise à jour sous-modules ?") {
                    git add .
                    git commit -m "chore: Update submodules to latest"
                    Write-Log "✅ Commit mise à jour sous-modules créé" -Level "SUCCESS"
                }
            } else {
                Write-Log "✅ Sous-modules déjà à jour" -Level "SUCCESS"
            }
        } else {
            Write-Log "🔍 [DRY-RUN] Mise à jour sous-modules simulée" -Level "INFO"
        }
    }
    
    # =============================================================================
    # PHASE 6 : VALIDATION PRÉ-PUSH
    # =============================================================================
    Write-Log "`n=== ✅ PHASE 6 : VALIDATION PRÉ-PUSH ===" -Level "PHASE"
    
    # Vérifier working tree propre
    $finalStatus = git status --porcelain
    if ($finalStatus) {
        Write-Log "⚠️ Working tree non propre :" -Level "WARN"
        git status --short
    } else {
        Write-Log "✅ Working tree propre" -Level "SUCCESS"
    }
    
    # Vérifier commits à pusher
    $finalAhead = git rev-list --count origin/$mainBranch..HEAD 2>$null
    Write-Log "📤 $finalAhead commits à pusher" -Level "INFO"
    
    if ($finalAhead -gt 0) {
        Write-Log "`n📜 Commits à pusher :" -Level "INFO"
        git log --oneline origin/$mainBranch..HEAD
        
        # Dry-run du push
        Write-Log "`n🔍 Dry-run push :" -Level "INFO"
        git push --dry-run origin $mainBranch
    }
    
    # =============================================================================
    # PHASE 7 : PUSH FINAL
    # =============================================================================
    Write-Log "`n=== 🚀 PHASE 7 : PUSH FINAL ===" -Level "PHASE"
    
    if ($finalAhead -gt 0) {
        if (Confirm-Action "`n🚀 Pusher $finalAhead commits vers origin/$mainBranch ?") {
            if (-not $DryRun) {
                git push origin $mainBranch
                Write-Log "✅ Push réussi !" -Level "SUCCESS"
                
                # Push sous-modules si nécessaire
                if (-not $NoSubmodules) {
                    Write-Log "`n📦 Push sous-modules..." -Level "INFO"
                    git submodule foreach 'git push origin HEAD || echo "No push needed for $name"'
                }
            } else {
                Write-Log "🔍 [DRY-RUN] Push simulé" -Level "INFO"
            }
        }
    } else {
        Write-Log "✅ Rien à pusher" -Level "SUCCESS"
    }
    
    # =============================================================================
    # VÉRIFICATION FINALE
    # =============================================================================
    Write-Log "`n=== 🎯 VÉRIFICATION FINALE ===" -Level "PHASE"
    
    Write-Log "`n📊 État final :" -Level "INFO"
    git status
    
    Write-Log "`n📜 Derniers commits :" -Level "INFO"
    git log --oneline -5
    
    if (-not $NoSubmodules) {
        Write-Log "`n📦 État sous-modules final :" -Level "INFO"
        git submodule status
    }
    
    Write-Log "`n✅ SYNCHRONISATION TERMINÉE AVEC SUCCÈS !" -Level "SUCCESS"
    Write-Log "Log complet disponible : $logFile"
    
} catch {
    Write-Log "`n❌ ERREUR DURANT SYNCHRONISATION" -Level "ERROR"
    Write-Log "Message: $($_.Exception.Message)" -Level "ERROR"
    Write-Log "StackTrace: $($_.ScriptStackTrace)" -Level "ERROR"
    Write-Log "Log disponible : $logFile" -Level "ERROR"
    exit 1
}