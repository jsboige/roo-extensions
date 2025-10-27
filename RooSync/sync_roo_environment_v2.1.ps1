<#
.SYNOPSIS
    Script de synchronisation de l'environnement Roo (Version 2.1 - Consolidée)

.DESCRIPTION
    Ce script automatise la mise à jour de l'environnement de travail Roo depuis un dépôt Git.
    Il gère les modifications locales, la mise à jour via 'git pull', la synchronisation
    de fichiers de configuration critiques, et la journalisation des opérations.
    
    Version 2.1 consolide les fonctionnalités robustes de la version RooSync/ (SHA tracking,
    vérification Git, patterns dynamiques) avec les améliorations de la version scheduler/
    (logging structuré, documentation complète, Test-Json).
    
    Conçu pour une exécution non-interactive par un planificateur de tâches.

.PARAMETER DryRun
    Mode simulation : affiche les opérations sans les exécuter

.NOTES
    Version:        2.1.0
    Auteur:         Roo
    Date:           2025-10-26
    Baseline:       Fusion RooSync/sync_roo_environment.ps1 + scheduler/sync_roo_environment.ps1
    Documentation:  docs/roosync/script-consolidation-report-20251026.md
    
.EXAMPLE
    .\sync_roo_environment_v2.1.ps1
    Exécution standard avec configuration par défaut
    
.EXAMPLE
    $env:ROO_SYNC_DRY_RUN = "true"; .\sync_roo_environment_v2.1.ps1
    Exécution en mode dry-run (simulation)
    
.EXAMPLE
    $env:ROO_EXTENSIONS_PATH = "C:\custom\path"; .\sync_roo_environment_v2.1.ps1
    Exécution avec chemin personnalisé
#>

[CmdletBinding()]
param(
    [switch]$DryRun = [bool]$env:ROO_SYNC_DRY_RUN
)

#--------------------------------------------------------------------------
# Configuration avec Variables d'Environnement
#--------------------------------------------------------------------------

# Répertoire de travail principal (support variable d'environnement)
$RepoPath = if ($env:ROO_EXTENSIONS_PATH) { 
    $env:ROO_EXTENSIONS_PATH 
} else { 
    "d:/roo-extensions" 
}

# Fichier de log principal
$LogFile = if ($env:ROO_SYNC_LOG) { 
    $env:ROO_SYNC_LOG 
} else { 
    Join-Path $RepoPath "sync_log.txt" 
}

# Répertoire pour les logs de conflits
$ConflictLogDir = Join-Path $RepoPath "sync_conflicts"

# Rotation des logs (jours)
$LogRetentionDays = if ($env:ROO_SYNC_LOG_RETENTION) {
    [int]$env:ROO_SYNC_LOG_RETENTION
} else {
    7
}

# Codes de sortie standardisés
$ExitCode = @{
    Success = 0
    GitError = 1
    JsonValidationError = 2
    EnvironmentError = 3
}

#--------------------------------------------------------------------------
# Fonction de Logging Structuré
#--------------------------------------------------------------------------

function Write-Log {
    <#
    .SYNOPSIS
        Écrit un message de log avec niveau et timestamp
    .PARAMETER Message
        Message à logger
    .PARAMETER Level
        Niveau de log : INFO, WARN, ERROR, FATAL
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("INFO", "WARN", "ERROR", "FATAL")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] - $Message"
    
    # Affichage console (avec couleur selon niveau)
    switch ($Level) {
        "INFO"  { Write-Host $logEntry -ForegroundColor White }
        "WARN"  { Write-Host $logEntry -ForegroundColor Yellow }
        "ERROR" { Write-Host $logEntry -ForegroundColor Red }
        "FATAL" { Write-Host $logEntry -ForegroundColor Magenta }
    }
    
    # Écriture dans le fichier de log (si pas en dry-run)
    if (-not $DryRun) {
        try {
            Add-Content -Path $LogFile -Value $logEntry -ErrorAction Stop
        } catch {
            Write-Host "[WARN] Impossible d'écrire dans le fichier de log : $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

#--------------------------------------------------------------------------
# Initialisation
#--------------------------------------------------------------------------

$startTime = Get-Date

Write-Log "═══════════════════════════════════════════════════════════════" -Level INFO
Write-Log "Début de la synchronisation de l'environnement Roo (v2.1)" -Level INFO
if ($DryRun) {
    Write-Log "MODE DRY-RUN : Aucune modification ne sera effectuée" -Level WARN
}
Write-Log "═══════════════════════════════════════════════════════════════" -Level INFO

# Rotation automatique des logs
if (-not $DryRun -and (Test-Path $LogFile)) {
    $logAge = (Get-Date) - (Get-Item $LogFile).LastWriteTime
    if ($logAge.Days -gt $LogRetentionDays) {
        $archiveLog = "$LogFile.$(Get-Date -Format 'yyyyMMdd')"
        try {
            Move-Item $LogFile $archiveLog -Force -ErrorAction Stop
            Write-Log "Log archivé : $archiveLog (ancien de $($logAge.Days) jours)" -Level INFO
        } catch {
            Write-Log "Échec de l'archivage du log : $($_.Exception.Message)" -Level WARN
        }
    }
}

# Création du répertoire de logs de conflits si inexistant
if (-not (Test-Path $ConflictLogDir)) {
    if ($DryRun) {
        Write-Log "[DRY-RUN] Création du répertoire : $ConflictLogDir" -Level INFO
    } else {
        try {
            New-Item -ItemType Directory -Path $ConflictLogDir -ErrorAction Stop | Out-Null
            Write-Log "Répertoire des logs de conflits créé : $ConflictLogDir" -Level INFO
        } catch {
            Write-Log "Impossible de créer le répertoire des logs de conflits : $($_.Exception.Message)" -Level FATAL
            exit $ExitCode.EnvironmentError
        }
    }
}

#--------------------------------------------------------------------------
# Vérification de l'Environnement Git
#--------------------------------------------------------------------------

Write-Log "Vérification de la disponibilité de la commande git..." -Level INFO
$GitPath = Get-Command git -ErrorAction SilentlyContinue

if (-not $GitPath) {
    Write-Log "ERREUR: La commande 'git' n'a pas été trouvée." -Level FATAL
    Write-Log "Veuillez installer Git depuis : https://git-scm.com/downloads" -Level FATAL
    Write-Log "Assurez-vous que Git est dans le PATH système." -Level FATAL
    exit $ExitCode.EnvironmentError
}

Write-Log "Commande 'git' trouvée : $($GitPath.Source)" -Level INFO

# Déplacement vers le répertoire de travail
if ($DryRun) {
    Write-Log "[DRY-RUN] Set-Location $RepoPath" -Level INFO
} else {
    try {
        Set-Location -Path $RepoPath -ErrorAction Stop
        Write-Log "Répertoire de travail actuel : $(Get-Location)" -Level INFO
    } catch {
        Write-Log "Impossible de se déplacer vers '$RepoPath'. Erreur : $($_.Exception.Message)" -Level FATAL
        exit $ExitCode.EnvironmentError
    }
}

#--------------------------------------------------------------------------
# Étape 1 : Préparation et Vérification Git (Stash)
#--------------------------------------------------------------------------

Write-Log "Vérification du statut Git avant pull..." -Level INFO

if ($DryRun) {
    Write-Log "[DRY-RUN] git status --porcelain" -Level INFO
    $GitStatus = @() # Simule repository propre
} else {
    $GitStatus = git status --porcelain
}

$StashApplied = $false

if ($GitStatus) {
    Write-Log "Modifications locales détectées. Tentative de stash..." -Level WARN
    
    if ($DryRun) {
        Write-Log "[DRY-RUN] git stash push -m 'Automated stash before sync pull'" -Level INFO
        $StashApplied = $false # Pas de vrai stash en dry-run
    } else {
        try {
            git stash push -m "Automated stash before sync pull v2.1" -ErrorAction Stop
            if ($LASTEXITCODE -eq 0) {
                Write-Log "Stash réussi." -Level INFO
                $StashApplied = $true
            } else {
                Write-Log "Échec du stash (code sortie : $LASTEXITCODE)." -Level ERROR
                exit $ExitCode.GitError
            }
        } catch {
            Write-Log "Échec du stash. Annulation de la synchronisation. Message : $($_.Exception.Message)" -Level FATAL
            exit $ExitCode.GitError
        }
    }
} else {
    Write-Log "Aucune modification locale détectée avant le stash." -Level INFO
}

#--------------------------------------------------------------------------
# Étape 2 : Mise à Jour du Dépôt Local (git pull avec SHA Tracking)
#--------------------------------------------------------------------------

Write-Log "Exécution de git pull origin main..." -Level INFO

# Récupérer le SHA HEAD actuel pour comparaison ultérieure
if ($DryRun) {
    Write-Log "[DRY-RUN] git rev-parse HEAD" -Level INFO
    $HeadBeforePull = "dry-run-sha-before"
    $HeadAfterPull = "dry-run-sha-after"
} else {
    try {
        $HeadBeforePull = git rev-parse HEAD
        if (-not $HeadBeforePull -or ($LASTEXITCODE -ne 0)) {
            Write-Log "Impossible de récupérer le SHA de HEAD avant pull." -Level FATAL
            if ($StashApplied) {
                Write-Log "Tentative de restauration du stash..." -Level WARN
                git stash pop -ErrorAction SilentlyContinue | Out-Null
            }
            exit $ExitCode.GitError
        }
        Write-Log "SHA HEAD avant pull : $HeadBeforePull" -Level INFO
    } catch {
        Write-Log "Erreur lors de la récupération du SHA HEAD : $($_.Exception.Message)" -Level FATAL
        exit $ExitCode.GitError
    }

    # Exécution du git pull
    try {
        $pullOutput = git pull origin main 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            # Détection des conflits de fusion
            if ($pullOutput -match "merge conflict" -or $pullOutput -match "CONFLICT") {
                $conflictTimestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                $conflictFile = Join-Path $ConflictLogDir "sync_conflict_pull_$conflictTimestamp.log"
                
                Write-Log "CONFLIT DE FUSION DÉTECTÉ ! Annulation de la fusion." -Level FATAL
                $pullOutput | Out-File -FilePath $conflictFile -Encoding utf8
                Write-Log "Détails du conflit enregistrés : $conflictFile" -Level FATAL
                
                git merge --abort
                Write-Log "La fusion a été annulée (git merge --abort)." -Level FATAL
                
                # Restauration du stash si appliqué
                if ($StashApplied) {
                    Write-Log "Tentative de restauration du stash..." -Level WARN
                    git stash pop -ErrorAction SilentlyContinue | Out-Null
                }
                exit $ExitCode.GitError
            } else {
                Write-Log "Erreur lors de 'git pull'. Sortie : $pullOutput" -Level FATAL
                if ($StashApplied) {
                    Write-Log "Tentative de restauration du stash..." -Level WARN
                    git stash pop -ErrorAction SilentlyContinue | Out-Null
                }
                exit $ExitCode.GitError
            }
        }
        
        Write-Log "Git pull réussi." -Level INFO
        
        # Récupérer le SHA HEAD après pull
        $HeadAfterPull = git rev-parse HEAD
        if (-not $HeadAfterPull -or ($LASTEXITCODE -ne 0)) {
            Write-Log "Impossible de récupérer le SHA de HEAD après pull." -Level FATAL
            if ($StashApplied) {
                git stash pop -ErrorAction SilentlyContinue | Out-Null
            }
            exit $ExitCode.GitError
        }
        Write-Log "SHA HEAD après pull : $HeadAfterPull" -Level INFO
        
        if ($HeadBeforePull -eq $HeadAfterPull) {
            Write-Log "Aucun changement détecté (HEAD identique)." -Level INFO
        } else {
            Write-Log "Changements détectés (HEAD modifié)." -Level INFO
        }
        
    } catch {
        $ErrorMessage = $_.Exception.Message
        Write-Log "Échec du git pull. Message : $ErrorMessage" -Level FATAL
        
        if ($StashApplied) {
            Write-Log "Tentative de restauration du stash..." -Level WARN
            git stash pop -ErrorAction SilentlyContinue | Out-Null
        }
        exit $ExitCode.GitError
    }
}

#--------------------------------------------------------------------------
# Étape 3 : Analyse des Nouveautés (Patterns Dynamiques + Filtrage git diff)
#--------------------------------------------------------------------------

Write-Log "Analyse des nouveautés et préparation pour la synchronisation/validation..." -Level INFO

# Liste initiale des fichiers spécifiques
$SpecificFiles = @(
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

# Patterns pour la collecte dynamique
$FilesToSyncPatterns = @{
    "roo-config" = @("*.ps1", "*.md")
    "roo-modes" = @("*.md")
    "roo-modes/n5/configs" = @("*.json")
}

$FilesToSyncList = [System.Collections.Generic.List[string]]::new()

Write-Log "Ajout des fichiers spécifiques à la liste de synchronisation..." -Level INFO
foreach ($sf in $SpecificFiles) {
    $normalizedSf = $sf -replace '\\', '/'
    if (-not $FilesToSyncList.Contains($normalizedSf)) {
        $FilesToSyncList.Add($normalizedSf)
        Write-Log "  Spécifique ajouté : $normalizedSf" -Level INFO
    }
}

Write-Log "Collecte des fichiers basés sur les patterns..." -Level INFO
foreach ($basePathPatternKey in $FilesToSyncPatterns.Keys) {
    $patternsForPath = $FilesToSyncPatterns[$basePathPatternKey]
    $fullBasePath = Join-Path $RepoPath $basePathPatternKey

    if (Test-Path $fullBasePath) {
        foreach ($pattern in $patternsForPath) {
            $isRecursive = ($pattern -eq "*.md")
            
            Write-Log "  Recherche de '$pattern' dans '$basePathPatternKey' (Récursif: $isRecursive)" -Level INFO
            Get-ChildItem -Path $fullBasePath -Filter $pattern -Recurse:$isRecursive -ErrorAction SilentlyContinue | ForEach-Object {
                $relativeFilePath = $_.FullName.Substring($RepoPath.Length).TrimStart('\/') -replace '\\', '/'
                if (-not $FilesToSyncList.Contains($relativeFilePath)) {
                    $FilesToSyncList.Add($relativeFilePath)
                }
            }
        }
    } else {
        Write-Log "  Chemin de base pour pattern non trouvé : $fullBasePath" -Level WARN
    }
}

Write-Log "Total fichiers potentiels à synchroniser : $($FilesToSyncList.Count)" -Level INFO

# Identifier les fichiers réellement modifiés par le pull
if ($DryRun) {
    Write-Log "[DRY-RUN] git diff --name-only (simulation)" -Level INFO
    $ChangedFilesByPull = @() # Simule aucun changement
} else {
    $ChangedFilesByPull = git diff --name-only $HeadBeforePull $HeadAfterPull | ForEach-Object { $_ }
    Write-Log "Fichiers modifiés par le pull : $($ChangedFilesByPull.Count)" -Level INFO
}

# Filtrer FilesToSyncList pour ne garder que ceux modifiés par le pull
$ActualFilesToProcess = $FilesToSyncList | Where-Object { $fileInList = $_; $ChangedFilesByPull -contains $fileInList }
Write-Log "Fichiers à synchroniser/valider (modifiés + listés) : $($ActualFilesToProcess.Count)" -Level INFO

#--------------------------------------------------------------------------
# Étape 4 : Préparation Validation JSON
#--------------------------------------------------------------------------

$JsonFilesToValidate = [System.Collections.Generic.List[string]]::new()

Write-Log "Identification des fichiers JSON à valider..." -Level INFO
foreach ($FileRelPathInRepo in $ActualFilesToProcess) {
    $FullFilePathInRepo = Join-Path $RepoPath $FileRelPathInRepo
    
    if (Test-Path $FullFilePathInRepo) {
        if ($FileRelPathInRepo.EndsWith(".json")) {
            if (-not $JsonFilesToValidate.Contains($FullFilePathInRepo)) {
                $JsonFilesToValidate.Add($FullFilePathInRepo)
                Write-Log "  JSON à valider : $FileRelPathInRepo" -Level INFO
            }
        }
    } else {
        Write-Log "  Fichier listé par diff mais non trouvé : $FullFilePathInRepo" -Level ERROR
    }
}

#--------------------------------------------------------------------------
# Étape 5 : Vérification Post-Synchronisation (Validation JSON avec Test-Json)
#--------------------------------------------------------------------------

Write-Log "Vérification post-synchronisation des fichiers JSON..." -Level INFO

if ($JsonFilesToValidate.Count -eq 0) {
    Write-Log "Aucun fichier JSON n'a été modifié ou n'était listé pour validation." -Level INFO
} else {
    $jsonErrors = 0
    
    foreach ($JsonFileFullPathToValidate in $JsonFilesToValidate) {
        $RelativeJsonPathForLog = $JsonFileFullPathToValidate.Substring($RepoPath.Length).TrimStart('\/') -replace '\\', '/'
        
        if (Test-Path $JsonFileFullPathToValidate) {
            if ($DryRun) {
                Write-Log "[DRY-RUN] Test-Json pour : $RelativeJsonPathForLog" -Level INFO
            } else {
                try {
                    # Utilisation de Test-Json (PowerShell 6+)
                    Get-Content -Path $JsonFileFullPathToValidate | Test-Json -ErrorAction Stop | Out-Null
                    Write-Log "  Vérifié (JSON valide) : $RelativeJsonPathForLog" -Level INFO
                } catch {
                    Write-Log "  ERREUR: JSON invalide : $RelativeJsonPathForLog" -Level ERROR
                    Write-Log "  Détails : $($_.Exception.Message)" -Level ERROR
                    $jsonErrors++
                }
            }
        } else {
            Write-Log "  ERREUR: Fichier JSON non trouvé : $RelativeJsonPathForLog" -Level ERROR
            $jsonErrors++
        }
    }
    
    if ($jsonErrors -gt 0) {
        Write-Log "Validation JSON échouée ($jsonErrors erreur(s)). Annulation." -Level FATAL
        if ($StashApplied -and -not $DryRun) {
            Write-Log "Tentative de restauration du stash..." -Level WARN
            git stash pop -ErrorAction SilentlyContinue | Out-Null
        }
        exit $ExitCode.JsonValidationError
    }
}

#--------------------------------------------------------------------------
# Étape 6 : Gestion des Commits de Correction (Logs)
#--------------------------------------------------------------------------

Write-Log "Vérification des modifications pour commit de correction (ex: logs)..." -Level INFO

if ($DryRun) {
    Write-Log "[DRY-RUN] git status --porcelain (simulation)" -Level INFO
    Write-Log "[DRY-RUN] Aucun commit ne sera créé" -Level INFO
} else {
    $PostSyncStatus = git status --porcelain
    
    if ($PostSyncStatus) {
        Write-Log "Modifications détectées après synchronisation (ex: logs). Création d'un commit..." -Level WARN
        
        git add .
        git commit -m "SYNC: [Automated v2.1] Roo environment sync post-pull and logs"
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log "Commit de synchronisation créé." -Level INFO
            
            Write-Log "Tentative de push du commit de synchronisation..." -Level INFO
            git push origin main
            
            if ($LASTEXITCODE -eq 0) {
                Write-Log "Push du commit de synchronisation réussi." -Level INFO
            } else {
                Write-Log "Échec du push du commit de synchronisation." -Level ERROR
                Write-Log "Le push peut être retenté manuellement." -Level WARN
            }
        } else {
            Write-Log "Échec de la création du commit de synchronisation." -Level ERROR
        }
    } else {
        Write-Log "Aucune modification à commiter après synchronisation." -Level INFO
    }
}

#--------------------------------------------------------------------------
# Étape 7 : Nettoyage et Restauration Stash
#--------------------------------------------------------------------------

if ($StashApplied) {
    Write-Log "Restauration du stash..." -Level INFO
    
    if ($DryRun) {
        Write-Log "[DRY-RUN] git stash pop" -Level INFO
    } else {
        try {
            git stash pop -ErrorAction Stop
            
            if ($LASTEXITCODE -eq 0) {
                Write-Log "Stash restauré avec succès." -Level INFO
            } else {
                Write-Log "Échec de la restauration du stash. Des conflits peuvent exister." -Level WARN
                
                $StashConflictLogFile = Join-Path $ConflictLogDir "sync_conflict_stash_pop_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
                git status | Out-File -FilePath $StashConflictLogFile -Encoding utf8
                Write-Log "Détails du conflit de stash pop enregistrés : $StashConflictLogFile" -Level WARN
                Write-Log "Intervention manuelle requise pour résoudre les conflits de stash." -Level WARN
            }
        } catch {
            Write-Log "Erreur lors de la restauration du stash : $($_.Exception.Message)" -Level ERROR
        }
    }
}

#--------------------------------------------------------------------------
# Rapport Final et Métriques
#--------------------------------------------------------------------------

$duration = (Get-Date) - $startTime

Write-Log "═══════════════════════════════════════════════════════════════" -Level INFO
Write-Log "Synchronisation de l'environnement Roo terminée." -Level INFO
Write-Log "Durée totale : $([math]::Round($duration.TotalSeconds, 2))s" -Level INFO
if ($DryRun) {
    Write-Log "MODE DRY-RUN : Aucune modification n'a été effectuée" -Level WARN
}
Write-Log "═══════════════════════════════════════════════════════════════" -Level INFO

exit $ExitCode.Success