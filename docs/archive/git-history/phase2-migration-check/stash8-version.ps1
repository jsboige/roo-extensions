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
    Log-Message "Git pull réussi. L'environnement local est maintenant synchronisé avec le dépôt."
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
# Ces étapes sont maintenant implicitement gérées par le 'git pull' si le dépôt est l'emplacement actif.
# La section de copie de fichiers est supprimée.
Log-Message "Le 'git pull' a mis à jour les fichiers directement dans le répertoire de travail."

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

# Étape 5: Vérification Post-Synchronisation
Log-Message "Vérification post-synchronisation (validation JSON)..."

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
Log-Message "Vérification des modifications pour commit de correction (ex: logs)..."
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