# Fichier : d:/roo-extensions/sync_roo_environment.ps1

$RepoPath = "d:/roo-extensions"
$LogFile = "d:/roo-extensions/sync_log.txt"
$ConflictLogDir = "d:/roo-extensions/sync_conflicts"
$ErrorActionPreference = "Stop" # Stop on errors for better control

# Créer le répertoire de logs de conflits si inexistant
If (-not (Test-Path $ConflictLogDir)) {
    New-Item -ItemType Directory -Path $ConflictLogDir -ErrorAction SilentlyContinue | Out-Null
}

function Log-Message {
    Param (
        [string]$Message,
        [string]$Type = "INFO" # INFO, ALERTE, ERREUR
    )
    $LogEntry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $($Type): $($Message)"
    Add-Content -Path $LogFile -Value $LogEntry
    Write-Host $LogEntry # Also output to console for scheduler visibility
}

Set-Location $RepoPath

# --- Étape 1: Préparation et Vérification de l'Environnement Git ---
Log-Message "Étape 1: Préparation et Vérification de l'Environnement Git..."
$StashApplied = $false
Try {
    Log-Message "Vérification du statut Git avant pull..."
    $GitStatus = git status --porcelain
    if ($GitStatus) {
        Log-Message "Modifications locales détectées. Tentative de stash..." "ALERTE"
        git stash push -m "Automated stash before sync pull"
        Log-Message "Stash réussi."
        $StashApplied = $true
    } else {
        Log-Message "Aucune modification locale détectée avant le pull."
    }
} Catch {
    Log-Message "Échec lors de la vérification du statut Git ou du stash. Message : $($_.Exception.Message)" "ERREUR"
    Exit 1 # Sortie avec erreur
}

# --- Étape 2: Mise à Jour du Dépôt Local (git pull) ---
Log-Message "Étape 2: Mise à Jour du Dépôt Local (git pull)..."
Try {
    Log-Message "Exécution de git pull origin main..."
    # Capture HEAD avant le pull pour la comparaison ultérieure
    $HeadBeforePull = git rev-parse HEAD
    git pull origin main
    Log-Message "Git pull réussi."
} Catch {
    $ErrorMessage = $_.Exception.Message
    if ($ErrorMessage -like "*merge conflict*") {
        Log-Message "Conflit de fusion détecté. Annulation de la fusion..." "ALERTE"
        Try { git merge --abort } Catch { Log-Message "Échec de git merge --abort. Message: $($_.Exception.Message)" "ALERTE"}
        $ConflictLogFile = Join-Path $ConflictLogDir "sync_conflicts_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
        Add-Content -Path $ConflictLogFile -Value "--- Conflit Git détecté lors du pull - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ---"
        Add-Content -Path $ConflictLogFile -Value "Dépôt : $RepoPath"
        Add-Content -Path $ConflictLogFile -Value "Branche : main" # Assumer main, ajuster si nécessaire
        Add-Content -Path $ConflictLogFile -Value "Statut avant abort :"
        (git status) | Out-String | Add-Content -Path $ConflictLogFile
        Add-Content -Path $ConflictLogFile -Value "--- FIN DU CONFLIT ---"
        Log-Message "Conflit de fusion annulé. Voir $($ConflictLogFile) pour les détails. Synchronisation interrompue." "ERREUR"
    } else {
        Log-Message "Échec du git pull. Message : $($ErrorMessage). Annulation de la synchronisation." "ERREUR"
    }
    Exit 1 # Sortie avec erreur
}

# --- Étape 3: Analyse des Nouveautés et Identification des Fichiers à Synchroniser ---
Log-Message "Étape 3: Analyse des Nouveautés et Identification des Fichiers à Synchroniser..."

# Liste des fichiers et patterns à synchroniser (relatifs à $RepoPath)
$TargetFilesAndPatterns = @(
    "roo-config/settings/settings.json",
    "roo-config/settings/servers.json",
    "roo-config/settings/modes.json",
    "roo-config/escalation-test-config.json",
    "roo-config/qwen3-profiles/qwen3-parameters.json",
    "roo-modes/configs/modes.json",
    "roo-modes/configs/new-roomodes.json",
    "roo-modes/configs/standard-modes.json",
    "roo-modes/configs/vscode-custom-modes.json"
)

# Ajouter les .ps1 sous roo-config (récursif)
Get-ChildItem -Path (Join-Path $RepoPath "roo-config") -Filter "*.ps1" -Recurse | ForEach-Object {
    $TargetFilesAndPatterns += $_.FullName.Substring($RepoPath.Length + 1)
}

# Ajouter les .json sous roo-modes/n5/configs/ (récursif)
Get-ChildItem -Path (Join-Path $RepoPath "roo-modes/n5/configs") -Filter "*.json" -Recurse | ForEach-Object {
    $TargetFilesAndPatterns += $_.FullName.Substring($RepoPath.Length + 1)
}

# Ajouter les .md sous roo-config/ (récursif)
Get-ChildItem -Path (Join-Path $RepoPath "roo-config") -Filter "*.md" -Recurse | ForEach-Object {
    $TargetFilesAndPatterns += $_.FullName.Substring($RepoPath.Length + 1)
}

# Ajouter les .md sous roo-modes/ (récursif)
Get-ChildItem -Path (Join-Path $RepoPath "roo-modes") -Filter "*.md" -Recurse | ForEach-Object {
    $TargetFilesAndPatterns += $_.FullName.Substring($RepoPath.Length + 1)
}

# Rendre la liste unique
$UniqueTargetFiles = $TargetFilesAndPatterns | Sort-Object -Unique

Log-Message "Liste des fichiers cibles potentiels construite."

$FilesModifiedByPull = @()
Try {
    Log-Message "Détection des fichiers modifiés par le pull (HEAD vs HEAD@{1})..."
    if ($HeadBeforePull) {
        $FilesModifiedByPull = git diff --name-only $HeadBeforePull HEAD | ForEach-Object { $_ -replace '/', '\' } # Normaliser les slashes pour Windows
    } else {
        Log-Message "Impossible de déterminer HEAD avant le pull, synchronisation de tous les fichiers cibles." "ALERTE"
        # En cas d'échec de la détection (ex: premier pull), on pourrait choisir de synchroniser tous les $UniqueTargetFiles
        # Pour l'instant, on continue avec une liste vide, ce qui signifie que seuls les fichiers explicitement listés et existants seront copiés.
        # Ou, pour être plus sûr, on peut forcer la synchronisation de tous les fichiers cibles.
        # $FilesModifiedByPull = $UniqueTargetFiles # Décommentez pour synchroniser tous les fichiers cibles si diff échoue
    }
    Log-Message "Fichiers modifiés par le pull : $($FilesModifiedByPull -join ', ')"
} Catch {
    Log-Message "Erreur lors de la détection des fichiers modifiés par git diff. Message : $($_.Exception.Message)" "ALERTE"
    # Continuer, mais la synchronisation pourrait ne pas être précise.
}

$FilesToActuallySync = @()
if ($FilesModifiedByPull.Count -gt 0) {
    foreach ($modifiedFile in $FilesModifiedByPull) {
        if ($UniqueTargetFiles -contains $modifiedFile) {
            $FilesToActuallySync += $modifiedFile
        }
    }
} else {
    # Si git diff n'a rien retourné ou a échoué, on se rabat sur une copie de tous les fichiers cibles existants
    # Ceci est une mesure de sécurité, mais peut être affiné.
    Log-Message "Aucun fichier spécifiquement modifié par le pull détecté ou diff échoué. Vérification de tous les fichiers cibles pour synchronisation." "ALERTE"
    foreach ($targetFile in $UniqueTargetFiles) {
        if (Test-Path (Join-Path $RepoPath $targetFile)) {
            $FilesToActuallySync += $targetFile
        }
    }
}
$FilesToActuallySync = $FilesToActuallySync | Sort-Object -Unique
Log-Message "Fichiers identifiés pour synchronisation réelle : $($FilesToActuallySync -join ', ')"


# --- Étape 4: Exécution des Opérations de Synchronisation ---
Log-Message "Étape 4: Exécution des Opérations de Synchronisation..."
$SyncedJsonFiles = @()

if ($FilesToActuallySync.Count -eq 0) {
    Log-Message "Aucun fichier à synchroniser cette fois-ci."
}

foreach ($FileRelPath in $FilesToActuallySync) {
    $SourceFile = Join-Path $RepoPath $FileRelPath
    $DestinationFile = Join-Path $RepoPath $FileRelPath # Assumer que le dépôt est l'emplacement actif

    if (Test-Path $SourceFile) {
        Try {
            Copy-Item -Path $SourceFile -Destination $DestinationFile -Force
            Log-Message "Synchronisé : $($FileRelPath)"
            if ($FileRelPath.EndsWith(".json")) {
                $SyncedJsonFiles += $DestinationFile
            }
        } Catch {
            Log-Message "Échec de la synchronisation de $($FileRelPath). Message : $($_.Exception.Message)" "ERREUR"
            # Selon la criticité, on pourrait vouloir sortir ici (Exit 1)
        }
    } else {
        Log-Message "Fichier source non trouvé pour la synchronisation (peut avoir été supprimé par le pull) : $($SourceFile)" "ALERTE"
    }
}

# --- Étape 5: Vérification Post-Synchronisation ---
Log-Message "Étape 5: Vérification Post-Synchronisation..."

# Vérification des fichiers JSON synchronisés
if ($SyncedJsonFiles.Count -gt 0) {
    Log-Message "Vérification des fichiers JSON synchronisés..."
    foreach ($JsonFileFullPath in $SyncedJsonFiles) {
        if (Test-Path $JsonFileFullPath) {
            Try {
                Get-Content -Raw $JsonFileFullPath | ConvertFrom-Json | Out-Null
                Log-Message "Vérifié (JSON valide) : $($JsonFileFullPath.Substring($RepoPath.Length + 1))"
            } Catch {
                Log-Message "Fichier JSON invalide après synchronisation : $($JsonFileFullPath.Substring($RepoPath.Length + 1)). Détails : $($_.Exception.Message)" "ERREUR"
                Exit 1 # Fichier JSON critique invalide
            }
        }
    }
} else {
    Log-Message "Aucun fichier JSON n'a été synchronisé, pas de vérification JSON nécessaire."
}

# Vérification de l'existence des fichiers clés
$CriticalFiles = @(
    "roo-config/settings/settings.json",
    "roo-modes/configs/modes.json"
    # Ajoutez d'autres fichiers critiques ici si nécessaire
)
Log-Message "Vérification de l'existence des fichiers critiques..."
foreach ($CriticalFileRelPath in $CriticalFiles) {
    $FullPath = Join-Path $RepoPath $CriticalFileRelPath
    if (-not (Test-Path $FullPath)) {
        Log-Message "Fichier critique manquant après synchronisation : $($CriticalFileRelPath)" "ERREUR"
        Exit 1 # Fichier critique manquant
    } else {
        Log-Message "Fichier critique présent : $($CriticalFileRelPath)"
    }
}

# --- Étape 6: Gestion des Commits de Correction (si nécessaire) ---
Log-Message "Étape 6: Gestion des Commits de Correction..."
Try {
    $PostSyncStatus = git status --porcelain
    if ($PostSyncStatus) {
        Log-Message "Modifications détectées après synchronisation (ex: logs). Création d'un commit de correction..." "ALERTE"
        git add . # Ajoute tous les changements, y compris les logs. Peut être affiné.
        git commit -m "SYNC: [Automated] Mise à jour post-synchronisation (logs, etc.)"
        Log-Message "Commit de correction créé."

        Log-Message "Tentative de push du commit de correction..."
        git push origin main
        Log-Message "Push du commit de correction réussi."
    } else {
        Log-Message "Aucune modification à commiter après synchronisation."
    }
} Catch {
    Log-Message "Échec lors de la gestion des commits de correction ou du push. Message : $($_.Exception.Message)" "ERREUR"
    # Ne pas quitter ici, car la synchronisation des fichiers a été effectuée localement.
    # Le push peut être retenté manuellement.
}

# --- Étape 7: Nettoyage et Rapport Final ---
Log-Message "Étape 7: Nettoyage et Rapport Final..."
if ($StashApplied) {
    Log-Message "Restauration du stash..."
    Try {
        git stash pop
        Log-Message "Stash restauré avec succès."
    } Catch {
        Log-Message "Échec de la restauration du stash. Des conflits peuvent exister. Message : $($_.Exception.Message). Résolution manuelle requise." "ALERTE"
        # Documenter les conflits de stash pop si nécessaire dans un fichier de conflit dédié
        $ConflictLogFile = Join-Path $ConflictLogDir "stash_pop_conflicts_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
        Add-Content -Path $ConflictLogFile -Value "--- Conflit Git détecté lors du stash pop - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ---"
        Add-Content -Path $ConflictLogFile -Value "$($_.Exception.Message)"
        (git status) | Out-String | Add-Content -Path $ConflictLogFile
        Add-Content -Path $ConflictLogFile -Value "--- FIN DU CONFLIT STASH POP ---"
        Log-Message "Détails du conflit de stash pop enregistrés dans $ConflictLogFile" "ALERTE"
    }
}

Log-Message "Synchronisation de l'environnement Roo terminée."
Exit 0