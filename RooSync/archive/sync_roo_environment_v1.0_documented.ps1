<#
.SYNOPSIS
    Script de synchronisation de l'environnement Roo.
.DESCRIPTION
    Ce script automatise la mise à jour de l'environnement de travail Roo depuis un dépôt Git.
    Il gère les modifications locales, la mise à jour via 'git pull', la synchronisation
    de fichiers de configuration critiques, et la journalisation des opérations.
    Conçu pour une exécution non-interactive par un planificateur de tâches.
.NOTES
    Version: 1.0
    Auteur: Roo
    Date: 2025-07-27
#>

#--------------------------------------------------------------------------
# Configuration
#--------------------------------------------------------------------------

# Répertoire de travail principal de Roo
$Workspace = "d:/roo-extensions"

# Fichier de log principal
$LogFile = Join-Path -Path $Workspace -ChildPath "sync_log.txt"

# Répertoire pour les logs de conflits
$ConflictLogDir = Join-Path -Path $Workspace -ChildPath "sync_conflicts"

# Fichiers à synchroniser (Source depuis le repo -> Destination active)
# Cette table de hachage définit les règles de copie.
$FilesToSync = @{
    # Exemple: Copier tous les modes de roo-config vers le répertoire roo-modes
    "roo-config/modes/*.json" = "roo-modes/";
    # Exemple: Copier tous les profils de roo-config vers le répertoire profiles
    "roo-config/profiles/*.json" = "profiles/";
    # Exemple: Copier un fichier de documentation spécifique
    "docs/design/01-sync-manager-specification.md" = "docs/design/active-specification.md";
}

#--------------------------------------------------------------------------
# Fonctions
#--------------------------------------------------------------------------

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR", "FATAL")]
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] - $Message"
    
    # Écrit dans le fichier de log
    Add-Content -Path $LogFile -Value $logEntry
    
    # Affiche dans la console (utile pour le débogage manuel)
    Write-Host $logEntry
}

#--------------------------------------------------------------------------
# Exécution Principale
#--------------------------------------------------------------------------

# --- 1. Initialisation ---
Write-Log -Message "Début du script de synchronisation de l'environnement Roo."

# Vérification et création du répertoire de logs de conflits
if (-not (Test-Path -Path $ConflictLogDir)) {
    try {
        New-Item -Path $ConflictLogDir -ItemType Directory -ErrorAction Stop | Out-Null
        Write-Log -Message "Répertoire des logs de conflits créé : $ConflictLogDir"
    } catch {
        Write-Log -Message "Impossible de créer le répertoire des logs de conflits : $($_.Exception.Message)" -Level FATAL
        exit 1
    }
}

# Se placer dans le répertoire de travail
try {
    Set-Location -Path $Workspace -ErrorAction Stop
    Write-Log -Message "Déplacement vers le répertoire de travail : $Workspace"
} catch {
    Write-Log -Message "Impossible de se déplacer vers le répertoire de travail '$Workspace'. Erreur : $($_.Exception.Message)" -Level FATAL
    exit 1
}

# --- 2. Préparation et Vérification Git ---
$stashApplied = $false
Write-Log -Message "Vérification du statut du dépôt Git..."
$gitStatus = git status --porcelain
if ($gitStatus) {
    Write-Log -Message "Modifications locales détectées. Mise de côté (stash)..." -Level WARN
    $stashName = "Roo-Sync-Stash-$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    git stash push -m $stashName
    if ($LASTEXITCODE -eq 0) {
        $stashApplied = $true
        Write-Log -Message "Modifications mises de côté avec le nom : $stashName"
    } else {
        Write-Log -Message "Échec de la mise de côté (git stash)." -Level ERROR
        # On continue quand même, le pull échouera probablement proprement.
    }
} else {
    Write-Log -Message "Le répertoire de travail est propre. Aucune modification locale."
}

# --- 3. Mise à Jour depuis le Dépôt ---
Write-Log -Message "Tentative de mise à jour depuis le dépôt distant (git pull)..."
$pullOutput = git pull 2>&1
if ($LASTEXITCODE -ne 0) {
    if ($pullOutput -match "Merge conflict") {
        $conflictTimestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $conflictFile = Join-Path -Path $ConflictLogDir -ChildPath "sync_conflict_$($conflictTimestamp).log"
        Write-Log -Message "CONFLIT DE FUSION DÉTECTÉ ! Annulation de la fusion." -Level FATAL
        $pullOutput | Out-File -FilePath $conflictFile -Encoding utf8
        Write-Log -Message "Les détails du conflit ont été enregistrés dans : $conflictFile" -Level FATAL
        
        git merge --abort
        Write-Log -Message "La fusion a été annulée (git merge --abort)." -Level FATAL
        
        # Si un stash a été appliqué, on essaie de le restaurer
        if ($stashApplied) {
            Write-Log -Message "Tentative de restauration du stash..."
            git stash pop
        }
        exit 1
    } else {
        Write-Log -Message "Erreur lors de l'exécution de 'git pull'. Sortie : $pullOutput" -Level FATAL
        if ($stashApplied) {
            Write-Log -Message "Tentative de restauration du stash..."
            git stash pop
        }
        exit 1
    }
}
Write-Log -Message "'git pull' exécuté avec succès."

# --- 4. Synchronisation des Fichiers ---
Write-Log -Message "Début de la synchronisation des fichiers de configuration et de documentation."
$syncErrors = 0
foreach ($sourcePattern in $FilesToSync.Keys) {
    $destination = $FilesToSync[$sourcePattern]
    $sourceFiles = Get-Item -Path $sourcePattern -ErrorAction SilentlyContinue
    
    if (-not $sourceFiles) {
        Write-Log -Message "Aucun fichier source trouvé pour le motif '$sourcePattern'." -Level WARN
        continue
    }

    foreach ($sourceFile in $sourceFiles) {
        $destPath = if ((Test-Path -Path $destination -PathType Container) -or ($destination.EndsWith('/') -or $destination.EndsWith('\'))) {
            Join-Path -Path $destination -ChildPath $sourceFile.Name
        } else {
            $destination
        }

        try {
            # S'assurer que le répertoire de destination existe
            $destDir = Split-Path -Path $destPath -Parent
            if (-not (Test-Path -Path $destDir)) {
                New-Item -Path $destDir -ItemType Directory -Force | Out-Null
            }
            
            Copy-Item -Path $sourceFile.FullName -Destination $destPath -Force -ErrorAction Stop
            Write-Log -Message "Copié : '$($sourceFile.FullName)' -> '$destPath'"
        } catch {
            Write-Log -Message "Échec de la copie de '$($sourceFile.FullName)' vers '$destPath'. Erreur : $($_.Exception.Message)" -Level ERROR
            $syncErrors++
        }
    }
}

if ($syncErrors -gt 0) {
    Write-Log -Message "La synchronisation des fichiers s'est terminée avec $syncErrors erreur(s)." -Level ERROR
} else {
    Write-Log -Message "Synchronisation des fichiers terminée avec succès."
}

# --- 5. Vérification Post-Synchronisation ---
Write-Log -Message "Vérification des fichiers après synchronisation."
$validationErrors = 0
foreach ($sourcePattern in $FilesToSync.Keys) {
    $destination = $FilesToSync[$sourcePattern]
    $sourceFiles = Get-Item -Path $sourcePattern -ErrorAction SilentlyContinue
    if (-not $sourceFiles) { continue }

    foreach ($sourceFile in $sourceFiles) {
        $destPath = if ((Test-Path -Path $destination -PathType Container) -or ($destination.EndsWith('/') -or $destination.EndsWith('\'))) {
            Join-Path -Path $destination -ChildPath $sourceFile.Name
        } else {
            $destination
        }

        if (-not (Test-Path -Path $destPath)) {
            Write-Log -Message "Fichier de destination manquant : '$destPath'" -Level ERROR
            $validationErrors++
            continue
        }

        if ($destPath.EndsWith(".json")) {
            try {
                Get-Content -Path $destPath | Test-Json -ErrorAction Stop
                Write-Log -Message "Validation JSON réussie pour : '$destPath'"
            } catch {
                Write-Log -Message "Validation JSON échouée pour '$destPath'. Erreur : $($_.Exception.Message)" -Level ERROR
                $validationErrors++
            }
        }
    }
}

if ($validationErrors -gt 0) {
    Write-Log -Message "La vérification post-synchronisation a révélé $validationErrors erreur(s)." -Level ERROR
} else {
    Write-Log -Message "Vérification post-synchronisation réussie."
}


# --- 6. Commit de Correction (si des logs ou autres fichiers ont été modifiés) ---
Write-Log -Message "Vérification des modifications à commiter (fichiers de log, etc.)."
# Ajoute le fichier de log aux changements à suivre, s'il n'est pas dans .gitignore
git add $LogFile
$gitStatusAfterSync = git status --porcelain
if ($gitStatusAfterSync) {
    Write-Log -Message "Des modifications ont été générées par le processus de synchronisation. Tentative de commit..." -Level WARN
    git commit -m "feat(sync): Mise à jour automatique post-synchronisation" -m "Le script de synchronisation a généré des modifications (ex: logs)."
    if ($LASTEXITCODE -eq 0) {
        Write-Log -Message "Commit de correction créé. Tentative de push..."
        git push
        if ($LASTEXITCODE -ne 0) {
            Write-Log -Message "Échec du 'git push' pour le commit de correction." -Level ERROR
        } else {
            Write-Log -Message "'git push' du commit de correction réussi."
        }
    } else {
        Write-Log -Message "Échec de la création du commit de correction." -Level ERROR
    }
} else {
    Write-Log -Message "Aucune modification à commiter après la synchronisation."
}

# --- 7. Nettoyage ---
if ($stashApplied) {
    Write-Log -Message "Restauration des modifications locales mises de côté (git stash pop)..."
    git stash pop
    if ($LASTEXITCODE -ne 0) {
        Write-Log -Message "Un conflit est survenu lors de la restauration du stash (git stash pop). Veuillez le résoudre manuellement." -Level ERROR
    } else {
        Write-Log -Message "Stash restauré avec succès."
    }
}

Write-Log -Message "Script de synchronisation de l'environnement Roo terminé."
exit 0