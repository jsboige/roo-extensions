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

Log-Message "Début de la synchronisation de l'environnement Roo."
Set-Location $RepoPath
Log-Message "Répertoire de travail actuel : $(Get-Location)"

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
    Log-Message "Aucune modification locale détectée avant le stash."
    $StashApplied = $false
}

# Étape 2: Mise à Jour du Dépôt Local (git pull)
Log-Message "Exécution de git pull origin main..."
Try {
    # Récupérer le HEAD actuel pour comparaison ultérieure
    $OldHead = git rev-parse HEAD
    git pull origin main -ErrorAction Stop
    Log-Message "Git pull réussi."
    $NewHead = git rev-parse HEAD
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
    # Restaurer le stash si un a été appliqué avant de quitter en erreur
    if ($StashApplied) {
        Log-Message "Tentative de restauration du stash après échec du pull..."
        Try { git stash pop -ErrorAction SilentlyContinue } Catch {} # Tenter de restaurer, ignorer les erreurs ici car on quitte déjà
    }
    Exit 1 # Sortie avec erreur
}

# Étape 3 & 4: Analyse des Nouveautés et Préparation pour la Synchronisation/Validation
Log-Message "Analyse des nouveautés et préparation pour la synchronisation/validation..."

# Liste initiale des fichiers spécifiques
$SpecificFiles = @(
    "roo-config/settings/settings.json",
    "roo-config/settings/servers.json",
    "roo-config/settings/modes.json",
    "roo-config/escalation-test-config.json",
    "roo-config/qwen3-profiles/qwen3-parameters.json",
    "roo-modes/configs/modes.json",
    "roo-modes/configs/new-roomodes.json", # Assumant que c'est un fichier spécifique et non un pattern
    "roo-modes/configs/standard-modes.json",
    "roo-modes/configs/vscode-custom-modes.json"
)

# Patterns pour la collecte dynamique
# La clé est le chemin de base pour Get-ChildItem (relatif à $RepoPath)
# La valeur est un tableau de patterns de filtre pour ce chemin
$FilesToSyncPatterns = @{
    "roo-config" = @("*.ps1", "*.md"); # .ps1 non-récursif (par défaut pour GCI sans -Recurse sur le pattern), .md récursif
    "roo-modes" = @("*.md"); # .md récursif
    "roo-modes/n5/configs" = @("*.json") # .json non-récursif (par défaut)
}

$FilesToSyncList = [System.Collections.Generic.List[string]]::new()
Log-Message "Ajout des fichiers spécifiques à la liste de synchronisation..."
foreach ($sf in $SpecificFiles) {
    $normalizedSf = $sf -replace '\\', '/' # Normaliser en slashes
    if (-not $FilesToSyncList.Contains($normalizedSf)) {
        $FilesToSyncList.Add($normalizedSf)
        Log-Message "Spécifique ajouté : $normalizedSf"
    }
}


Log-Message "Collecte des fichiers basés sur les patterns..."
foreach ($basePathPatternKey in $FilesToSyncPatterns.Keys) {
    $patternsForPath = $FilesToSyncPatterns[$basePathPatternKey]
    $fullBasePath = Join-Path $RepoPath $basePathPatternKey

    if (Test-Path $fullBasePath) {
        foreach ($pattern in $patternsForPath) {
            $isRecursive = $false
            # Déterminer la récursivité basée sur le pattern et le chemin de base
            if ($pattern -eq "*.md") { # Tous les .md sont récursifs
                $isRecursive = $true
            }
            # Pour les autres (.ps1, .json), Get-ChildItem sans -Recurse sur le pattern lui-même
            # signifie non-récursif pour ce niveau. Si le $basePathPatternKey est profond,
            # il cherchera dans ce dossier profond, mais pas ses sous-dossiers à moins que -Recurse soit vrai.

            Log-Message "Recherche de '$pattern' dans '$fullBasePath' (Récursif: $isRecursive)"
            Get-ChildItem -Path $fullBasePath -Filter $pattern -Recurse:$isRecursive -ErrorAction SilentlyContinue | ForEach-Object {
                $relativeFilePath = $_.FullName.Substring($RepoPath.Length).TrimStart('\/') -replace '\\', '/'
                if (-not $FilesToSyncList.Contains($relativeFilePath)) {
                    $FilesToSyncList.Add($relativeFilePath)
                    Log-Message "Pattern ajouté : $relativeFilePath"
                }
            }
        }
    } else {
        Log-Message "Chemin de base pour pattern non trouvé : $fullBasePath" "ALERTE"
    }
}
Log-Message "Liste complète des fichiers potentiels à synchroniser (avant filtrage par diff): $($FilesToSyncList -join ', ')"

# Identifier les fichiers réellement modifiés par le pull
# La sortie de git diff utilise des slashes. Nos chemins dans FilesToSyncList sont aussi normalisés en slashes.
$ChangedFilesByPull = git diff --name-only $OldHead $NewHead | ForEach-Object { $_ } # Déjà en slashes
Log-Message "Fichiers modifiés par le pull (selon git diff): $($ChangedFilesByPull -join ', ')"

# Filtrer FilesToSyncList pour ne garder que ceux modifiés par le pull
$ActualFilesToProcess = $FilesToSyncList | Where-Object { $fileInList = $_; $ChangedFilesByPull -contains $fileInList }
Log-Message "Fichiers à synchroniser/valider (modifiés par pull ET dans la liste de synchro globale) : $($ActualFilesToProcess -join ', ')"


$JsonFilesToValidate = [System.Collections.Generic.List[string]]::new()

Log-Message "Identification des fichiers JSON à valider parmi ceux modifiés et listés..."
foreach ($FileRelPathInRepo in $ActualFilesToProcess) {
    # $FileRelPathInRepo est le chemin relatif au dépôt, ex: "roo-config/settings/settings.json"
    # Le fichier est déjà mis à jour dans le dépôt par 'git pull'.
    # La "synchronisation" ici signifie s'assurer qu'il est pris en compte pour la validation.
    # Si une copie vers un emplacement *externe* était nécessaire, elle se ferait ici.
    # Pour ce script, l'emplacement actif est le dépôt.

    $FullFilePathInRepo = Join-Path $RepoPath $FileRelPathInRepo
    
    if (Test-Path $FullFilePathInRepo) {
        Log-Message "Fichier marqué pour traitement/validation : $FileRelPathInRepo"
        # La copie sur soi-même (Copy-Item $FullFilePathInRepo $FullFilePathInRepo) est inutile.
        # On ajoute les JSON à la liste de validation.
        if ($FileRelPathInRepo.EndsWith(".json")) {
            if (-not $JsonFilesToValidate.Contains($FullFilePathInRepo)) {
                 $JsonFilesToValidate.Add($FullFilePathInRepo)
                 Log-Message "Ajouté à la liste de validation JSON : $FileRelPathInRepo (Chemin complet: $FullFilePathInRepo)"
            }
        }
    } else {
        # Cela serait très inattendu si le fichier était listé par 'git diff' mais n'existe pas.
        Log-Message "Fichier listé par diff mais non trouvé localement : $FullFilePathInRepo. Cela ne devrait pas arriver." "ERREUR"
    }
}

# Étape 5: Vérification Post-Synchronisation (Validation JSON)
Log-Message "Vérification post-synchronisation des fichiers JSON..."
if ($JsonFilesToValidate.Count -eq 0) {
    Log-Message "Aucun fichier JSON n'a été modifié ou n'était listé pour validation."
} else {
    foreach ($JsonFileFullPathToValidate in $JsonFilesToValidate) {
        # $JsonFileFullPathToValidate est le chemin complet du fichier JSON dans le dépôt.
        $RelativeJsonPathForLog = $JsonFileFullPathToValidate.Substring($RepoPath.Length).TrimStart('\/') -replace '\\', '/'
        if (Test-Path $JsonFileFullPathToValidate) {
            Try {
                Get-Content -Raw $JsonFileFullPathToValidate | ConvertFrom-Json -ErrorAction Stop | Out-Null
                Log-Message "Vérifié (JSON valide) : $RelativeJsonPathForLog"
            } Catch {
                Log-Message "ERREUR: Fichier JSON invalide après synchronisation : $RelativeJsonPathForLog. Détails : $($_.Exception.Message)" "ERREUR"
                # Restaurer le stash si un a été appliqué avant de quitter en erreur
                if ($StashApplied) {
                    Log-Message "Tentative de restauration du stash après échec de validation JSON..."
                    Try { git stash pop -ErrorAction SilentlyContinue } Catch {}
                }
                Exit 1 # Quitter si un JSON crucial est invalide
            }
        } else {
             Log-Message "ERREUR: Fichier JSON listé pour validation non trouvé : $RelativeJsonPathForLog. Cela ne devrait pas arriver." "ERREUR"
        }
    }
}

# Étape 6: Gestion des Commits de Correction (si nécessaire, ex: pour les logs)
Log-Message "Vérification des modifications pour commit de correction (ex: logs)..."
$PostSyncStatus = git status --porcelain
if ($PostSyncStatus) {
    Log-Message "Modifications détectées après synchronisation (ex: logs). Création d'un commit..." "ALERTE"
    git add . # Ajoute tous les changements, y compris le fichier log lui-même
    git commit -m "SYNC: [Automated] Roo environment sync post-pull and logs"
    Log-Message "Commit de synchronisation créé."

    Log-Message "Tentative de push du commit de synchronisation..."
    Try {
        git push origin main -ErrorAction Stop
        Log-Message "Push du commit de synchronisation réussi."
    } Catch {
        Log-Message "Échec du push du commit de synchronisation. Message : $($_.Exception.Message)" "ERREUR"
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
        git stash pop -ErrorAction Stop
        Log-Message "Stash restauré avec succès."
    } Catch {
        Log-Message "Échec de la restauration du stash. Des conflits peuvent exister. Message : $($_.Exception.Message)" "ALERTE"
        $StashConflictLogFile = Join-Path $ConflictLogDir "stash_pop_conflict_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
        Add-Content -Path $StashConflictLogFile -Value "--- Conflit Git détecté lors du stash pop - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ---"
        Add-Content -Path $StashConflictLogFile -Value "$($_.Exception.Message)"
        (git status) | Out-String | Add-Content -Path $StashConflictLogFile
        Log-Message "Détails du conflit de stash pop enregistrés dans $($StashConflictLogFile). Intervention manuelle requise." "ALERTE"
    }
}

Log-Message "Synchronisation de l'environnement Roo terminée."
Exit 0