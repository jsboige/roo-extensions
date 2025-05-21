<#
.SYNOPSIS
    Script de maintenance automatique pour le dépôt roo-extensions.

.DESCRIPTION
    Ce script effectue plusieurs tâches de maintenance sur le dépôt roo-extensions :
    - Nettoyage des fichiers temporaires et de sauvegarde
    - Vérification de l'état du sous-module mcps/mcp-servers
    - Vérification de l'état des branches Git

.NOTES
    Auteur: Roo Assistant
    Date de création: 21/05/2025
#>

# Configuration
$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$LogFile = Join-Path $RepoRoot "logs/maintenance.log"

# Création du répertoire de logs s'il n'existe pas
if (-not (Test-Path (Split-Path -Parent $LogFile))) {
    New-Item -ItemType Directory -Path (Split-Path -Parent $LogFile) -Force | Out-Null
}

# Fonction pour écrire dans le journal
function Write-Log {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("INFO", "WARNING", "ERROR")]
        [string]$Level = "INFO"
    )
    
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] [$Level] $Message"
    
    # Écrire dans le fichier journal
    Add-Content -Path $LogFile -Value $LogMessage
    
    # Afficher dans la console avec une couleur appropriée
    switch ($Level) {
        "INFO" { Write-Host $LogMessage -ForegroundColor Green }
        "WARNING" { Write-Host $LogMessage -ForegroundColor Yellow }
        "ERROR" { Write-Host $LogMessage -ForegroundColor Red }
    }
}

<#
.SYNOPSIS
    Nettoie les fichiers temporaires et de sauvegarde.

.DESCRIPTION
    Cette fonction recherche et supprime les fichiers temporaires et de sauvegarde
    qui ne sont pas nécessaires au fonctionnement du dépôt.
#>
function Clean-TemporaryFiles {
    Write-Log "Début du nettoyage des fichiers temporaires et de sauvegarde..."
    
    # Définir les motifs de fichiers à rechercher
    $tempPatterns = @(
        "*.tmp",
        "*.temp",
        "*.bak",
        "*.backup",
        "*.swp",
        "*.swo",
        "*~"
    )
    
    # Exclure les répertoires node_modules
    $excludeDirs = @(
        "node_modules"
    )
    
    $filesToDelete = @()
    
    # Rechercher les fichiers correspondant aux motifs
    foreach ($pattern in $tempPatterns) {
        $files = Get-ChildItem -Path $RepoRoot -Filter $pattern -Recurse -File -ErrorAction SilentlyContinue | 
                 Where-Object { 
                     $exclude = $false
                     foreach ($dir in $excludeDirs) {
                         if ($_.FullName -like "*\$dir\*") {
                             $exclude = $true
                             break
                         }
                     }
                     -not $exclude
                 }
        
        $filesToDelete += $files
    }
    
    # Supprimer les fichiers trouvés
    if ($filesToDelete.Count -gt 0) {
        Write-Log "Fichiers temporaires trouvés: $($filesToDelete.Count)" "INFO"
        
        foreach ($file in $filesToDelete) {
            try {
                Remove-Item -Path $file.FullName -Force
                Write-Log "Supprimé: $($file.FullName)" "INFO"
            }
            catch {
                Write-Log "Erreur lors de la suppression de $($file.FullName): $_" "ERROR"
            }
        }
    }
    else {
        Write-Log "Aucun fichier temporaire trouvé." "INFO"
    }
    
    Write-Log "Nettoyage des fichiers temporaires terminé."
}

<#
.SYNOPSIS
    Vérifie l'état du sous-module mcps/mcp-servers.

.DESCRIPTION
    Cette fonction vérifie si le sous-module mcps/mcp-servers est correctement initialisé,
    à jour et sur la bonne branche.
#>
function Check-McpServersSubmodule {
    Write-Log "Vérification de l'état du sous-module mcps/mcp-servers..."
    
    $submodulePath = Join-Path $RepoRoot "mcps/mcp-servers"
    
    # Vérifier si le sous-module existe
    if (-not (Test-Path $submodulePath)) {
        Write-Log "Le sous-module mcps/mcp-servers n'existe pas. Initialisation..." "WARNING"
        
        try {
            Push-Location $RepoRoot
            git submodule init
            git submodule update
            Pop-Location
            
            if (Test-Path $submodulePath) {
                Write-Log "Sous-module initialisé avec succès." "INFO"
            }
            else {
                Write-Log "Échec de l'initialisation du sous-module." "ERROR"
                return
            }
        }
        catch {
            Write-Log "Erreur lors de l'initialisation du sous-module: $_" "ERROR"
            return
        }
    }
    
    # Vérifier l'état du sous-module
    try {
        Push-Location $submodulePath
        
        # Vérifier si le sous-module est sur un commit détaché
        $gitStatus = git status --porcelain=v2 --branch
        $detachedHead = $gitStatus | Select-String "branch.head \(detached\)"
        
        if ($detachedHead) {
            Write-Log "Le sous-module est sur un commit détaché. Cela est normal pour un sous-module." "INFO"
        }
        
        # Vérifier s'il y a des modifications non validées
        $changes = git status --porcelain
        if ($changes) {
            Write-Log "Le sous-module contient des modifications non validées:" "WARNING"
            $changes | ForEach-Object { Write-Log "  $_" "WARNING" }
        }
        else {
            Write-Log "Le sous-module est propre, sans modifications non validées." "INFO"
        }
        
        # Vérifier si le sous-module est à jour par rapport au commit référencé
        $expectedSha = git ls-files --stage | Select-String "160000 ([a-f0-9]+)" | ForEach-Object { $_.Matches.Groups[1].Value }
        $currentSha = git rev-parse HEAD
        
        if ($expectedSha -ne $currentSha) {
            Write-Log "Le sous-module n'est pas sur le commit attendu." "WARNING"
            Write-Log "  Commit attendu: $expectedSha" "WARNING"
            Write-Log "  Commit actuel: $currentSha" "WARNING"
            Write-Log "Pour mettre à jour le sous-module, exécutez: git submodule update" "INFO"
        }
        else {
            Write-Log "Le sous-module est sur le commit attendu." "INFO"
        }
        
        Pop-Location
    }
    catch {
        Write-Log "Erreur lors de la vérification du sous-module: $_" "ERROR"
        if ((Get-Location).Path -eq $submodulePath) {
            Pop-Location
        }
    }
    
    Write-Log "Vérification du sous-module terminée."
}

<#
.SYNOPSIS
    Vérifie l'état des branches Git.

.DESCRIPTION
    Cette fonction vérifie l'état des branches Git, notamment :
    - La branche actuelle
    - Les branches qui ont besoin d'être fusionnées
    - Les branches obsolètes qui peuvent être supprimées
#>
function Check-GitBranches {
    Write-Log "Vérification de l'état des branches Git..."
    
    try {
        Push-Location $RepoRoot
        
        # Obtenir la branche actuelle
        $currentBranch = git symbolic-ref --short HEAD
        Write-Log "Branche actuelle: $currentBranch" "INFO"
        
        # Mettre à jour les références distantes
        git fetch --all --prune
        Write-Log "Références distantes mises à jour." "INFO"
        
        # Vérifier les branches qui ont besoin d'être fusionnées avec main
        if ($currentBranch -ne "main") {
            $behindCount = git rev-list --count $currentBranch..origin/main
            if ($behindCount -gt 0) {
                Write-Log "La branche actuelle est en retard de $behindCount commit(s) par rapport à origin/main." "WARNING"
                Write-Log "Considérez fusionner les changements de main avec: git merge origin/main" "INFO"
            }
        }
        
        # Lister les branches locales
        $localBranches = git branch | ForEach-Object { $_.Trim('* ') }
        
        # Vérifier les branches obsolètes
        foreach ($branch in $localBranches) {
            if ($branch -eq "main") { continue }
            
            # Vérifier si la branche a été fusionnée dans main
            $isMerged = git branch --merged main | ForEach-Object { $_.Trim('* ') } | Where-Object { $_ -eq $branch }
            
            if ($isMerged) {
                Write-Log "La branche '$branch' a été fusionnée dans main et peut être supprimée." "INFO"
                Write-Log "Pour supprimer cette branche, exécutez: git branch -d $branch" "INFO"
            }
            
            # Vérifier si la branche distante existe encore
            $hasRemote = git ls-remote --heads origin $branch
            
            if (-not $hasRemote -and $branch -ne $currentBranch) {
                Write-Log "La branche '$branch' n'existe plus sur le dépôt distant." "WARNING"
                Write-Log "Pour supprimer cette branche locale, exécutez: git branch -d $branch" "INFO"
            }
        }
        
        Pop-Location
    }
    catch {
        Write-Log "Erreur lors de la vérification des branches Git: $_" "ERROR"
        if ((Get-Location).Path -eq $RepoRoot) {
            Pop-Location
        }
    }
    
    Write-Log "Vérification des branches Git terminée."
}

# Fonction principale
function Start-MaintenanceRoutine {
    Write-Log "Démarrage de la routine de maintenance..."
    
    # Exécuter les fonctions de maintenance
    Clean-TemporaryFiles
    Check-McpServersSubmodule
    Check-GitBranches
    
    Write-Log "Routine de maintenance terminée."
}

# Exécuter la routine de maintenance
Start-MaintenanceRoutine