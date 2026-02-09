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

# Vérifier si Git est disponible
Log-Message "Vérification de la disponibilité de la commande git..."
$GitPath = Get-Command git -ErrorAction SilentlyContinue
if (-not $GitPath) {
    Log-Message "ERREUR: La commande 'git' n'a pas été trouvée. Veuillez vous assurer que Git est installé et dans le PATH." "ERREUR"
    Exit 1
}
Log-Message "Commande 'git' trouvée : $($GitPath.Source)"
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

Log-Message "Capture de l'état HEAD avant pull..."
$HeadBeforePull = git rev-parse HEAD
if (-not $HeadBeforePull -or ($LASTEXITCODE -ne 0)) {
    Log-Message "Impossible de récupérer le SHA de HEAD avant pull. Annulation." "ERREUR"
    # Tenter de restaurer le stash si appliqué
    if ($StashApplied) {
        Log-Message "Tentative de restauration du stash avant de quitter..."
        Try { git stash pop -ErrorAction SilentlyContinue } Catch {}
    }
    Exit 1
}
Log-Message "SHA de HEAD avant pull: $HeadBeforePull"

# Étape 2: Mise à Jour du Dépôt Local (git pull)
Log-Message "Exécution de git pull origin main..."
$PullAttemptOutput = "" # Pour stocker la sortie en cas d'erreur
Try {
    $GitPullResult = Invoke-Expression "git pull origin main 2>&1" # Capturer stdout et stderr
    $PullAttemptOutput = $GitPullResult | Out-String # Convertir en une seule chaîne

    if ($LASTEXITCODE -ne 0) {
        throw "Git pull a échoué avec le code $LASTEXITCODE."
    }
    Log-Message "Git pull réussi."
    if ($PullAttemptOutput -and $PullAttemptOutput.Trim().Length -gt 0) { Log-Message "Sortie de Git Pull: $($PullAttemptOutput.Trim())" }

} Catch {
    $ErrorMessageFromException = $_.Exception.Message
    
    if ($PullAttemptOutput -like "*merge conflict*") {
        Log-Message "Conflit de fusion détecté (basé sur la sortie de git pull). Annulation de la fusion..." "ALERTE"
        git merge --abort # Tenter d'annuler
        $ConflictLogFile = Join-Path $ConflictLogDir "sync_conflicts_pull_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
        Add-Content -Path $ConflictLogFile -Value "--- Conflit Git détecté lors du pull - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ---"
        Add-Content -Path $ConflictLogFile -Value "Dépôt : $RepoPath"
        Add-Content -Path $ConflictLogFile -Value "Branche : main"
        Add-Content -Path $ConflictLogFile -Value "Sortie de git pull ayant causé l'erreur : $($PullAttemptOutput.Trim())"
        Add-Content -Path $ConflictLogFile -Value "Statut après tentative d'abort :"
        (git status) | Out-String | Add-Content -Path $ConflictLogFile
        Add-Content -Path $ConflictLogFile -Value "--- FIN DU CONFLIT ---"
        Log-Message "Conflit de fusion annulé. Voir $($ConflictLogFile) pour les détails. Synchronisation interrompue." "ERREUR"
    } else {
        Log-Message "Échec du git pull. Message d'exception: $($ErrorMessageFromException). Sortie de la commande: $($PullAttemptOutput.Trim()). Annulation de la synchronisation." "ERREUR"
    }
    # Tenter de restaurer le stash si appliqué
    if ($StashApplied) {
        Log-Message "Tentative de restauration du stash avant de quitter..."
        Try { git stash pop -ErrorAction SilentlyContinue } Catch {}
    }
    Exit 1 # Sortie avec erreur
}

# Étape 3: Analyse des Nouveautés
Log-Message "Analyse des nouveautés..."

$HeadAfterPull = git rev-parse HEAD
if (-not $HeadAfterPull -or ($LASTEXITCODE -ne 0)) {
    Log-Message "Impossible de récupérer le SHA de HEAD après pull. Annulation." "ERREUR"
    if ($StashApplied) { Try { git stash pop -ErrorAction SilentlyContinue } Catch {} }
    Exit 1
}
Log-Message "SHA de HEAD après pull: $HeadAfterPull"

$FilesChangedByPull = @()
if ($HeadBeforePull -ne $HeadAfterPull) {
    Log-Message "HEAD a changé. Récupération des fichiers modifiés entre $HeadBeforePull et $HeadAfterPull..."
    $FilesChangedByPull = git diff --name-only $HeadBeforePull $HeadAfterPull | ForEach-Object { $_.Replace('\', '/') }
    if ($LASTEXITCODE -ne 0) {
        Log-Message "Erreur lors de la récupération des fichiers modifiés via git diff. Annulation." "ERREUR"
        if ($StashApplied) { Try { git stash pop -ErrorAction SilentlyContinue } Catch {} }
        Exit 1
    }
    if ($FilesChangedByPull.Count -gt 0) {
        Log-Message "Fichiers modifiés par le pull: $($FilesChangedByPull -join ', ')"
    } else {
        Log-Message "Git diff n'a retourné aucun fichier modifié, bien que HEAD ait changé (possible fusion fast-forward sans modifs directes)."
    }
} else {
    Log-Message "Aucune modification récupérée par git pull (HEAD n'a pas changé de $HeadBeforePull)."
}

# Construction dynamique de la liste des fichiers éligibles à la synchronisation
$AllEligibleFilesForSync = [System.Collections.Generic.List[string]]::new()

# Fichiers JSON spécifiques
$SpecificJsonFiles = @(
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
$SpecificJsonFiles | ForEach-Object { $AllEligibleFilesForSync.Add($_) }

# .ps1 sous roo-config/ (récursif)
$BaseDirForPs1 = Join-Path $RepoPath "roo-config"
if(Test-Path $BaseDirForPs1) {
    Get-ChildItem -Path $BaseDirForPs1 -Filter *.ps1 -Recurse -File | ForEach-Object {
        $AllEligibleFilesForSync.Add((Resolve-Path -Path $_.FullName -Relative -BasePath $RepoPath).TrimStart(".\").Replace('\', '/'))
    }
}

# .json sous roo-modes/n5/configs/ (non récursif)
$BaseDirForN5Json = Join-Path $RepoPath "roo-modes/n5/configs"
if(Test-Path $BaseDirForN5Json) {
    Get-ChildItem -Path $BaseDirForN5Json -Filter *.json -File | ForEach-Object {
        $AllEligibleFilesForSync.Add((Resolve-Path -Path $_.FullName -Relative -BasePath $RepoPath).TrimStart(".\").Replace('\', '/'))
    }
}

# .md sous roo-config/ (récursif)
$BaseDirForConfigMd = Join-Path $RepoPath "roo-config"
if(Test-Path $BaseDirForConfigMd) {
    Get-ChildItem -Path $BaseDirForConfigMd -Filter *.md -Recurse -File | ForEach-Object {
        $AllEligibleFilesForSync.Add((Resolve-Path -Path $_.FullName -Relative -BasePath $RepoPath).TrimStart(".\").Replace('\', '/'))
    }
}

# .md sous roo-modes/ (récursif)
$BaseDirForModesMd = Join-Path $RepoPath "roo-modes"
if(Test-Path $BaseDirForModesMd) {
    Get-ChildItem -Path $BaseDirForModesMd -Filter *.md -Recurse -File | ForEach-Object {
        $AllEligibleFilesForSync.Add((Resolve-Path -Path $_.FullName -Relative -BasePath $RepoPath).TrimStart(".\").Replace('\', '/'))
    }
}

$UniqueEligibleFiles = $AllEligibleFilesForSync | Select-Object -Unique
Log-Message "Nombre total de fichiers éligibles uniques pour la synchronisation : $($UniqueEligibleFiles.Count)"

# Étape 4: Exécution des Opérations de Synchronisation
Log-Message "Exécution des opérations de synchronisation..."
$FilesActuallySynced = [System.Collections.Generic.List[string]]::new()

if ($FilesChangedByPull.Count -eq 0 -and $HeadBeforePull -eq $HeadAfterPull) {
    Log-Message "Aucun fichier n'a été modifié par le pull et HEAD n'a pas changé. Aucune synchronisation de fichier n'est nécessaire."
} else {
    # Si HEAD a changé mais FilesChangedByPull est vide (ex: fast-forward sans modifs directes),
    # ou si des fichiers ont été modifiés, on procède.
    # On ne synchronise que les fichiers qui sont à la fois modifiés ET éligibles.
    $FilesToConsiderForSync = $FilesChangedByPull | Where-Object { $UniqueEligibleFiles -contains $_ } | Select-Object -Unique
    
    if ($FilesToConsiderForSync.Count -eq 0) {
        if ($FilesChangedByPull.Count -gt 0) {
             Log-Message "Les fichiers modifiés par le pull ($($FilesChangedByPull -join ', ')) ne sont pas dans la liste des fichiers éligibles. Aucune synchronisation de fichier."
        } else {
             Log-Message "Aucun fichier modifié par le pull n'est éligible pour la synchronisation."
        }
    } else {
        Log-Message "Fichiers à synchroniser (modifiés par pull ET éligibles) ($($FilesToConsiderForSync.Count)): $($FilesToConsiderForSync -join ', ')"
        foreach ($FileRelativePath in $FilesToConsiderForSync) {
            $SourceFile = Join-Path $RepoPath $FileRelativePath
            $DestinationFile = Join-Path $RepoPath $FileRelativePath

            if (Test-Path $SourceFile) {
                Try {
                    Copy-Item -Path $SourceFile -Destination $DestinationFile -Force -ErrorAction Stop
                    Log-Message "Synchronisé : $($FileRelativePath)"
                    $FilesActuallySynced.Add($FileRelativePath)
                } Catch {
                    Log-Message "Échec de la synchronisation de $($FileRelativePath). Message : $($_.Exception.Message)" "ERREUR"
                    if ($StashApplied) { Try { git stash pop -ErrorAction SilentlyContinue } Catch {} }
                    Exit 1
                }
            } else {
                Log-Message "Le fichier source $($FileRelativePath) (listé par git diff) n'existe pas dans le dépôt après pull. Ignoré." "ALERTE"
            }
        }
    }
}

# Étape 5: Vérification Post-Synchronisation
Log-Message "Vérification post-synchronisation..."

# 5.1 Vérification de l'intégrité des fichiers JSON synchronisés
$JsonFilesToValidate = $FilesActuallySynced | Where-Object { $_ -like "*.json" } | Select-Object -Unique

if ($JsonFilesToValidate.Count -eq 0) {
    Log-Message "Aucun fichier JSON n'a été synchronisé, pas de validation JSON nécessaire."
} else {
    Log-Message "Fichiers JSON synchronisés à valider ($($JsonFilesToValidate.Count)): $($JsonFilesToValidate -join ', ')"
    foreach ($JsonFileRelativePath in $JsonFilesToValidate) {
        $FullPath = Join-Path $RepoPath $JsonFileRelativePath
        Try {
            Get-Content -Raw $FullPath | ConvertFrom-Json -ErrorAction Stop | Out-Null
            Log-Message "Vérifié (JSON valide) : $($JsonFileRelativePath)"
        } Catch {
            Log-Message "ERREUR: Fichier JSON $($JsonFileRelativePath) invalide après synchronisation. Détails : $($_.Exception.Message)" "ERREUR"
            if ($StashApplied) { Try { git stash pop -ErrorAction SilentlyContinue } Catch {} }
            Exit 1
        }
    }
}

# 5.2 Vérification de l'existence des fichiers JSON critiques (ceux de $SpecificJsonFiles)
Log-Message "Vérification de l'existence des fichiers JSON critiques..."
$MissingCriticalFiles = @()
foreach ($CriticalJsonFileRelPath in $SpecificJsonFiles) { # Utiliser la liste originale des JSON critiques
    $FullPath = Join-Path $RepoPath $CriticalJsonFileRelPath
    if (-not (Test-Path $FullPath)) {
        Log-Message "ERREUR: Fichier JSON critique MANQUANT après synchronisation : $($CriticalJsonFileRelPath)" "ERREUR"
        $MissingCriticalFiles += $CriticalJsonFileRelPath
    } else {
        Log-Message "Présent (fichier critique) : $($CriticalJsonFileRelPath)"
    }
}

if ($MissingCriticalFiles.Count -gt 0) {
    Log-Message "Au moins un fichier JSON critique est manquant ($($MissingCriticalFiles -join ', ')). Synchronisation considérée comme échouée." "ERREUR"
    if ($StashApplied) { Try { git stash pop -ErrorAction SilentlyContinue } Catch {} }
    Exit 1
}

# Étape 6: Gestion des Commits de Correction (si nécessaire)
Log-Message "Vérification des modifications pour commit de correction..."
$PostSyncStatus = git status --porcelain
if ($PostSyncStatus) {
    Log-Message "Modifications détectées après synchronisation (ex: logs). Création d'un commit de correction..."
    git add .
    git commit -m "SYNC: [Automated] Synchronisation des paramètres Roo post-pull" # Message ajusté
    Log-Message "Commit de correction créé."

    Log-Message "Tentative de push du commit de correction..."
    Try {
        git push origin main -ErrorAction Stop
        Log-Message "Push du commit de correction réussi."
    } Catch {
        Log-Message "Échec du push du commit de correction. Message : $($_.Exception.Message)" "ERREUR"
    }
} else {
    Log-Message "Aucune modification à commiter après synchronisation."
}

# Étape 7: Nettoyage et Rapport Final
if ($StashApplied) {
    Log-Message "Restauration du stash..."
    Try {
        git stash pop -ErrorAction Stop
        Log-Message "Stash restauré avec succès."
    } Catch {
        $StashPopErrorMessage = $_.Exception.Message
        Log-Message "Échec de la restauration du stash. Des conflits peuvent exister. Message : $($StashPopErrorMessage)" "ALERTE"
        # Documenter les conflits de stash pop
        $StashConflictLogFile = Join-Path $ConflictLogDir "sync_conflicts_stash_pop_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
        Add-Content -Path $StashConflictLogFile -Value "--- Conflit Git détecté lors du stash pop - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ---"
        Add-Content -Path $StashConflictLogFile -Value "Dépôt : $RepoPath"
        Add-Content -Path $StashConflictLogFile -Value "Message d'erreur : $StashPopErrorMessage"
        Add-Content -Path $StashConflictLogFile -Value "Statut Git après tentative de pop :"
        (git status --porcelain) | Out-String | Add-Content -Path $StashConflictLogFile # Utiliser --porcelain pour un statut plus concis
        (git diff --name-status --diff-filter=U) | Out-String | Add-Content -Path $StashConflictLogFile # Lister les fichiers en conflit
        Add-Content -Path $StashConflictLogFile -Value "--- FIN DU CONFLIT STASH POP ---"
        Log-Message "Détails du conflit de stash pop enregistrés dans $($StashConflictLogFile). Résolution manuelle requise." "ERREUR"
    }
}

Log-Message "Synchronisation de l'environnement Roo terminée."