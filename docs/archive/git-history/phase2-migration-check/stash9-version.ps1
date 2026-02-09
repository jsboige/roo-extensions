# Fichier : d:/roo-extensions/sync_roo_environment.ps1

$RepoPath = "d:/roo-extensions"
$LogFile = "d:/roo-extensions/sync_log.txt"
$ConflictLogDir = "d:/roo-extensions/sync_conflicts"

# Créer le répertoire de logs de conflits si inexistant
If (-not (Test-Path $ConflictLogDir)) {
    New-Item -ItemType Directory -Path $ConflictLogDir | Out-Null
}

function Log-Message {
    Param (
        [string]$Message,
        [string]$Type = "INFO" # INFO, ALERTE, ERREUR
    )
    Add-Content -Path $LogFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $($Type): $($Message)"
}

Set-Location $RepoPath

# Étape 1: Préparation et Vérification de l'Environnement Git
Log-Message "Vérification du statut Git avant pull..."
$GitStatus = (& git status --porcelain 2>&1)
if ($GitStatus) {
    Log-Message "Modifications locales détectées. Tentative de stash..." "ALERTE"
    Try {
        $StashOutput = (& git stash push -m "Automated stash before sync pull" 2>&1)
        if ($LASTEXITCODE -ne 0) {
            throw "Git stash failed: $StashOutput"
        }
        Log-Message "Stash réussi."
        $StashApplied = $true
    } Catch {
        Log-Message "Échec du stash. Annulation de la synchronisation. Message : $($_.Exception.Message)" "ERREUR"
        Exit 1 # Sortie avec erreur
    }
} else {
    $StashApplied = $false
}

# Étape 2: Mise à Jour du Dépôt Local (git pull)
Log-Message "Exécution de git pull..."
Try {
    $PullOutput = (& git pull origin main 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "Git pull failed: $PullOutput"
    }
    Log-Message "Git pull réussi."
} Catch {
    $ErrorMessage = $_.Exception.Message
    if ($ErrorMessage -like "*merge conflict*") {
        Log-Message "Conflit de fusion détecté. Annulation de la fusion..." "ALERTE"
        & git merge --abort
        $ConflictLogFile = Join-Path $ConflictLogDir "sync_conflicts_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
        Add-Content -Path $ConflictLogFile -Value "--- Conflit Git détecté lors du pull - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ---"
        Add-Content -Path $ConflictLogFile -Value "Dépôt : $RepoPath"
        Add-Content -Path $ConflictLogFile -Value "Branche : main"
        Add-Content -Path $ConflictLogFile -Value "Statut avant abort :"
        (& git status 2>&1) | Out-String | Add-Content -Path $ConflictLogFile
        Add-Content -Path $ConflictLogFile -Value "--- FIN DU CONFLIT ---"
        Log-Message "Conflit de fusion annulé. Voir $($ConflictLogFile) pour les détails. Synchronisation interrompue." "ERREUR"
    } else {
        Log-Message "Échec du git pull. Message : $($ErrorMessage). Annulation de la synchronisation." "ERREUR"
    }
    Exit 1 # Sortie avec erreur
}

# Étape 3 & 4: Analyse des Nouveautés et Exécution des Opérations de Synchronisation
Log-Message "Analyse des nouveautés et synchronisation des fichiers..."

$FilesToSync = @(
    "roo-config/settings/settings.json",
    "roo-config/settings/servers.json",
    "roo-config/settings/modes.json",
    "roo-config/escalation-test-config.json",
    "roo-config/qwen3-profiles/qwen3-parameters.json",
    "roo-config/analyze-test-results.ps1",
    "roo-config/apply-escalation-test-config.ps1",
    "roo-config/create-profile.ps1",
    "roo-config/deploy-profile-modes.ps1",
    "roo-config/maintenance-routine.ps1",
    "roo-config/maintenance-workflow.ps1",
    "roo-config/test-escalation-scenarios.ps1",
    "roo-config/deployment-scripts/create-clean-modes.ps1",
    "roo-config/deployment-scripts/deploy-guide-interactif.ps1",
    "roo-config/deployment-scripts/deploy-modes-ascii.ps1",
    "roo-config/deployment-scripts/deploy-modes-enhanced.ps1",
    "roo-config/deployment-scripts/deploy-modes-extreme.ps1",
    "roo-config/deployment-scripts/deploy-modes-final.ps1",
    "roo-config/deployment-scripts/deploy-modes-fixed.ps1",
    "roo-config/deployment-scripts/deploy-modes-improved.ps1",
    "roo-config/deployment-scripts/deploy-modes-minimal.ps1",
    "roo-config/deployment-scripts/deploy-modes-simple-complex.ps1",
    "roo-config/deployment-scripts/deploy-modes-simple.ps1",
    "roo-config/deployment-scripts/deploy-modes-solution.ps1",
    "roo-config/deployment-scripts/deploy-modes-ultra-simple.ps1",
    "roo-config/deployment-scripts/deploy-modes.ps1",
    "roo-config/deployment-scripts/force-deploy-with-encoding-fix.ps1",
    "roo-config/deployment-scripts/simple-deploy.ps1",
    "roo-config/diagnostic-scripts/check-deployed-encoding.ps1",
    "roo-config/diagnostic-scripts/diagnostic-rapide-encodage.ps1",
    "roo-config/diagnostic-scripts/encoding-diagnostic.ps1",
    "roo-config/diagnostic-scripts/verify-deployed-modes.ps1",
    "roo-config/encoding-scripts/fix-encoding-advanced.ps1",
    "roo-config/encoding-scripts/fix-encoding-ascii.ps1",
    "roo-config/encoding-scripts/fix-encoding-complete.ps1",
    "roo-config/encoding-scripts/fix-encoding-direct.ps1",
    "roo-config/encoding-scripts/fix-encoding-extreme.ps1",
    "roo-config/encoding-scripts/fix-encoding-final.ps1",
    "roo-config/encoding-scripts/fix-encoding-improved.ps1",
    "roo-config/encoding-scripts/fix-encoding-minimal.ps1",
    "roo-config/encoding-scripts/fix-encoding-regex.ps1",
    "roo-config/encoding-scripts/fix-encoding-simple-final.ps1",
    "roo-config/encoding-scripts/fix-encoding-simple.ps1",
    "roo-config/encoding-scripts/fix-encoding-ultra-simple.ps1",
    "roo-config/encoding-scripts/fix-encoding.ps1",
    "roo-config/encoding-scripts/fix-source-encoding.ps1",
    "roo-config/settings/deploy-settings.ps1",
    "roo-config/README-campagne-tests-escalade.md",
    "roo-config/README-profile-modes.md",
    "roo-config/README.md",
    "roo-config/REDIRECTION.md",
    "roo-config/backups/README.md",
    "roo-config/config-templates/README.md",
    "roo-config/deployment-scripts/README.md",
    "roo-config/diagnostic-scripts/README.md",
    "roo-config/docs/guide-import-export.md",
    "roo-config/docs/README.md",
    "roo-config/docs/solution-modes-simple-complex.md",
    "roo-config/encoding-scripts/README.md",
    "roo-config/qwen3-profiles/README.md",
    "roo-config/scheduler/Guide_Edition_Directe_Configurations_Roo_Scheduler.md",
    "roo-config/scheduler/Guide_Installation_Roo_Scheduler.md",
    "roo-config/settings/README.md",
    "roo-modes/configs/modes.json",
    "roo-modes/configs/new-roomodes.json",
    "roo-modes/configs/standard-modes.json",
    "roo-modes/configs/vscode-custom-modes.json",
    "roo-modes/n5/configs/architect-large-optimized-v2.json",
    "roo-modes/n5/configs/architect-large-optimized.json",
    "roo-modes/n5/configs/architect-large-original.json",
    "roo-modes/n5/configs/architect-large.json",
    "roo-modes/n5/configs/architect-medium.json",
    "roo-modes/n5/configs/ask-large.json",
    "roo-modes/n5/configs/ask-medium.json",
    "roo-modes/n5/configs/custom-n5-modes.json",
    "roo-modes/n5/configs/debug-large.json",
    "roo-modes/n5/configs/debug-medium.json",
    "roo-modes/n5/configs/large-modes.json",
    "roo-modes/n5/configs/medium-modes-fixed.json",
    "roo-modes/n5/configs/medium-modes.json",
    "roo-modes/n5/configs/micro-modes.json",
    "roo-modes/n5/configs/mini-modes-fixed.json",
    "roo-modes/n5/configs/mini-modes.json",
    "roo-modes/n5/configs/n5-modes-roo-compatible-local.json",
    "roo-modes/n5/configs/n5-modes-roo-compatible-modified.json",
    "roo-modes/n5/configs/n5-modes-roo-compatible.json",
    "roo-modes/n5/configs/oracle-modes-fixed.json",
    "roo-modes/n5/configs/oracle-modes.json",
    "roo-modes/n5/configs/orchestrator-large.json",
    "roo-modes/n5/configs/orchestrator-medium.json",
    "roo-modes/README.md",
    "roo-modes/custom/README.md",
    "roo-modes/custom/REDIRECTION.md",
    "roo-modes/custom/docs/architecture/architecture-concept.md",
    "roo-modes/custom/docs/criteres-decision/criteres-decision.md",
    "roo-modes/custom/docs/implementation/commits.md",
    "roo-modes/custom/docs/implementation/deploiement-autres-machines.md",
    "roo-modes/custom/docs/implementation/deploiement.md",
    "roo-modes/custom/docs/implementation/notes-pour-reprise.md",
    "roo-modes/custom/docs/implementation/script-deploy-local-endpoints.md",
    "roo-modes/custom/docs/optimisation/guide-installation-optimisations-mcp.md",
    "roo-modes/custom/docs/optimisation/recommandations-prompts.md",
    "roo-modes/custom/docs/optimisation/utilisation-optimisee-mcps.md",
    "roo-modes/custom/docs/structure-technique/README.md",
    "roo-modes/docs/directives-modes-custom.md",
    "roo-modes/docs/guide-import-export.md",
    "roo-modes/docs/guide-integration-modes-custom.md",
    "roo-modes/docs/guide-verrouillage-famille-modes.md",
    "roo-modes/docs/README-family-lock.md",
    "roo-modes/docs/reference-prompts-natifs.md",
    "roo-modes/docs/architecture/architecture-concept.md",
    "roo-modes/docs/criteres-decision/criteres-decision.md",
    "roo-modes/docs/implementation/commits.md",
    "roo-modes/docs/implementation/deploiement-autres-machines.md",
    "roo-modes/docs/implementation/deploiement.md",
    "roo-modes/docs/implementation/guide-installation-modes-personnalises.md",
    "roo-modes/docs/implementation/notes-pour-reprise.md",
    "roo-modes/docs/implementation/script-deploy-local-endpoints.md",
    "roo-modes/docs/optimisation/recommandations-prompts.md",
    "roo-modes/n5/CHANGELOG.md",
    "roo-modes/n5/rapport-final-deploiement.md",
    "roo-modes/n5/rapport-implementation.md",
    "roo-modes/n5/README-roo-compatible.md",
    "roo-modes/n5/README.md",
    "roo-modes/n5/docs/guide-migration-roo-compatible.md",
    "roo-modes/n5/docs/guide-migration.md",
    "roo-modes/n5/docs/guide-utilisation.md",
    "roo-modes/n5/tests/README.md",
    "roo-modes/optimized/ARCHIVE.md",
    "roo-modes/optimized/README.md",
    "roo-modes/optimized/REDIRECTION.md",
    "roo-modes/optimized/docs/architecture-concept.md",
    "roo-modes/optimized/docs/criteres-decision.md",
    "roo-modes/optimized/docs/notes-pour-reprise.md",
    "roo-modes/optimized/docs/recommandations-prompts.md"
)

$JsonFiles = @(
    "roo-config/settings/settings.json",
    "roo-config/settings/servers.json",
    "roo-config/settings/modes.json",
    "roo-config/escalation-test-config.json",
    "roo-config/qwen3-profiles/qwen3-parameters.json",
    "roo-modes/configs/modes.json",
    "roo-modes/configs/new-roomodes.json",
    "roo-modes/configs/standard-modes.json",
    "roo-modes/configs/vscode-custom-modes.json",
    "roo-modes/n5/configs/architect-large-optimized-v2.json",
    "roo-modes/n5/configs/architect-large-optimized.json",
    "roo-modes/n5/configs/architect-large-original.json",
    "roo-modes/n5/configs/architect-large.json",
    "roo-modes/n5/configs/architect-medium.json",
    "roo-modes/n5/configs/ask-large.json",
    "roo-modes/n5/configs/ask-medium.json",
    "roo-modes/n5/configs/custom-n5-modes.json",
    "roo-modes/n5/configs/debug-large.json",
    "roo-modes/n5/configs/debug-medium.json",
    "roo-modes/n5/configs/large-modes.json",
    "roo-modes/n5/configs/medium-modes-fixed.json",
    "roo-modes/n5/configs/medium-modes.json",
    "roo-modes/n5/configs/micro-modes.json",
    "roo-modes/n5/configs/mini-modes-fixed.json",
    "roo-modes/n5/configs/mini-modes.json",
    "roo-modes/n5/configs/n5-modes-roo-compatible-local.json",
    "roo-modes/n5/configs/n5-modes-roo-compatible-modified.json",
    "roo-modes/n5/configs/n5-modes-roo-compatible.json",
    "roo-modes/n5/configs/oracle-modes-fixed.json",
    "roo-modes/n5/configs/oracle-modes.json",
    "roo-modes/n5/configs/orchestrator-large.json",
    "roo-modes/n5/configs/orchestrator-medium.json"
)

foreach ($File in $FilesToSync) {
    $SourceFile = Join-Path $RepoPath $File
    $DestinationFile = Join-Path $RepoPath $File # Assumer que le dépôt est l'emplacement actif

    if (Test-Path $SourceFile) {
        Try {
            Copy-Item -Path $SourceFile -Destination $DestinationFile -Force -ErrorAction Stop
            Log-Message "Synchronisé : $($File)"
        } Catch {
            Log-Message "Échec de la synchronisation de $($File). Message : $($_.Exception.Message)" "ERREUR"
            Exit 1
        }
    }
}

# Étape 5: Vérification Post-Synchronisation
Log-Message "Vérification post-synchronisation..."

foreach ($JsonFile in $JsonFiles) {
    $FullPath = Join-Path $RepoPath $JsonFile
    if (Test-Path $FullPath) {
        Try {
            Get-Content -Raw $FullPath | ConvertFrom-Json | Out-Null
            Log-Message "Vérifié (JSON valide) : $($JsonFile)"
        } Catch {
            Log-Message "ERREUR: Fichier JSON invalide après synchronisation : $($JsonFile). Détails : $($_.Exception.Message)" "ERREUR"
            Exit 1
        }
    }
}

# Étape 6: Gestion des Commits de Correction (si nécessaire)
Log-Message "Vérification des modifications pour commit de correction..."
$PostSyncStatus = (& git status --porcelain 2>&1)
if ($PostSyncStatus) {
    Log-Message "Modifications détectées après synchronisation. Création d'un commit de correction..."
    & git add .
    $CommitOutput = (& git commit -m "SYNC: [Automated] Synchronisation des paramètres Roo post-pull" 2>&1)
    if ($LASTEXITCODE -ne 0) {
        Log-Message "Échec du commit. Message : $($CommitOutput)" "ERREUR"
        # Ne pas quitter ici, car la synchronisation des fichiers a été effectuée localement.
        # Le commit peut être retenté manuellement.
    } else {
        Log-Message "Commit de correction créé."
    }

    Log-Message "Tentative de push du commit de correction..."
    Try {
        $PushOutput = (& git push origin main 2>&1)
        if ($LASTEXITCODE -ne 0) {
            throw "Git push failed: $PushOutput"
        }
        Log-Message "Push du commit de correction réussi."
    } Catch {
        Log-Message "Échec du push du commit de correction. Message : $($_.Exception.Message)" "ERREUR"
        # Ne pas quitter ici, car la synchronisation des fichiers a été effectuée localement.
        # Le push peut être retenté manuellement.
    }
} else {
    Log-Message "Aucune modification à commiter après synchronisation."
}

# Étape 7: Nettoyage et Rapport Final
if ($StashApplied) {
    Log-Message "Restauration du stash..."
    Try {
        $StashPopOutput = (& git stash pop 2>&1)
        if ($LASTEXITCODE -ne 0) {
            throw "Git stash pop failed: $StashPopOutput"
        }
        Log-Message "Stash restauré avec succès."
    } Catch {
        Log-Message "Échec de la restauration du stash. Des conflits peuvent exister. Message : $($_.Exception.Message)" "ALERTE"
        # Documenter les conflits de stash pop si nécessaire
    }
}

Log-Message "Synchronisation de l'environnement Roo terminée."