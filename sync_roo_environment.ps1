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
$GitStatus = git status --porcelain
if ($GitStatus) {
    Log-Message "Modifications locales détectées. Tentative de stash..." "ALERTE"
    Try {
        git stash push -m "Automated stash before sync pull" -ErrorAction Stop
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
    git pull origin main -ErrorAction Stop
    Log-Message "Git pull réussi."
} Catch {
    $ErrorMessage = $_.Exception.Message
    if ($ErrorMessage -like "*merge conflict*") {
        Log-Message "Conflit de fusion détecté. Annulation de la fusion..." "ALERTE"
        git merge --abort
        $ConflictLogFile = Join-Path $ConflictLogDir "sync_conflicts_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
        Add-Content -Path $ConflictLogFile -Value "--- Conflit Git détecté lors du pull - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ---"
        Add-Content -Path $ConflictLogFile -Value "Dépôt : $RepoPath"
        Add-Content -Path $ConflictLogFile -Value "Branche : main"
        Add-Content -Path $ConflictLogFile -Value "Statut avant abort :"
        (git status) | Out-String | Add-Content -Path $ConflictLogFile
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
    "roo-config/maintenance-routine.ps1",
    "roo-config/maintenance-workflow.ps1",
    "roo-config/README-campagne-tests-escalade.md",
    "roo-config/README-profile-modes.md",
    "roo-config/README.md",
    "roo-config/REDIRECTION.md",
    "roo-config/test-escalation-scenarios.ps1",
    "roo-modes/configs/modes.json",
    "roo-modes/configs/new-roomodes.json",
    "roo-modes/configs/standard-modes.json",
    "roo-modes/configs/vscode-custom-modes.json"
)

# Ajouter dynamiquement les fichiers .json de roo-modes/n5/configs/
Get-ChildItem -Path (Join-Path $RepoPath "roo-modes/n5/configs/") -Filter *.json | ForEach-Object {
    $FilesToSync += "roo-modes/n5/configs/$($_.Name)"
}

# Ajouter dynamiquement les fichiers .md de roo-config et roo-modes
Get-ChildItem -Path (Join-Path $RepoPath "roo-config") -Recurse -Filter *.md | ForEach-Object {
    $FilesToSync += $_.FullName.Substring($RepoPath.Length + 1)
}
Get-ChildItem -Path (Join-Path $RepoPath "roo-modes") -Recurse -Filter *.md | ForEach-Object {
    $FilesToSync += $_.FullName.Substring($RepoPath.Length + 1)
}

# Dédoublonner la liste
$FilesToSync = $FilesToSync | Sort-Object -Unique


# Identifier les fichiers réellement modifiés par le pull pour ne copier que ceux-là
$ChangedFiles = git diff --name-only HEAD@{1} HEAD
$FilesToActuallyCopy = @()

foreach ($FileRelPath in $FilesToSync) {
    if ($ChangedFiles -contains $FileRelPath) {
        $FilesToActuallyCopy += $FileRelPath
    }
}

if ($FilesToActuallyCopy.Count -eq 0) {
    Log-Message "Aucun fichier de configuration pertinent n'a été modifié par le git pull. Aucune copie nécessaire."
} else {
    Log-Message "Fichiers pertinents modifiés par git pull et à synchroniser : $($FilesToActuallyCopy -join ', ')"
}

foreach ($FileRelPath in $FilesToActuallyCopy) {
    $SourceFile = Join-Path $RepoPath $FileRelPath
    $DestinationFile = Join-Path $RepoPath $FileRelPath # Assumer que le dépôt est l'emplacement actif

    if (Test-Path $SourceFile) {
        Try {
            Copy-Item -Path $SourceFile -Destination $DestinationFile -Force -ErrorAction Stop
            Log-Message "Synchronisé : $($FileRelPath)"
        } Catch {
            Log-Message "Échec de la synchronisation de $($FileRelPath). Message : $($_.Exception.Message)" "ERREUR"
            # Envisager de ne pas quitter sur une seule erreur de copie pour tenter les autres
        }
    } else {
        Log-Message "Fichier source non trouvé pour la copie : $SourceFile (listé dans FilesToSync mais non modifié par pull ou inexistant ?)" "ALERTE"
    }
}

# Étape 5: Vérification Post-Synchronisation
Log-Message "Vérification post-synchronisation..."
$JsonFilesToCheck = @()
# Filtrer pour ne vérifier que les fichiers JSON qui ont été copiés
foreach ($FileRelPath in $FilesToActuallyCopy) {
    if ($FileRelPath.EndsWith(".json")) {
        $JsonFilesToCheck += $FileRelPath
    }
}

if ($JsonFilesToCheck.Count -gt 0) {
    Log-Message "Vérification des fichiers JSON suivants : $($JsonFilesToCheck -join ', ')"
    foreach ($JsonFileRelPath in $JsonFilesToCheck) {
        $FullPath = Join-Path $RepoPath $JsonFileRelPath
        if (Test-Path $FullPath) {
            Try {
                Get-Content -Raw $FullPath | ConvertFrom-Json | Out-Null
                Log-Message "Vérifié (JSON valide) : $($JsonFileRelPath)"
            } Catch {
                Log-Message "ERREUR: Fichier JSON invalide après synchronisation : $($JsonFileRelPath). Détails : $($_.Exception.Message)" "ERREUR"
                # Envisager de ne pas quitter sur une seule erreur de validation pour tenter les autres
            }
        }
    }
} else {
    Log-Message "Aucun fichier JSON n'a été copié, pas de vérification JSON post-copie nécessaire."
}


# Étape 6: Gestion des Commits de Correction (si nécessaire)
Log-Message "Vérification des modifications pour commit de correction (logs, etc.)..."
# Exclure les fichiers du répertoire sync_conflicts des commits automatiques
git update-index --assume-unchanged (Join-Path $RepoPath "sync_conflicts/*")

$PostSyncStatus = git status --porcelain
# Filtrer pour ignorer les fichiers dans sync_conflicts
$ChangesToCommit = $PostSyncStatus | Where-Object { $_ -notlike "sync_conflicts/*" }

if ($ChangesToCommit) {
    Log-Message "Modifications détectées après synchronisation (hors logs de conflits). Création d'un commit..."
    git add . # Ajoute tout ce qui est suivi et modifié, sauf si ignoré par .gitignore ou assume-unchanged
    git commit -m "SYNC: [Automated] Mise à jour des logs et potentiels ajustements post-synchronisation Roo"
    Log-Message "Commit de correction créé."

    Log-Message "Tentative de push du commit de correction..."
    Try {
        git push origin main -ErrorAction Stop
        Log-Message "Push du commit de correction réussi."
    } Catch {
        Log-Message "Échec du push du commit de correction. Message : $($_.Exception.Message)" "ERREUR"
    }
} else {
    Log-Message "Aucune modification (hors logs de conflits) à commiter après synchronisation."
}
# Réactiver le suivi des fichiers de log de conflits pour les opérations manuelles futures
git update-index --no-assume-unchanged (Join-Path $RepoPath "sync_conflicts/*")


# Étape 7: Nettoyage et Rapport Final
if ($StashApplied) {
    Log-Message "Restauration du stash..."
    Try {
        git stash pop -ErrorAction Stop
        Log-Message "Stash restauré avec succès."
    } Catch {
        Log-Message "Échec de la restauration du stash. Des conflits peuvent exister. Message : $($_.Exception.Message)" "ALERTE"
    }
}

Log-Message "Synchronisation de l'environnement Roo terminée."